#!/usr/bin/env python3
"""
import_from_figma.py
Pull Figma Variables → update tokens/tokens.json → regenerate DesignTokens.swift.

Usage:
    export FIGMA_API_TOKEN=<your-token>
    export FIGMA_FILE_KEY=<file-key-from-url>
    python3 scripts/import_from_figma.py

After running, review the git diff of:
  - tokens/tokens.json
  - Yarn&Yarn/DesignSystem/DesignTokens.swift

Then commit both files together.

Requirements:
  - Figma Professional or Enterprise plan (Variables REST API)
  - Personal access token with 'file_variables:read' scope
"""

import json
import os
import subprocess
import sys
import urllib.request
import urllib.error
from pathlib import Path

REPO_ROOT   = Path(__file__).resolve().parent.parent
TOKENS_FILE = REPO_ROOT / "tokens" / "tokens.json"
IDS_FILE    = REPO_ROOT / "tokens" / ".figma_ids.json"
FIGMA_API   = "https://api.figma.com/v1"


# ─── HTTP helpers ──────────────────────────────────────────────────────────────

def figma_get(path: str, token: str) -> dict:
    url = f"{FIGMA_API}{path}"
    req = urllib.request.Request(
        url,
        headers={"X-Figma-Token": token, "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        body_text = e.read().decode()
        print(f"HTTP {e.code} {e.reason}: {body_text}", file=sys.stderr)
        sys.exit(1)


# ─── Color helpers ─────────────────────────────────────────────────────────────

def figma_to_hex(rgba: dict) -> str:
    """Convert Figma RGBA dict (floats 0-1) to '#RRGGBB'."""
    r = round(rgba["r"] * 255)
    g = round(rgba["g"] * 255)
    b = round(rgba["b"] * 255)
    return f"#{r:02X}{g:02X}{b:02X}"


# ─── Token tree helpers ────────────────────────────────────────────────────────

def set_nested(tree: dict, path: list[str], value) -> None:
    """Set a value deep inside a nested dict, creating missing dicts."""
    for key in path[:-1]:
        tree = tree.setdefault(key, {})
    leaf_key = path[-1]
    if leaf_key in tree and isinstance(tree[leaf_key], dict):
        tree[leaf_key]["$value"] = value
    else:
        tree[leaf_key] = {"$value": value}


# ─── Main ──────────────────────────────────────────────────────────────────────

def main():
    api_token = os.environ.get("FIGMA_API_TOKEN")
    file_key  = os.environ.get("FIGMA_FILE_KEY")

    if not api_token or not file_key:
        print("Error: set FIGMA_API_TOKEN and FIGMA_FILE_KEY environment variables.", file=sys.stderr)
        sys.exit(1)

    if not TOKENS_FILE.exists():
        print(f"Error: {TOKENS_FILE} not found. Run export_to_figma.py first.", file=sys.stderr)
        sys.exit(1)

    # Load existing tokens (we only update $value; metadata is preserved)
    with open(TOKENS_FILE) as f:
        tokens = json.load(f)

    # Load ID map so we can match Figma variable IDs to token paths
    if not IDS_FILE.exists():
        print("Warning: .figma_ids.json not found. Run export_to_figma.py first.", file=sys.stderr)
        print("Attempting name-based matching instead …")
        id_map = {}
    else:
        with open(IDS_FILE) as f:
            id_map = json.load(f)

    # Build reverse map: real Figma variable ID → token path
    #   Key format in id_map: "col_colors__colors__counter__sage" → "VAR123:456"
    id_to_path: dict[str, list[str]] = {}
    for id_key, real_id in id_map.items():
        # Only variable entries contain "__" more than once
        parts = id_key.split("__")
        if len(parts) >= 3:
            # parts[0] = collection key (e.g. "col_colors")
            # parts[1:] = token path (e.g. ["colors", "counter", "sage"])
            id_to_path[real_id] = parts[1:]

    print(f"Fetching variables from Figma file {file_key!r} …")
    resp = figma_get(f"/files/{file_key}/variables/local", api_token)
    meta = resp.get("meta", {})
    variables = meta.get("variables", {})
    collections = meta.get("variableCollections", {})

    if not variables:
        print("No variables found in Figma file.")
        return

    # Find the "Default" mode ID for each collection
    col_default_mode: dict[str, str] = {}
    for col_id, col_data in collections.items():
        for mode in col_data.get("modes", []):
            if mode["name"] == "Default":
                col_default_mode[col_id] = mode["modeId"]
                break

    changed: list[str] = []

    for var_id, var_data in variables.items():
        col_id   = var_data.get("variableCollectionId", "")
        mode_id  = col_default_mode.get(col_id)
        if not mode_id:
            continue

        values_by_mode = var_data.get("valuesByMode", {})
        if mode_id not in values_by_mode:
            continue

        figma_value = values_by_mode[mode_id]
        var_type    = var_data.get("resolvedType", "FLOAT")

        # Resolve token path
        if var_id in id_to_path:
            path = id_to_path[var_id]
        else:
            # Fallback: derive path from variable name (e.g. "colors/counter/sage")
            path = var_data.get("name", "").split("/")
            if not path or path == [""]:
                continue

        # Convert value
        if var_type == "COLOR" and isinstance(figma_value, dict):
            new_value = figma_to_hex(figma_value)
        elif var_type == "FLOAT":
            raw = float(figma_value)
            new_value = int(raw) if raw == int(raw) else raw
        else:
            continue

        # Find old value for diff reporting
        try:
            node = tokens
            for key in path[:-1]:
                node = node[key]
            old_value = node.get(path[-1], {}).get("$value")
        except (KeyError, TypeError):
            old_value = None

        if old_value != new_value:
            set_nested(tokens, path, new_value)
            changed.append(f"  {'/'.join(path)}: {old_value!r} → {new_value!r}")

    if not changed:
        print("✓ No token values changed.")
        return

    print(f"Changed tokens ({len(changed)}):")
    for line in changed:
        print(line)

    with open(TOKENS_FILE, "w") as f:
        json.dump(tokens, f, indent=2)
        f.write("\n")
    print(f"\n✓ Updated {TOKENS_FILE.relative_to(REPO_ROOT)}")

    # Regenerate Swift
    generate_script = REPO_ROOT / "scripts" / "generate_swift.py"
    print("Regenerating DesignTokens.swift …")
    result = subprocess.run(
        [sys.executable, str(generate_script)],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        print(f"Error running generate_swift.py:\n{result.stderr}", file=sys.stderr)
        sys.exit(1)
    print(result.stdout.strip())
    print("\nReview the diff, then commit tokens/tokens.json and DesignTokens.swift together.")


if __name__ == "__main__":
    main()

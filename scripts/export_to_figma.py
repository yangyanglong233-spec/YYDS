#!/usr/bin/env python3
"""
export_to_figma.py
Push tokens/tokens.json to Figma as native Variables.

Usage:
    export FIGMA_API_TOKEN=<your-token>
    export FIGMA_FILE_KEY=<file-key-from-url>
    python3 scripts/export_to_figma.py

On the first run, four Variable Collections are created in Figma:
  - Colors/Counter, Colors/Status, Colors/Category, Colors/Marker
  - Typography
  - Spacing
  - Radius

Subsequent runs UPDATE existing variables using the ID map saved to
tokens/.figma_ids.json (commit this file so the IDs persist).

Requirements:
  - Figma Professional or Enterprise plan (Variables REST API)
  - Personal access token with 'file_variables:write' scope
"""

import json
import os
import sys
import urllib.request
import urllib.error
from pathlib import Path

REPO_ROOT   = Path(__file__).resolve().parent.parent
TOKENS_FILE = REPO_ROOT / "tokens" / "tokens.json"
IDS_FILE    = REPO_ROOT / "tokens" / ".figma_ids.json"
FIGMA_API   = "https://api.figma.com/v1"


# ─── HTTP helpers ──────────────────────────────────────────────────────────────

def figma_request(method: str, path: str, token: str, body: dict | None = None) -> dict:
    url  = f"{FIGMA_API}{path}"
    data = json.dumps(body).encode() if body else None
    req  = urllib.request.Request(
        url, data=data, method=method,
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

def hex_to_figma(hex_color: str) -> dict:
    """Convert '#RRGGBB' to Figma RGBA dict (floats 0-1)."""
    h = hex_color.lstrip("#")
    return {
        "r": int(h[0:2], 16) / 255,
        "g": int(h[2:4], 16) / 255,
        "b": int(h[4:6], 16) / 255,
        "a": 1.0,
    }


# ─── Token flattening ──────────────────────────────────────────────────────────

def flatten_tokens(node: dict, path: list[str] = None) -> list[dict]:
    """Walk the token tree, yielding leaf tokens as dicts with a 'path' key."""
    if path is None:
        path = []
    results = []
    for key, value in node.items():
        if key.startswith("$"):
            continue
        if isinstance(value, dict) and "$value" in value:
            results.append({"path": path + [key], **value})
        elif isinstance(value, dict):
            results.extend(flatten_tokens(value, path + [key]))
    return results


def tokens_for_collection(tokens: dict, top_keys: list[str]) -> list[dict]:
    """Return flattened leaf tokens under the given top-level keys."""
    result = []
    for key in top_keys:
        if key in tokens:
            result.extend(flatten_tokens(tokens[key], [key]))
    return result


# ─── Build Figma payload ───────────────────────────────────────────────────────

COLLECTIONS = [
    {
        "id_key": "col_colors",
        "name":   "Colors",
        "top_keys": ["colors"],
    },
    {
        "id_key": "col_typography",
        "name":   "Typography",
        "top_keys": ["typography"],
    },
    {
        "id_key": "col_spacing",
        "name":   "Spacing",
        "top_keys": ["spacing"],
    },
    {
        "id_key": "col_radius",
        "name":   "Radius / Shadow",
        "top_keys": ["radius", "shadow"],
    },
]


def build_payload(tokens: dict, existing_ids: dict) -> dict:
    """
    Build the POST /variables payload.
    If existing_ids contains real Figma IDs from a previous run, use UPDATE action;
    otherwise use CREATE with temporary IDs.
    """
    collections_payload = []
    modes_payload       = []
    variables_payload   = []
    values_payload      = []

    for col_def in COLLECTIONS:
        col_id_key  = col_def["id_key"]
        mode_id_key = col_id_key + "_mode"

        col_real_id  = existing_ids.get(col_id_key)
        mode_real_id = existing_ids.get(mode_id_key)

        if col_real_id:
            col_ref  = col_real_id
            mode_ref = mode_real_id
            # Collection already exists — no need to re-create it
        else:
            col_ref  = col_id_key      # temporary ID
            mode_ref = mode_id_key     # temporary ID
            collections_payload.append({
                "id":            col_ref,
                "action":        "CREATE",
                "name":          col_def["name"],
                "initialModeId": mode_ref,
            })
            modes_payload.append({
                "id":                   mode_ref,
                "action":               "CREATE",
                "name":                 "Default",
                "variableCollectionId": col_ref,
            })

        leaf_tokens = tokens_for_collection(tokens, col_def["top_keys"])

        for tok in leaf_tokens:
            var_name  = "/".join(tok["path"])
            var_id_key = col_id_key + "__" + "__".join(tok["path"])
            real_var_id = existing_ids.get(var_id_key)

            tok_type  = tok.get("$type", "number")
            var_type  = "COLOR" if tok_type == "color" else "FLOAT"
            raw_value = tok["$value"]
            figma_value = hex_to_figma(raw_value) if var_type == "COLOR" else float(raw_value)

            if real_var_id:
                # Variable exists — just update its value
                var_ref = real_var_id
            else:
                var_ref = var_id_key  # temporary ID
                variables_payload.append({
                    "id":                   var_ref,
                    "action":               "CREATE",
                    "name":                 var_name,
                    "variableCollectionId": col_ref,
                    "resolvedType":         var_type,
                    "description":          tok.get("$description", ""),
                })

            values_payload.append({
                "variableId": var_ref,
                "modeId":     mode_ref,
                "value":      figma_value,
            })

    return {
        "variableCollections": collections_payload,
        "variableModes":       modes_payload,
        "variables":           variables_payload,
        "variableModeValues":  values_payload,
    }


# ─── Main ──────────────────────────────────────────────────────────────────────

def main():
    api_token = os.environ.get("FIGMA_API_TOKEN")
    file_key  = os.environ.get("FIGMA_FILE_KEY")

    if not api_token or not file_key:
        print("Error: set FIGMA_API_TOKEN and FIGMA_FILE_KEY environment variables.", file=sys.stderr)
        sys.exit(1)

    if not TOKENS_FILE.exists():
        print(f"Error: {TOKENS_FILE} not found.", file=sys.stderr)
        sys.exit(1)

    with open(TOKENS_FILE) as f:
        tokens = json.load(f)

    existing_ids: dict = {}
    if IDS_FILE.exists():
        with open(IDS_FILE) as f:
            existing_ids = json.load(f)

    payload = build_payload(tokens, existing_ids)

    leaf_count = sum(
        len(tokens_for_collection(tokens, col["top_keys"]))
        for col in COLLECTIONS
    )
    print(f"Pushing {leaf_count} tokens to Figma file {file_key!r} …")

    resp = figma_request(
        "POST",
        f"/files/{file_key}/variables",
        api_token,
        payload,
    )

    # Merge returned real IDs into our ID map
    temp_to_real: dict = resp.get("meta", {}).get("tempIdToRealId", {})
    existing_ids.update(temp_to_real)

    IDS_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(IDS_FILE, "w") as f:
        json.dump(existing_ids, f, indent=2)

    collections_created = len(payload["variableCollections"])
    vars_created        = len(payload["variables"])
    vals_pushed         = len(payload["variableModeValues"])

    print(f"✓ Collections created/updated : {collections_created or '(existing)'}")
    print(f"✓ Variables created           : {vars_created}")
    print(f"✓ Values pushed               : {vals_pushed}")
    print(f"✓ ID map saved to {IDS_FILE.relative_to(REPO_ROOT)}")


if __name__ == "__main__":
    main()

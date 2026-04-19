#!/usr/bin/env python3
"""
generate_plugin.py
Updates the embedded TOKENS constant inside figma-plugin/code.js
by reading the current values from tokens/tokens.json.

Usage:
    python3 scripts/generate_plugin.py

Run this alongside generate_swift.py any time tokens/tokens.json changes.
"""

import json
import re
import sys
from pathlib import Path

REPO_ROOT   = Path(__file__).resolve().parent.parent
TOKENS_FILE = REPO_ROOT / "tokens" / "tokens.json"
PLUGIN_CODE = REPO_ROOT / "figma-plugin" / "code.js"


def build_tokens_block(tokens: dict) -> str:
    lines = ["// TOKENS_START", "const TOKENS = {"]

    # ── Spacing ──────────────────────────────────────────────────────────────
    spacing = tokens.get("spacing", {})
    lines.append("  spacing: [")
    for key in ["xs", "sm", "md", "lg", "xl", "xxl", "xxxl", "max"]:
        tok = spacing.get(key)
        if tok:
            val = tok.get("$value", 0)
            lines.append(f"    {{ name: '{key}', value: {val} }},")
    lines.append("  ],")

    # ── Radius ───────────────────────────────────────────────────────────────
    radius = tokens.get("radius", {})
    lines.append("  radius: [")
    for key in ["xs", "sm", "md", "lg"]:
        tok = radius.get(key)
        if tok:
            val = tok.get("$value", 0)
            lines.append(f"    {{ name: '{key}', value: {val} }},")
    lines.append("  ],")

    # ── Typography ────────────────────────────────────────────────────────────
    typo_root   = tokens.get("typography", {})
    family      = typo_root.get("family", {})
    display_fam = family.get("display", {}).get("$value", "Fraunces")
    body_fam    = family.get("body",    {}).get("$value", "DM Sans")
    weight      = typo_root.get("weight", {})
    w_regular   = weight.get("regular",  {}).get("$value", "Regular")
    w_semibold  = weight.get("semibold", {}).get("$value", "SemiBold")
    w_bold      = weight.get("bold",     {}).get("$value", "Bold")
    typo_sizes  = typo_root.get("size", {})
    size_labels = [
        ("xs", "XS"), ("sm", "SM"), ("base", "Base"), ("md", "MD"),
        ("lg", "LG"), ("xl", "XL"), ("xxl", "XXL"), ("hero", "Hero"),
    ]
    lines.append("  typography: {")
    lines.append(f"    displayFamily: '{display_fam}',")
    lines.append(f"    bodyFamily:    '{body_fam}',")
    lines.append( "    weight: {")
    lines.append(f"      regular:  '{w_regular}',")
    lines.append(f"      semibold: '{w_semibold}',")
    lines.append(f"      bold:     '{w_bold}',")
    lines.append( "    },")
    lines.append( "    sizes: [")
    for key, display in size_labels:
        tok = typo_sizes.get(key)
        if tok:
            val = tok.get("$value", 0)
            lines.append(f"      {{ name: '{display}', value: {val} }},")
    lines.append("    ],")
    lines.append("  },")

    # ── Shadows ───────────────────────────────────────────────────────────────
    shadow = tokens.get("shadow", {})
    lines.append("  shadows: [")
    order = [("standard", "Standard", False), ("accent", "Accent", True)]
    for key, display, is_accent in order:
        variant = shadow.get(key)
        if not variant:
            continue
        opacity = variant.get("opacity", {}).get("$value", 0.2)
        blur    = variant.get("radius",  {}).get("$value", 4)
        y       = variant.get("y",       {}).get("$value", 2)
        js_bool = "true" if is_accent else "false"
        lines.append(
            f"    {{ name: '{display}', opacity: {opacity}, blur: {blur}, "
            f"y: {y}, isAccent: {js_bool} }},"
        )
    lines.append("  ],")

    lines.append("};")
    lines.append("// TOKENS_END")
    return "\n".join(lines)


def main():
    if not TOKENS_FILE.exists():
        print(f"Error: {TOKENS_FILE} not found.", file=sys.stderr)
        sys.exit(1)

    if not PLUGIN_CODE.exists():
        print(f"Error: {PLUGIN_CODE} not found.", file=sys.stderr)
        sys.exit(1)

    with open(TOKENS_FILE) as f:
        tokens = json.load(f)

    new_block = build_tokens_block(tokens)

    with open(PLUGIN_CODE) as f:
        code = f.read()

    pattern = r"// TOKENS_START.*?// TOKENS_END"
    if not re.search(pattern, code, flags=re.DOTALL):
        print("Error: TOKENS_START / TOKENS_END markers not found in code.js.", file=sys.stderr)
        sys.exit(1)

    updated = re.sub(pattern, new_block, code, flags=re.DOTALL)

    with open(PLUGIN_CODE, "w") as f:
        f.write(updated)

    print(f"✓ Updated TOKENS block in {PLUGIN_CODE.relative_to(REPO_ROOT)}")


if __name__ == "__main__":
    main()

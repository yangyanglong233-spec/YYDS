#!/usr/bin/env python3
"""
generate_swift.py
Transforms tokens/tokens.json → Yarn&Yarn/DesignSystem/DesignTokens.swift

Usage:
    python3 scripts/generate_swift.py

No external dependencies — stdlib only.
"""

import json
import os
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
TOKENS_FILE = REPO_ROOT / "tokens" / "tokens.json"
OUTPUT_FILE = REPO_ROOT / "Yarn&Yarn" / "DesignSystem" / "DesignTokens.swift"


# ─── Helpers ───────────────────────────────────────────────────────────────────

def hex_to_rgb_floats(hex_color: str) -> tuple[float, float, float]:
    """Convert '#RRGGBB' to (r, g, b) floats in [0, 1]."""
    h = hex_color.lstrip("#")
    if len(h) != 6:
        raise ValueError(f"Unsupported color format: {hex_color!r}")
    r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
    return r / 255.0, g / 255.0, b / 255.0


def swift_color(hex_color: str) -> str:
    """Return a SwiftUI Color initializer string from a hex color."""
    r, g, b = hex_to_rgb_floats(hex_color)
    return f"Color(red: {r:.2f}, green: {g:.2f}, blue: {b:.2f})"


def swift_cgfloat(value) -> str:
    """Return a CGFloat literal. Integers are emitted without decimal."""
    if isinstance(value, int) or float(value) == int(value):
        return str(int(value))
    return str(value)


def camel(s: str) -> str:
    """Convert snake_case or kebab-case to lowerCamelCase."""
    parts = s.replace("-", "_").split("_")
    return parts[0] + "".join(p.title() for p in parts[1:])


# ─── Section generators ────────────────────────────────────────────────────────

def counter_colors_section(counter: dict) -> list[str]:
    lines = ["    // MARK: - Colors", "", "    enum Colors {", "",
             "        /// Named palette for counter marker badges",
             "        enum Counter {"]
    name_list = []
    for name, token in counter.items():
        if name.startswith("$"):
            continue
        color_str = swift_color(token["$value"])
        pad = max(0, 12 - len(name))
        lines.append(f'            static let {name}{" " * pad} = {color_str}')
        name_list.append(name)

    lines += [
        "",
        "            /// All counter colors in palette order",
        "            static let all: [(name: String, color: Color)] = [",
    ]
    chunks = [name_list[i:i+3] for i in range(0, len(name_list), 3)]
    for chunk in chunks:
        pairs = ", ".join(f'("{n}", {n})' for n in chunk)
        lines.append(f"                {pairs},")
    # Remove trailing comma from last chunk line
    lines[-1] = lines[-1].rstrip(",")
    lines += [
        "            ]",
        "",
        '            /// Returns `.white` for dark counter backgrounds, `.black` for light ones.',
        "            static func textColor(for name: String) -> Color {",
        '                name == "plum" ? .white : .black',
        "            }",
        "",
        "            /// Looks up a counter color by name, falling back to sage.",
        "            static func color(named name: String) -> Color {",
        "                all.first { $0.name == name }?.color ?? sage",
        "            }",
        "        }",
    ]
    return lines


def status_section(status: dict) -> list[str]:
    mapping = {
        "notStarted": ".secondary",
        "inProgress": ".accentColor",
        "onHold":     ".orange",
        "completed":  ".green",
    }
    lines = ["", "        /// Project status indicator colors", "        enum Status {"]
    for key, swift_val in mapping.items():
        token = status.get(key, {})
        desc = token.get("$description", "")
        comment = f"  // {desc}" if desc else ""
        lines.append(f"            static let {key}: Color = {swift_val}{comment}")
    lines.append("        }")
    return lines


def category_section(category: dict) -> list[str]:
    mapping = {
        "basicStitches":      ".yellow",
        "increasesDecreases": ".orange",
        "castOnBindOff":      ".green",
        "cables":             ".purple",
        "colorwork":          ".pink",
        "lace":               ".cyan",
        "default":            ".blue",
    }
    lines = ["", "        /// Glossary category badge colors", "        enum Category {"]
    for key, swift_val in mapping.items():
        token = category.get(key, {})
        desc = token.get("$description", "")
        comment = f"  // {desc}" if desc else ""
        keyword_safe = f"`{key}`" if key == "default" else key
        lines.append(f"            static let {keyword_safe}: Color = {swift_val}{comment}")
    lines.append("        }")
    return lines


def marker_section(marker: dict) -> list[str]:
    mapping = {
        "blue":   ".blue",
        "green":  ".green",
        "red":    ".red",
        "yellow": ".orange",
        "purple": ".purple",
    }
    lines = [
        "",
        "        /// Legacy note marker colors",
        "        enum Marker {",
    ]
    for key, swift_val in mapping.items():
        desc = ""
        if key == "yellow":
            desc = "  // orange for better contrast"
        lines.append(f"            static let {key}: Color = {swift_val}{desc}")

    lines += [
        "",
        "            static func color(named name: String) -> Color {",
        "                switch name {",
    ]
    for key in mapping:
        lines.append(f'                case "{key}": return {key}')
    lines += [
        "                default:       return blue",
        "                }",
        "            }",
        "        }",
        "    }",  # close Colors
    ]
    return lines


def typography_section(typo: dict) -> list[str]:
    size   = typo.get("size",   {})
    weight = typo.get("weight", {})
    family = typo.get("family", {})

    # Figma weight name → SwiftUI Font.Weight
    weight_map = {
        "Regular":   ".regular",
        "Medium":    ".medium",
        "SemiBold":  ".semibold",
        "Semi Bold": ".semibold",
        "Bold":      ".bold",
        "Italic":    ".regular",  # handled via Font.italic() modifier
        "Light":     ".light",
        "Extra Bold":".heavy",
        "Black":     ".black",
    }

    size_labels = {
        "xs": "sizeXS", "sm": "sizeSM", "base": "sizeBase", "md": "sizeMD",
        "lg": "sizeLG", "xl": "sizeXL", "xxl": "sizeXXL", "hero": "sizeHero",
    }

    lines = ["", "    // MARK: - Typography", "", "    enum Typography {"]

    # Families (now a nested dict with display/body keys)
    display_val = family.get("display", {}).get("$value", "Fraunces")
    body_val    = family.get("body",    {}).get("$value", "DM Sans")
    display_desc = family.get("display", {}).get("$description", "")
    body_desc    = family.get("body",    {}).get("$description", "")
    lines += [
        "        // MARK: Families",
        "        /// Download from fonts.google.com, add .ttf files to Xcode + register in Info.plist",
        f'        /// {display_desc}',
        f'        static let displayFamily = "{display_val}"',
        f'        /// {body_desc}',
        f'        static let bodyFamily    = "{body_val}"',
        "",
        "        /// Convenience — returns Font.custom() for display (headers/titles)",
        "        static func display(_ size: CGFloat, weight: Font.Weight = Weight.bold) -> Font {",
        f'            Font.custom(displayFamily, size: size).weight(weight)',
        "        }",
        "",
        "        /// Convenience — returns Font.custom() for body (UI text)",
        "        static func body(_ size: CGFloat, weight: Font.Weight = Weight.regular) -> Font {",
        f'            Font.custom(bodyFamily, size: size).weight(weight)',
        "        }",
        "",
    ]

    # Weights
    if weight:
        lines.append("        // MARK: Weights")
        lines.append("        enum Weight {")
        for key in ["regular", "semibold", "bold"]:
            tok = weight.get(key, {})
            figma_val = tok.get("$value", "")
            swift_val = weight_map.get(figma_val, ".regular")
            lines.append(f'            static let {key}: Font.Weight = {swift_val}  // Figma: "{figma_val}"')
        lines.append("        }")
        lines.append("")

    # Sizes
    lines.append("        // MARK: Sizes")
    lines.append("        /// Font size scale (points)")
    for key, swift_name in size_labels.items():
        tok = size.get(key, {})
        val = swift_cgfloat(tok.get("$value", 0))
        desc = tok.get("$description", "")
        comment = f"  // {desc}" if desc else ""
        lines.append(f"        static let {swift_name}: CGFloat = {val}{comment}")

    lines.append("    }")
    return lines


def spacing_section(spacing: dict) -> list[str]:
    order = ["xs", "sm", "md", "lg", "xl", "xxl", "xxxl", "max"]
    lines = ["", "    // MARK: - Spacing", "", "    enum Spacing {"]
    for key in order:
        token = spacing.get(key, {})
        val = swift_cgfloat(token.get("$value", 0))
        lines.append(f"        static let {key}: CGFloat = {val}")
    lines.append("    }")
    return lines


def radius_section(radius: dict) -> list[str]:
    order = ["xs", "sm", "md", "lg"]
    descs = {
        "xs": "text highlights, small chips",
        "sm": "text fields, small elements",
        "md": "search bar",
        "lg": "cards, buttons, backgrounds",
    }
    lines = ["", "    // MARK: - Radius", "", "    enum Radius {"]
    for key in order:
        token = radius.get(key, {})
        val = swift_cgfloat(token.get("$value", 0))
        lines.append(f"        static let {key}: CGFloat = {val}  // {descs[key]}")
    lines.append("    }")
    return lines


def shadow_section(shadow: dict) -> list[str]:
    lines = ["", "    // MARK: - Shadow", "", "    enum Shadow {"]
    for variant_name, variant in shadow.items():
        if variant_name.startswith("$"):
            continue
        lines.append(f"        enum {variant_name.capitalize()} {{")
        for prop, token in variant.items():
            if prop.startswith("$"):
                continue
            val = token.get("$value", 0)
            if prop == "opacity":
                lines.append(f"            static let opacity: Double = {val}")
            else:
                lines.append(f"            static let {prop}: CGFloat = {swift_cgfloat(val)}")
        lines.append("        }")
    lines.append("    }")
    return lines


# ─── Main ──────────────────────────────────────────────────────────────────────

def generate(tokens: dict) -> str:
    lines = [
        "// DesignTokens.swift",
        "// Yarn&Yarn",
        "//",
        "// AUTO-GENERATED — do not edit this file by hand.",
        "// Source of truth: tokens/tokens.json",
        "// Regenerate with: python3 scripts/generate_swift.py",
        "",
        "import SwiftUI",
        "",
        "enum DesignTokens {",
        "",
    ]

    colors = tokens.get("colors", {})
    lines += counter_colors_section(colors.get("counter", {}))
    lines += status_section(colors.get("status", {}))
    lines += category_section(colors.get("category", {}))
    lines += marker_section(colors.get("marker", {}))
    lines += typography_section(tokens.get("typography", {}))
    lines += spacing_section(tokens.get("spacing", {}))
    lines += radius_section(tokens.get("radius", {}))
    lines += shadow_section(tokens.get("shadow", {}))

    lines += ["}", ""]  # close DesignTokens
    return "\n".join(lines)


def main():
    if not TOKENS_FILE.exists():
        print(f"Error: tokens file not found at {TOKENS_FILE}", file=sys.stderr)
        sys.exit(1)

    with open(TOKENS_FILE) as f:
        tokens = json.load(f)

    swift_code = generate(tokens)

    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(OUTPUT_FILE, "w") as f:
        f.write(swift_code)

    print(f"✓ Generated {OUTPUT_FILE.relative_to(REPO_ROOT)}")


if __name__ == "__main__":
    main()

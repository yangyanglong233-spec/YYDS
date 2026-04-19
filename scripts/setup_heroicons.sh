#!/usr/bin/env bash
# scripts/setup_heroicons.sh
# Downloads required Heroicons v2 SVG files and creates Xcode asset imagesets.
#
# Run from the project root:
#   bash scripts/setup_heroicons.sh
#
# Idempotent — re-running skips already-downloaded icons.
# Add new icons by appending download_icon calls at the bottom.

set -e

BASE_URL="https://raw.githubusercontent.com/tailwindlabs/heroicons/master/src"
ASSETS_DIR="Yarn&Yarn/Assets.xcassets/Icons"

# ── Create root Icons group if needed ───────────────────────────────────────
mkdir -p "$ASSETS_DIR"
cat > "$ASSETS_DIR/Contents.json" << 'EOF'
{
  "info": {
    "author": "xcode",
    "version": 1
  }
}
EOF

# ── Helper ───────────────────────────────────────────────────────────────────
# download_icon <style> <heroicon-name>
#   style:  outline | solid | mini
#   name:   kebab-case icon name, e.g. magnifying-glass
#
# Asset catalog name:  hi-<style>-<name>
# URL paths:
#   outline/solid → src/24/<style>/<name>.svg
#   mini          → src/20/solid/<name>.svg

download_icon() {
  local style="$1"
  local name="$2"
  local asset_name="hi-${style}-${name}"
  local dest="${ASSETS_DIR}/${asset_name}.imageset"

  if [ -f "${dest}/icon.svg" ]; then
    echo "  ✓ ${asset_name} (cached)"
    return
  fi

  mkdir -p "$dest"

  if [ "$style" = "mini" ]; then
    local url="${BASE_URL}/20/solid/${name}.svg"
  else
    local url="${BASE_URL}/24/${style}/${name}.svg"
  fi

  if curl -sf "$url" -o "${dest}/icon.svg"; then
    echo "  ↓ ${asset_name}"
  else
    echo "  ✗ ${asset_name}  (not found — check icon name at heroicons.com)"
    rm -rf "$dest"
    return
  fi

  cat > "${dest}/Contents.json" << 'EOF'
{
  "images": [
    {
      "filename": "icon.svg",
      "idiom": "universal"
    }
  ],
  "info": {
    "author": "xcode",
    "version": 1
  },
  "properties": {
    "preserves-vector-representation": true,
    "template-rendering-intent": "template"
  }
}
EOF
}

# ── Outline (24 px) ──────────────────────────────────────────────────────────
echo "📥  Downloading Heroicons v2 — Outline (24 px)…"
download_icon outline magnifying-glass
download_icon outline magnifying-glass-circle
download_icon outline plus
download_icon outline minus
download_icon outline check
download_icon outline pencil
download_icon outline pencil-square
download_icon outline trash
download_icon outline photo
download_icon outline document
download_icon outline clock
download_icon outline ellipsis-horizontal-circle
download_icon outline video-camera-slash
download_icon outline pause-circle
download_icon outline squares-2x2
download_icon outline list-bullet
download_icon outline lock-closed

# ── Solid (24 px) ────────────────────────────────────────────────────────────
echo ""
echo "📥  Downloading Heroicons v2 — Solid (24 px)…"
download_icon solid x-circle
download_icon solid lock-closed
download_icon solid document
download_icon solid photo
download_icon solid clock
download_icon solid check-circle
download_icon solid minus-circle
download_icon solid plus-circle
download_icon solid pause-circle

# ── Mini (20 px, thicker strokes) ────────────────────────────────────────────
echo ""
echo "📥  Downloading Heroicons v2 — Mini (20 px)…"
download_icon mini chevron-right

# ── Summary ──────────────────────────────────────────────────────────────────
count=$(find "$ASSETS_DIR" -name "Contents.json" | grep -v "^${ASSETS_DIR}/Contents" | wc -l | tr -d ' ')
echo ""
echo "✅  Done — ${count} imageset(s) ready in ${ASSETS_DIR}/"
echo ""
echo "Next steps:"
echo "  1. In Xcode, right-click Yarn&Yarn/DesignSystem/ → Add Files → Icons.swift"
echo "  2. Build (⌘B) and confirm 0 'could not load image' warnings"

# Design Token Scripts

Two-way sync between `tokens/tokens.json` and Figma native Variables.

```
tokens/tokens.json  ◄─────────────────────────────────────────────┐
       │                                                           │
  generate_swift.py                                  import_from_figma.py
       │                                                           │
       ▼                                                           │
DesignSystem/DesignTokens.swift      export_to_figma.py ─────► Figma Variables
       │                                    ▲               (designer edits here)
  used by Swift source files          tokens.json
```

---

## Prerequisites

### 1. Figma Plan
The Variables REST API requires a **Professional or Enterprise** Figma plan.

### 2. Personal Access Token
1. Open Figma → Account Settings → **Security** → Personal access tokens
2. Click **Generate new token**
3. Set scopes: `file_variables:read` + `file_variables:write`
4. Copy the token

### 3. File Key
From your Figma file URL:
```
https://www.figma.com/design/XXXXXXXXXXXX/My-File
                              ^^^^^^^^^^^^
                              This is FIGMA_FILE_KEY
```

### 4. Environment Variables
```sh
export FIGMA_API_TOKEN=figd_xxxxxxxxxxxxxxxx
export FIGMA_FILE_KEY=XXXXXXXXXXXX
```

Add these to your shell profile (`~/.zshrc`) or use a `.env` file (never commit it).

---

## Scripts

### `generate_swift.py` — Offline token → Swift code
```sh
python3 scripts/generate_swift.py
```
Reads `tokens/tokens.json` and regenerates `Yarn&Yarn/DesignSystem/DesignTokens.swift`.
Use this when you edit `tokens.json` directly without going through Figma.

---

### `export_to_figma.py` — Push tokens to Figma
```sh
python3 scripts/export_to_figma.py
```
- Creates four Variable Collections in your Figma file: **Colors**, **Typography**, **Spacing**, **Radius / Shadow**
- Saves a Figma ID map to `tokens/.figma_ids.json` — **commit this file** so future runs update rather than duplicate

Run once for initial setup. Re-run any time you add new tokens.

---

### `import_from_figma.py` — Pull Figma changes back to code
```sh
python3 scripts/import_from_figma.py
```
1. Fetches current variable values from Figma
2. Updates `tokens/tokens.json` with any changed values
3. Runs `generate_swift.py` to regenerate `DesignTokens.swift`
4. Prints a diff of what changed

After running, review `git diff` and commit `tokens.json` + `DesignTokens.swift` together.

---

## Typical Workflow

### Initial Setup (one time)
```sh
# 1. Export current Swift tokens to Figma
python3 scripts/export_to_figma.py

# 2. Open Figma, connect Variables to your component properties
```

### Designer Makes a Visual Change
```
Designer changes a color/spacing/font value in Figma Variables
  ↓
python3 scripts/import_from_figma.py
  ↓
Review git diff
  ↓
git add tokens/tokens.json Yarn&Yarn/DesignSystem/DesignTokens.swift
git commit -m "chore: sync design tokens from Figma"
  ↓
Build in Xcode — new values are live
```

### Developer Adds a New Token
```
1. Add entry to tokens/tokens.json
2. python3 scripts/generate_swift.py   ← update Swift
3. python3 scripts/export_to_figma.py  ← push to Figma
4. Commit tokens.json + DesignTokens.swift + .figma_ids.json
```

---

## What Can Be Changed in Figma

**Allowed** (syncs back to code):
- Any color value in Colors collections
- Any number value in Typography / Spacing / Radius collections

**Not allowed** (must be done in Swift):
- Adding or removing tokens (structural changes)
- Renaming tokens
- Changing which component uses which token
- AccentColor — managed separately in `Assets.xcassets/AccentColor.colorset`

---

## Files

| File | Purpose | Commit? |
|------|---------|---------|
| `tokens/tokens.json` | Canonical token values | Yes |
| `tokens/.figma_ids.json` | Figma real ID map | Yes |
| `Yarn&Yarn/DesignSystem/DesignTokens.swift` | Auto-generated Swift | Yes (generated) |
| `scripts/generate_swift.py` | JSON → Swift transformer | Yes |
| `scripts/export_to_figma.py` | Push to Figma | Yes |
| `scripts/import_from_figma.py` | Pull from Figma | Yes |

> **Never edit `DesignTokens.swift` by hand.** Changes will be overwritten on the next import.

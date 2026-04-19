// YY Design System Docs — Figma Plugin
// Generates a documentation page from local paint styles + embedded token values.
// Run scripts/generate_plugin.py after changing tokens/tokens.json.

figma.showUI(__html__, { width: 340, height: 340, title: 'YY Design System Docs' });

// ─── Embedded tokens (auto-updated by scripts/generate_plugin.py) ─────────────
// TOKENS_START
const TOKENS = {
  spacing: [
    { name: 'xs', value: 4 },
    { name: 'sm', value: 6 },
    { name: 'md', value: 8 },
    { name: 'lg', value: 12 },
    { name: 'xl', value: 16 },
    { name: 'xxl', value: 20 },
    { name: 'xxxl', value: 24 },
    { name: 'max', value: 30 },
  ],
  radius: [
    { name: 'xs', value: 4 },
    { name: 'sm', value: 8 },
    { name: 'md', value: 10 },
    { name: 'lg', value: 12 },
  ],
  typography: {
    displayFamily: 'Fraunces',
    bodyFamily:    'DM Sans',
    weight: {
      regular:  'Regular',
      semibold: 'SemiBold',
      bold:     'Bold',
    },
    sizes: [
      { name: 'XS', value: 10 },
      { name: 'SM', value: 12 },
      { name: 'Base', value: 14 },
      { name: 'MD', value: 16 },
      { name: 'LG', value: 18 },
      { name: 'XL', value: 22 },
      { name: 'XXL', value: 36 },
      { name: 'Hero', value: 48 },
    ],
  },
  shadows: [
    { name: 'Standard', opacity: 0.2, blur: 4, y: 2, isAccent: false },
    { name: 'Accent', opacity: 0.35, blur: 12, y: 5, isAccent: true },
  ],
};
// TOKENS_END


// ─── Helpers ──────────────────────────────────────────────────────────────────

const rgbToHex = (r, g, b) => {
  const h = v => Math.round(v * 255).toString(16).padStart(2, '0').toUpperCase();
  return `#${h(r)}${h(g)}${h(b)}`;
};

const solid = (r, g, b, a = 1) => [{ type: 'SOLID', color: { r, g, b }, opacity: a }];

// Vertical auto-layout frame, height auto-fits, width auto-fits
function vFrame(name, gap, padH = 0, padV = 0, bg = []) {
  const f = figma.createFrame();
  f.name = name;
  f.layoutMode = 'VERTICAL';
  f.itemSpacing = gap;
  f.paddingLeft = f.paddingRight = padH;
  f.paddingTop = f.paddingBottom = padV;
  f.primaryAxisSizingMode = 'AUTO';
  f.counterAxisSizingMode = 'AUTO';
  f.fills = bg;
  return f;
}

// Horizontal auto-layout frame
function hFrame(name, gap, padH = 0, padV = 0, crossAlign = 'CENTER', bg = []) {
  const f = figma.createFrame();
  f.name = name;
  f.layoutMode = 'HORIZONTAL';
  f.itemSpacing = gap;
  f.paddingLeft = f.paddingRight = padH;
  f.paddingTop = f.paddingBottom = padV;
  f.primaryAxisSizingMode = 'AUTO';
  f.counterAxisSizingMode = 'AUTO';
  f.counterAxisAlignItems = crossAlign;
  f.fills = bg;
  return f;
}

// Shorthand weight aliases sourced from TOKENS
const W = {
  r:  () => TOKENS.typography.weight.regular,
  sb: () => TOKENS.typography.weight.semibold,
  b:  () => TOKENS.typography.weight.bold,
};
const DISPLAY_FAMILY = () => TOKENS.typography.displayFamily;
const BODY_FAMILY    = () => TOKENS.typography.bodyFamily;

// Create a body text node (DM Sans)
function makeText(content, size, style, r = 0.08, g = 0.08, b = 0.08, family = null) {
  const t = figma.createText();
  t.fontName = { family: family || BODY_FAMILY(), style };
  t.fontSize = size;
  t.characters = String(content);
  t.fills = solid(r, g, b);
  return t;
}

// Create a display/header text node (Fraunces)
function makeDisplayText(content, size, style, r = 0.08, g = 0.08, b = 0.08) {
  return makeText(content, size, style, r, g, b, DISPLAY_FAMILY());
}

// Create a fixed-width body text node with auto-height
function makeTextFixed(content, size, style, width, r = 0.08, g = 0.08, b = 0.08) {
  const t = makeText(content, size, style, r, g, b);
  t.textAutoResize = 'HEIGHT';
  t.resize(width, 20);
  return t;
}

// Group paint styles by second path segment (e.g. "colors/counter/sage" → group "counter")
function groupPaintStyles(styles) {
  const groups = {};
  for (const style of styles) {
    if (!style.paints.length) continue;
    const paint = style.paints[0];
    if (paint.type !== 'SOLID') continue;
    const parts = style.name.split('/');
    let group, tokenName;
    if (parts.length >= 3 && parts[0] === 'colors') {
      group     = parts[1];
      tokenName = parts.slice(2).join('/');
    } else if (parts.length === 2) {
      group     = parts[0];
      tokenName = parts[1];
    } else {
      group     = 'other';
      tokenName = style.name;
    }
    if (!groups[group]) groups[group] = [];
    groups[group].push({ name: tokenName, r: paint.color.r, g: paint.color.g, b: paint.color.b });
  }
  return groups;
}


// ─── Section builders ─────────────────────────────────────────────────────────
// IMPORTANT: always appendChild(node) BEFORE setting node.layoutSizingHorizontal

const CONTENT_W = 1280; // content width

function buildHeader() {
  const f = figma.createFrame();
  f.name = 'Header';
  f.layoutMode = 'VERTICAL';
  f.itemSpacing = 10;
  f.paddingLeft = f.paddingRight = 48;
  f.paddingTop = f.paddingBottom = 40;
  f.primaryAxisSizingMode = 'AUTO';
  f.counterAxisSizingMode = 'FIXED';
  f.resize(CONTENT_W,100);
  f.fills = solid(0.04, 0.04, 0.10);

  const title = makeDisplayText('🧶  Yarn & Yarn Design System', 36, W.b(), 1, 1, 1);
  f.appendChild(title);
  title.layoutSizingHorizontal = 'FILL';

  const sub = makeText(
    'Auto-generated from tokens/tokens.json · Run generate_plugin.py to refresh token values',
    13, W.r(), 0.55, 0.58, 0.65
  );
  f.appendChild(sub);
  sub.layoutSizingHorizontal = 'FILL';

  return f;
}

function buildSwatchCard(name, r, g, b) {
  const card = vFrame(`swatch-${name}`, 8);
  card.counterAxisAlignItems = 'CENTER';
  card.paddingBottom = 4;

  const circle = figma.createEllipse();
  circle.resize(60, 60);
  circle.fills = solid(r, g, b);
  card.appendChild(circle);

  card.appendChild(makeText(name, 11, W.sb()));
  card.appendChild(makeText(rgbToHex(r, g, b), 10, W.r(), 0.5, 0.5, 0.5));

  return card;
}

function buildColorSection(paintStyles) {
  const section = figma.createFrame();
  section.name = 'Colors';
  section.layoutMode = 'VERTICAL';
  section.itemSpacing = 36;
  section.primaryAxisSizingMode = 'AUTO';
  section.counterAxisSizingMode = 'FIXED';
  section.resize(CONTENT_W,100);
  section.fills = [];

  const title = makeDisplayText('Colors', 26, W.b());
  section.appendChild(title);
  title.layoutSizingHorizontal = 'FILL';

  const groups = groupPaintStyles(paintStyles);
  const groupNames = Object.keys(groups).sort();

  if (groupNames.length === 0) {
    const warn = makeText(
      '⚠️  No color styles found. In Tokens Studio: Tokens tab → Styles & Variables → Export Styles.',
      13, W.r(), 0.7, 0.35, 0.1
    );
    section.appendChild(warn);
    warn.layoutSizingHorizontal = 'FILL';
    return section;
  }

  for (const groupName of groupNames) {
    const groupBlock = figma.createFrame();
    groupBlock.name = `group-${groupName}`;
    groupBlock.layoutMode = 'VERTICAL';
    groupBlock.itemSpacing = 14;
    groupBlock.primaryAxisSizingMode = 'AUTO';
    groupBlock.counterAxisSizingMode = 'FIXED';
    groupBlock.resize(CONTENT_W,100);
    groupBlock.fills = [];

    const label = makeText(
      groupName.charAt(0).toUpperCase() + groupName.slice(1),
      13, W.sb(), 0.4, 0.4, 0.4
    );
    groupBlock.appendChild(label);
    label.layoutSizingHorizontal = 'FILL';

    const row = hFrame(`swatches-${groupName}`, 12, 0, 0, 'MIN');
    groupBlock.appendChild(row);
    // Note: set layoutSizingHorizontal AFTER appendChild
    row.layoutSizingHorizontal = 'FILL';

    for (const { name, r, g, b } of groups[groupName]) {
      row.appendChild(buildSwatchCard(name, r, g, b));
    }

    section.appendChild(groupBlock);
    groupBlock.layoutSizingHorizontal = 'FILL';
  }

  return section;
}

function buildSpacingSection() {
  const section = figma.createFrame();
  section.name = 'Spacing';
  section.layoutMode = 'VERTICAL';
  section.itemSpacing = 14;
  section.primaryAxisSizingMode = 'AUTO';
  section.counterAxisSizingMode = 'FIXED';
  section.resize(CONTENT_W,100);
  section.fills = [];

  const title = makeDisplayText('Spacing', 26, W.b());
  section.appendChild(title);
  title.layoutSizingHorizontal = 'FILL';

  const sub = makeText('Scale in points (pt)', 12, W.r(), 0.55, 0.55, 0.55);
  section.appendChild(sub);

  for (const { name, value } of TOKENS.spacing) {
    const row = hFrame(`spacing-${name}`, 16, 0, 4, 'CENTER');
    section.appendChild(row);
    row.layoutSizingHorizontal = 'FILL';

    const nameLabel = makeTextFixed(name, 13, W.sb(), 52);
    row.appendChild(nameLabel);

    const valLabel = makeTextFixed(`${value}pt`, 12, W.r(), 40, 0.55, 0.55, 0.55);
    row.appendChild(valLabel);

    const bar = figma.createRectangle();
    bar.resize(Math.max(value * 4, 4), 8);
    bar.cornerRadius = 4;
    bar.fills = solid(0.0, 0.48, 1.0);
    row.appendChild(bar);
  }

  return section;
}

function buildRadiusSection() {
  const section = figma.createFrame();
  section.name = 'Corner Radius';
  section.layoutMode = 'VERTICAL';
  section.itemSpacing = 24;
  section.primaryAxisSizingMode = 'AUTO';
  section.counterAxisSizingMode = 'FIXED';
  section.resize(CONTENT_W,100);
  section.fills = [];

  const title = makeDisplayText('Corner Radius', 26, W.b());
  section.appendChild(title);
  title.layoutSizingHorizontal = 'FILL';

  const row = hFrame('radius-row', 24, 0, 0, 'MIN');
  section.appendChild(row);

  for (const { name, value } of TOKENS.radius) {
    const item = vFrame(`radius-${name}`, 10);
    item.counterAxisAlignItems = 'CENTER';
    row.appendChild(item);

    const box = figma.createRectangle();
    box.resize(80, 80);
    box.cornerRadius = value;
    box.fills = solid(1, 1, 1);
    box.effects = [{
      type: 'DROP_SHADOW',
      color: { r: 0, g: 0, b: 0, a: 0.10 },
      offset: { x: 0, y: 2 },
      radius: 8,
      spread: 0,
      visible: true,
      blendMode: 'NORMAL',
    }];
    item.appendChild(box);
    item.appendChild(makeText(name, 12, W.sb()));
    item.appendChild(makeText(`${value}pt`, 11, W.r(), 0.55, 0.55, 0.55));
  }

  return section;
}

function buildShadowSection() {
  const section = figma.createFrame();
  section.name = 'Shadows';
  section.layoutMode = 'VERTICAL';
  section.itemSpacing = 24;
  section.primaryAxisSizingMode = 'AUTO';
  section.counterAxisSizingMode = 'FIXED';
  section.resize(CONTENT_W,100);
  section.fills = [];

  const title = makeDisplayText('Shadows', 26, W.b());
  section.appendChild(title);
  title.layoutSizingHorizontal = 'FILL';

  const row = hFrame('shadow-row', 40, 0, 0, 'MIN');
  section.appendChild(row);

  for (const { name, opacity, blur, y, isAccent } of TOKENS.shadows) {
    const item = vFrame(`shadow-${name}`, 10);
    item.counterAxisAlignItems = 'CENTER';
    row.appendChild(item);

    const card = figma.createRectangle();
    card.resize(140, 90);
    card.cornerRadius = 12;
    card.fills = solid(1, 1, 1);
    card.effects = [{
      type: 'DROP_SHADOW',
      color: isAccent
        ? { r: 0.0, g: 0.48, b: 1.0, a: opacity }
        : { r: 0.0, g: 0.00, b: 0.0, a: opacity },
      offset: { x: 0, y },
      radius: blur,
      spread: 0,
      visible: true,
      blendMode: 'NORMAL',
    }];
    item.appendChild(card);
    item.appendChild(makeText(name, 13, W.sb()));
    item.appendChild(makeText(
      `blur ${blur}  ·  y ${y}  ·  ${Math.round(opacity * 100)}% opacity`,
      11, W.r(), 0.55, 0.55, 0.55
    ));
  }

  return section;
}

function buildTypographySection() {
  const section = figma.createFrame();
  section.name = 'Typography';
  section.layoutMode = 'VERTICAL';
  section.itemSpacing = 0;
  section.primaryAxisSizingMode = 'AUTO';
  section.counterAxisSizingMode = 'FIXED';
  section.resize(CONTENT_W,100);
  section.fills = [];

  const title = makeDisplayText('Typography Scale', 26, W.b());
  section.appendChild(title);
  title.layoutSizingHorizontal = 'FILL';

  const sub = makeText(`Shown in ${DISPLAY_FAMILY()} (display) · ${BODY_FAMILY()} (body) — mirrors SF Pro on iOS/macOS`, 12, W.r(), 0.55, 0.55, 0.55);
  section.appendChild(sub);

  // Divider
  const divTop = figma.createRectangle();
  divTop.resize(CONTENT_W,1);
  divTop.fills = solid(0.88, 0.88, 0.88);
  section.appendChild(divTop);

  for (const { name, value } of TOKENS.typography.sizes) {
    const row = hFrame(`type-${name}`, 20, 0, 12, 'CENTER');
    section.appendChild(row);
    row.layoutSizingHorizontal = 'FILL';

    // Meta column (fixed 90px)
    const meta = vFrame(`meta-${name}`, 2);
    row.appendChild(meta);
    meta.layoutSizingHorizontal = 'FIXED';
    meta.resize(90, 10);

    meta.appendChild(makeText(name, 11, W.sb(), 0.4, 0.4, 0.4));
    meta.appendChild(makeText(`${value}pt`, 11, W.r(), 0.65, 0.65, 0.65));

    // Sample text — cap render size at 40pt so rows stay manageable
    const displaySize = Math.min(value, 40);
    const sample = makeText('The quick brown fox jumps', displaySize, W.r());
    row.appendChild(sample);
    sample.layoutSizingHorizontal = 'FILL';

    // Row divider
    const div = figma.createRectangle();
    div.resize(CONTENT_W,1);
    div.fills = solid(0.92, 0.92, 0.92);
    section.appendChild(div);
  }

  return section;
}


// ─── Main ─────────────────────────────────────────────────────────────────────

async function generateDocs() {
  // 0. Load all pages so we can access their .children
  await figma.loadAllPagesAsync();

  // 1. Load fonts (must happen before any text node creation)
  await Promise.all([
    // Body font (DM Sans)
    figma.loadFontAsync({ family: BODY_FAMILY(), style: W.r()  }),
    figma.loadFontAsync({ family: BODY_FAMILY(), style: W.sb() }),
    figma.loadFontAsync({ family: BODY_FAMILY(), style: W.b()  }),
    // Display font (Fraunces)
    figma.loadFontAsync({ family: DISPLAY_FAMILY(), style: W.r()  }),
    figma.loadFontAsync({ family: DISPLAY_FAMILY(), style: W.b()  }),
  ]);

  // 2. Find or recreate the docs page
  const PAGE_NAME = '🎨 Design System Docs';
  let docsPage = figma.root.children.find(p => p.name === PAGE_NAME);
  if (docsPage) {
    [...docsPage.children].forEach(c => c.remove());
  } else {
    docsPage = figma.createPage();
    docsPage.name = PAGE_NAME;
  }

  await figma.setCurrentPageAsync(docsPage);
  docsPage.backgrounds = [{ type: 'SOLID', color: { r: 0.95, g: 0.95, b: 0.97 } }];

  // 3. Build sections — no auto-layout needed on the page itself; absolute position each section
  const GAP = 80;
  const paintStyles = await figma.getLocalPaintStylesAsync();

  const sections = [
    buildHeader(),
    buildColorSection(paintStyles),
    buildSpacingSection(),
    buildRadiusSection(),
    buildShadowSection(),
    buildTypographySection(),
  ];

  // 4. Place sections at stacked Y positions
  let y = 80;
  for (const section of sections) {
    section.x = 80;
    section.y = y;
    docsPage.appendChild(section);
    y += section.height + GAP;
  }

  // 5. Zoom to fit
  figma.viewport.scrollAndZoomIntoView(sections);
}


// ─── Message handler ──────────────────────────────────────────────────────────

figma.ui.onmessage = async (msg) => {
  if (msg.type === 'GENERATE') {
    try {
      await generateDocs();
      figma.closePlugin('✅ Design System Docs generated!');
    } catch (err) {
      // Show the full error (Figma sometimes throws strings, not Error objects)
      const message = (err && err.message) ? err.message : String(err);
      figma.closePlugin('❌ ' + message);
    }
  }

  if (msg.type === 'CANCEL') {
    figma.closePlugin();
  }
};

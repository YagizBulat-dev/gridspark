---
name: Obsidian Arcade
colors:
  surface: '#0e1225'
  surface-dim: '#0e1225'
  surface-bright: '#34384d'
  surface-container-lowest: '#090d20'
  surface-container-low: '#161a2e'
  surface-container: '#1b1e32'
  surface-container-high: '#25293d'
  surface-container-highest: '#303448'
  on-surface: '#dee1fc'
  on-surface-variant: '#b9cacb'
  inverse-surface: '#dee1fc'
  inverse-on-surface: '#2b2f44'
  outline: '#849495'
  outline-variant: '#3b494b'
  surface-tint: '#00dbe9'
  primary: '#dbfcff'
  on-primary: '#00363a'
  primary-container: '#00f0ff'
  on-primary-container: '#006970'
  inverse-primary: '#006970'
  secondary: '#dcb8ff'
  on-secondary: '#480081'
  secondary-container: '#7701d0'
  on-secondary-container: '#dcb7ff'
  tertiary: '#fff4e8'
  on-tertiary: '#412d00'
  tertiary-container: '#ffd386'
  on-tertiary-container: '#7d5800'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#7df4ff'
  primary-fixed-dim: '#00dbe9'
  on-primary-fixed: '#002022'
  on-primary-fixed-variant: '#004f54'
  secondary-fixed: '#efdbff'
  secondary-fixed-dim: '#dcb8ff'
  on-secondary-fixed: '#2c0051'
  on-secondary-fixed-variant: '#6700b5'
  tertiary-fixed: '#ffdea8'
  tertiary-fixed-dim: '#ffba20'
  on-tertiary-fixed: '#271900'
  on-tertiary-fixed-variant: '#5e4200'
  background: '#0e1225'
  on-background: '#dee1fc'
  surface-variant: '#303448'
typography:
  display-score:
    fontFamily: Sora
    fontSize: 48px
    fontWeight: '800'
    lineHeight: 52px
    letterSpacing: -0.02em
  display-score-mobile:
    fontFamily: Sora
    fontSize: 36px
    fontWeight: '800'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Sora
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 38px
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Sora
    fontSize: 26px
    fontWeight: '700'
    lineHeight: 32px
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Sora
    fontSize: 22px
    fontWeight: '600'
    lineHeight: 28px
  headline-sm:
    fontFamily: Sora
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '500'
    lineHeight: 24px
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-numeric:
    fontFamily: Space Grotesk
    fontSize: 14px
    fontWeight: '700'
    lineHeight: 18px
    letterSpacing: 0.04em
  label-caps:
    fontFamily: Space Grotesk
    fontSize: 11px
    fontWeight: '700'
    lineHeight: 14px
    letterSpacing: 0.08em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 0.75rem
  gutter-tablet: 1rem
  margin: 1rem
  margin-tablet: 2rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2.5rem
---

## Brand & Style

This design system establishes an atmospheric, high-octane dark arcade visual identity tailored for a fast-paced spatial block puzzle experience. It fuses high-contrast arcade nostalgia with polished modern mobile ergonomics. 

- **Personality:** Hypnotic, electric, kinetic, and razor-sharp.
- **Target Audience:** Mobile puzzle enthusiasts seeking tactile sensory feedback, streak-driven progression, and a premium visual environment that avoids generic flat minimalism.
- **Aesthetic Movement:** Tactile Dark Glass & Neon Luminescence. Deep, light-absorbing obsidian backing plates create an infinite canvas, allowing translucent tinted glass layers, crisp specular perimeter highlights, and neon inner glows to drive immediate visual prioritization.
- **Emotional Response:** Flow-state immersion, electric excitement on combos, and a satisfying physical sense of mass and activation with every touch interaction.

## Colors

The palette revolves around deep void depths punctured by high-voltage emission tones. Contrast is strictly managed to ensure game state, puzzle matrix cells, and interactive states retain maximum visual acuity.

- **Primary (`#00F0FF` - Electric Cyan):** Core interface actions, active grid snapping indicators, primary energy gauges, and peak combo multipliers.
- **Secondary (`#8A2BE2` - Radiant Violet):** Secondary actions, depth framing, dimensional structural glows, and tier progression nodes.
- **Tertiary (`#FFB800` - Solar Amber):** High-stakes indicators, coin/star balances, active streak fire counters, and fever-mode triggers.
- **Accent Magenta (`#FF2A85` - Neon Pulse):** Game over alerts, critical countdowns, supercharged block blasts, and high-impact micro-interactions.
- **Neutral Base (`#0B0D17` to `#13172A`):** Deep obsidian-violet tones forming the root canvas, card surfaces, and dormant 8x8 cell slots.
- **Surface Elevation Layers:**
  - Canvas Root: `#0B0D17`
  - Elevated Container / Glass Deck: `#13172A` with 75% opacity and backdrop blur.
  - Interactive Cell Well (Empty slot): `#1A1F38` with inset dark shadow.

## Typography

Typography bridges futuristic geometry with immediate split-second legibility under fast play conditions:

- **Sora (Headlines & Big Scores):** Provides wide, rounded futuristic apexes that look punchy in large numerals and dramatic title banners. Always set tight with slight negative tracking for maximum cohesion.
- **Plus Jakarta Sans (Body & Context):** Soft, rounded grotesque providing clean reading across modal dialogs, quest logs, and game tooltips without visual fatigue.
- **Space Grotesk (Labels, Streaks & Counters):** Monospaced-leaning technical proportions ensure rapid glance value for timers, multipliers, stage counters, and coin values without layout jitter. Set all metadata labels in uppercase with deliberate letter spacing.

## Layout & Spacing

The interface implements a fixed portrait viewport optimized for thumb-reach ergonomics, centered around the 8x8 primary matrix.

- **Primary Structure:** Mobile portrait layouts conform to a 3-tier vertical stack:
  1. *Header Tier:* Profile, active streak flame, score HUD, and pause button (constrained to `margin`).
  2. *Game Board Tier:* Centered 1:1 aspect ratio container spanning edge-to-edge minus `margin * 2`. The 8x8 grid utilizes internal uniform `space-xs` (4px) gaps between blocks to retain clear delineation during active piece movement.
  3. *Tray & Staging Tier:* Three-slot dock below the board hosting unplaced polyomino pieces, spaced with `space-sm`.
- **Adaptation Rules:** On larger viewports or tablets, the puzzle canvas locks to a max-width of 480px, while HUD elements expand horizontally or dock into flanking wings with expanded margins (`margin-tablet`).

## Elevation & Depth

Visual depth is achieved through optical illumination, directional specular highlights, and physical button beveling rather than pure drop-shadow offsets:

- **Layer 0 (Canvas Base):** Deep, vignette-treated `#0B0D17` with a low-opacity radial ambient gradient emanating from board center (`#13172A`).
- **Layer 1 (Recessed Wells - Empty Grid Cells):** Inset shadows (`0 2px 4px rgba(0,0,0,0.6)`) paired with a 1px border at 8% white opacity, indicating receptive space.
- **Layer 2 (Floating Glass Decks):** 16px background blur, surface fill of `#13172A` at 80% opacity, framed with a 1px top-lit stroke (`rgba(255, 255, 255, 0.15)` top, transitioning to `rgba(255, 255, 255, 0.03)` bottom).
- **Layer 3 (Interactive Active Polyominoes & Floating Blocks):** Rendered with top specular highlights (`inset 0 1px 0 rgba(255,255,255,0.4)`), vivid core fills, and saturated color-matched bloom halos (`0 8px 20px -2px [color]`, 45% opacity).
- **Layer 4 (Modals & Victory Banners):** Heavy obsidian scrim (`rgba(11, 13, 23, 0.85)` + 20px blur), foreground elements rimmed with glowing electric cyan or solar amber outer glow (`0 0 24px rgba(0, 240, 255, 0.35)`).

## Shapes

The design uses a balanced rounded radius (`0.5rem` / `8px` base) to give interactive elements an arcade tactile presence without becoming overly pill-like or juvenile.

- **Grid Cells:** Base radius of `8px` (`rounded-md`), ensuring individual puzzle tiles feel distinct yet click together visually into solid lines.
- **Cards and HUD Panels:** `16px` (`rounded-lg`) corner radii to soften modal and dashboard edges against the dark background.
- **Pill Exceptions:** High-intensity streak counters, energy capsules, and multiplier pills explicitly use complete circular caps (`rounded-full`) to differentiate temporal counters from structural frames.

## Components

### Buttons & Interactive Controls
- **Juicy Action Buttons (Primary):** Solid `#00F0FF` fill with dark typography (`#0B0D17`). Styled with an extruded tactile 3D base: a 3px solid bottom bevel (`#00A8B3`), an inner top specular rim (`inset 0 1px 0 rgba(255,255,255,0.6)`), and an ambient drop shadow (`0 6px 16px rgba(0,240,255,0.4)`). On active touch, the button translates 2px downwards, flattening the bottom bevel.
- **Secondary Buttons:** Dark glass container (`#13172A` at 90%) with a crisp 1px stroke tinted in vibrant violet (`#8A2BE2`). Specular light accentuates the top edge.

### Glassmorphic Cards & Panels
- Backing surfaces use semi-transparent obsidian-violet (`#13172A` at 85%) backed by a 16px blur filter. 
- Contours are framed with micro-borders: 1px width with gradient orientation from high-alpha cyan/white at the top to low-alpha violet at the bottom edge.

### Streak Counters & Badges
- **Flame Streak Badge:** Pill shape featuring deep violet-tinted translucent backing, a blazing amber icon (`#FFB800`), and a dynamic numeric multiplier in `label-numeric`. Outlined with a high-contrast amber hair-line glow (`box-shadow: 0 0 8px rgba(255,184,0,0.5)`).
- **Score HUD:** Centered pill deck housing live score points with responsive scale animations on line clears, accompanied by an electric cyan combo pip strip.

### 8x8 Puzzle Cells & Active Blocks
- **Empty Grid Slots:** Rounded squares with subtle inset contrast, defining the board structure when empty.
- **Filled Solid Blocks:** Vibrant saturation matching the active piece theme (Cyan, Violet, Amber, Magenta), featuring a 45-degree micro-gradient, a bright 1px inner top-edge bevel, and subtle shadow separation from neighboring connected tiles.

### Input Fields & Toggles
- **Settings Sliders & Inputs:** Recessed tracks (`#0B0D17`) accompanied by glowing cylindrical sliders in `#00F0FF`.
- **Toggle Switches:** Obsidian pill capsules with a glowing neon indicator that shifts from muted slate (`#323B5C`) in inactive states to `#00F0FF` with a localized neon bloom when engaged.
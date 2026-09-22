# Pay&Save Design System

The visual language follows the reference mock-up the team chose: a near-black, photo-led interface with a deep forest-green accent, soft rounded cards, bold geometric headings and light, airy body text. Everything below is measured from that reference and then adjusted only where the research requirements demand it (§5).

Use our own photography (or properly licensed stock). Do not reuse the reference's photos, wordmark or product names.

## 1. Colour tokens

| Token | Hex | Use |
|---|---|---|
| `bg` | `#000000` | App background (pure black, as in the reference) |
| `surface` | `#161616` | Cards, grid tiles |
| `surfaceRaised` | `#222222` | Hero card end colour, bottom sheets |
| `searchFill` | `#D9D9D9` | Search field and filter button fill (light grey on black) |
| `searchText` | `#7A7A7A` | Placeholder and icon inside the search field |
| `green` | `#1B6B3E` | Primary accent: buttons, selected chip, add buttons |
| `greenDeep` | `#0E4527` | Gradient end for the primary button |
| `greenBright` | `#2FA360` | Green text on black (currency symbol, links) — passes AA on black |
| `textPrimary` | `#FFFFFF` | Headings, amounts |
| `textSecondary` | `#B8B8B8` | Subtitles |
| `textTertiary` | `#8C8C8C` | Inactive chips, captions (6.3:1 on black) |
| `divider` | `#2A2A2A` | Hairlines |
| `statusVerified` | `#2FA360` | Verified (always with ✓ icon + word) |
| `statusPending` | `#E3A33B` | Saved offline / awaiting verification (clock icon + word) |
| `statusDue` | `#E5484D` | Overdue (alert icon + word) |

Gradients:
- **Primary button:** left→right `green` → `greenDeep`, as on the "Get Started" and hero "Get it now" buttons.
- **Hero card:** top-left→bottom-right `#1E1E1E` → `#2B2B2B`.
- **Onboarding photo overlay:** transparent at 35% height → `#000000` at 100%.

## 2. Typography

| Role | Font | Size / weight | Reference element |
|---|---|---|---|
| Wordmark | Montserrat | 34 / 800, uppercase | "MOROJIWO" → **PAY&SAVE** |
| Display | Montserrat | 28 / 700 | "Enjoy Your Day" |
| Greeting / H1 | Montserrat | 22 / 700 | "Good Morning …" |
| Section title | Montserrat | 16 / 600 | "Recommended For You" |
| Card title | Montserrat | 17 / 600 | "Latte Coffee" |
| Body / subtitle | Poppins | 16 / 300 | "Perfect coffee for your perfect day" |
| Caption | Poppins | 12 / 400 | "With Oat Milk" |
| Amount | Montserrat | 18 / 700 | "$4.19" |
| Button | Montserrat | 16 / 700 | "Get Started" |

Sinhala and Tamil: Montserrat and Poppins carry no Sinhala or Tamil glyphs (this caused issue E-01 in the prototype). Set `fontFamilyFallback: ['Noto Sans Sinhala', 'Noto Sans Tamil']` on every text style, and bump line height to 1.5 for those locales.

## 3. Shape, spacing, elevation

- Radii: button 16, hero card 20, grid tile 18, search field 12, chip 10, add button 8, avatar full circle.
- Spacing scale: 4, 8, 12, 16, 20, 24, 32. Screen padding 20.
- No drop shadows on cards; separation comes from surface colour against black. The reference's tilted phones and big shadow are presentation only, not app UI.
- Pager dots: active is a 16×4 pill in white, inactive 4×4 dots in `textTertiary`.

## 4. Mapping the reference screens to Pay&Save

### 4.1 Onboarding → Welcome (NFR-06: language first)

```
┌──────────────────────────────┐
│  [full-bleed photo: hands    │
│   passing money / a group    │
│   at a table, dark-graded]   │
│                              │
│  PAY&SAVE                    │  wordmark, 800
│                              │
│                              │
│    Pay Together.             │  display, centred
│    Save Together.            │
│  Keep your seettu records    │  body 300
│  clear for everyone          │
│   English  සිංහල  தமிழ்       │  language chips (selected = green)
│           ▬ • •              │  pager
│  [      Get started      ]   │  gradient pill button
└──────────────────────────────┘
```

### 4.2 Home → Member home

```
┌──────────────────────────────┐
│ (avatar)  ◉ Friends Seettu ▾  🔔│  circle switcher replaces the location pin
│ Good morning, Nadeeshi       │
│ [🔍 Find a payment or circle][⚙]│
│ This cycle                   │
│ ┌──────────────────────────┐ │  hero card = "Recommended for you" card
│ │[cover] Cycle 3 of 5      │ │
│ │ photo  Due 20 Sep · 3 days│ │
│ │        LKR 5,000   ⏱ Due │ │  status: icon + word, never colour alone
│ │              [Pay now]   │ │
│ └──────────────────────────┘ │
│           • ▬ • •            │  swipe between your circles
│ [Turn order] History  Savings Reminders │  chips
│ ┌──────────┐ ┌──────────┐    │  2-column grid
│ │ photo    │ │ photo    │    │
│ │Turn order│ │My savings│    │
│ │Next: You │ │LKR 15,000│    │
│ │ cycle 5  │ │3 verified│[+]│
│ └──────────┘ └──────────┘    │
│  ⌂ Home  ◎ Circles  ☰ History  ⚙ Settings │
└──────────────────────────────┘
```

Rules for the hero card, driven by the state machine in MASTER_PLAN §5.2:

| State | Badge | Button |
|---|---|---|
| due | ⏱ Due in 3 days (red when overdue) | **Pay now** (green gradient) |
| pending_sync | ⏱ Saved on this phone · not yet confirmed | View saved record (outline) — Pay now hidden |
| recorded | ⏱ Waiting for organizer to verify | View record (outline) |
| verified | ✓ Verified 17 Sep · PS-1038 | View verified record (outline) |

The reference's strikethrough price is **not** reused: striking through a money amount in a savings app reads as "this payment was cancelled".

### 4.3 Other screens

Keep the Milestone 02 layouts and apply: black background, `surface` cards, Montserrat headings, green primary action at the bottom, arithmetic rows (`3 verified × LKR 5,000 = LKR 15,000`) in `textSecondary` with the total in `textPrimary` bold.

## 5. Where the app deliberately differs from the reference

Each change is required by a Milestone 01 requirement or a Milestone 02 finding.

1. **Bottom navigation has text labels** under the icons. Icon-only navigation fails users with low digital confidence (NFR-06).
2. **Touch targets are at least 48 dp**, including the small green "+" tile buttons (the reference's are about 36 px).
3. **Contrast:** the reference's grey-on-black captions are lifted to `textTertiary` `#8C8C8C` or brighter to meet WCAG 2.1 AA.
4. **Status is never colour alone** — every status has an icon and a word.
5. **Language choice appears on the first screen**, above Get started.

## 6. Components to build first

`PsGradientButton`, `PsOutlineButton`, `PsSearchField` (+ filter button), `PsChipRow`, `PsHeroCycleCard`, `PsGridTile`, `PsStatusBadge`, `PsArithmeticRow`, `PsBottomNav`, `PsPagerDots`, `PsCircleSwitcher`. Theme and two starter widgets are in `frontend/lib/core/`.

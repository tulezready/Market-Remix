# MaketPles ENB — Design System (MASTER)

The source of truth for every page on the site. The `ui-ux-pro-max` skill in
`.claude/skills/` reads this file before designing; where it disagrees with the
skill's generic suggestions, **this file wins**. Page-specific overrides go in
`pages/<page>.md`.

Implementation lives in `site.css` (tokens at the top) and `site.js`.

## Product

Official online marketplace of the East New Britain Provincial Administration,
Division of Commerce & Industry. Buyers: people in the province, Papua New
Guineans elsewhere ("Send home"), and overseas visitors. Many shop on low-cost
Android phones over mobile data, often outdoors.

Style: **vibrant and block-based**, shop-first. Products and prices come before
storytelling. Culture is expressed through colour, pattern and language, never
by depicting sacred objects (no tubuan / dukduk imagery).

## Colour — the East New Britain blend

| Role | Token | Hex | Source |
|---|---|---|---|
| Base / text | `--ink` | `#161214` | Black volcanic sand |
| Page background | `--ash` | `#FAF4EA` | Baining bark cloth |
| Surfaces, tints | `--sand` / `--shell` | `#F3E6CC` | Tolai tambu shell money |
| Action (buttons, prices, links) | `--red` | `#C8321E` | Flag red, tubuan leaf skirt |
| Growth, success, districts, "Fresh" | `--leaf` | `#2E7D3A` | Flag green, tubuan green leaves |
| Highlight, main search button, marquee | `--gold` | `#E9B949` | Kumul (bird of paradise) |
| Badges, accents | `--pink` / `--pink-dp` | `#E2508E` / `#B8336E` | Sulka mask pink |
| Scenery only | `--harbour`, `--cocoa`, `--ember`, `--tephra` | `#0F5C68`, `#5B3220`, `#E4572E`, `#8C857D` | Simpson Harbour, Gazelle cocoa, Tavurvur |
| Secondary text | `--muted` | `#6E6157` | — |

Rules:
- One job per colour. Red is the only "do this" colour; never put two competing CTAs in red side by side.
- Text contrast at least 4.5:1 (3:1 for 24px+ or 18.66px bold). Pink text uses `--pink-dp`, never `--pink`.
- Category colours (tiles, chips) come from `CATS` in `site.js`; districts: Rabaul ember, Kokopo harbour teal, Gazelle cocoa→gold, Pomio leaf green with Sulka-pink art.

## Pattern & motifs

- **ENB weave** (`.bilum`): red zigzag over green zigzag with a gold/pink thread. Section dividers.
- **Tambu strip** (`.tambu`): cream shell discs on a cord. Used sparingly, under dark bands.
- **Rabaul caldera scene** in the home hero; **Southern Cross** stars (desktop only).
- **Flag layout** (black field, green diagonal, red field, white stars) for the mandate/numbers band.

## Typography

- Display: **Unbounded** 700/800 — headings, prices, numbers.
- Body/UI: **Plus Jakarta Sans** 400–800.
- Labels: **Space Mono** 400/700, uppercase, letter-spaced — eyebrows, badges, small meta.
- Minimum text size **12px** everywhere (labels included); body 15–16px; line-height 1.5+.
- Tok Pisin phrases are set in italic (`.tp`) next to the English, never instead of it.

## Touch & layout

- Every tappable control is at least **44px** tall on phones (chips, buttons, inputs, header actions), with 8px+ gaps.
- Phone bottom bar: Home · Shop · Search · Basket (never more than 5).
- Breakpoints: 400 / 640 / 860 / 1024 / 1180 / 1500px. No horizontal scrolling.
- Filters live in the URL (`shop.html?cat=…&district=…&q=…&sort=…`).

## Motion & performance

- Durations 200–300ms for UI, up to 1s for reveals; everything off under `prefers-reduced-motion`.
- Decorative animation (volcano plume, glints, stars, floating tickets, film grain) is desktop-only.
- No `backdrop-filter` on phones. Images lazy-load with responsive `srcset`; product photos carry a fixed aspect ratio (no layout shift).
- Header logo uses the small raster `logo-96.png`; the 137KB `logo.svg` is for print and large uses only.

## Pre-delivery checklist

- [ ] Contrast 4.5:1 for text; focus ring visible on every control
- [ ] Touch targets 44px+ on phones; no text under 12px
- [ ] Icon-only links/buttons have an `aria-label`
- [ ] Works at 360, 390, 768, 1024, 1440px
- [ ] Reduced motion respected; no decorative animation on phones
- [ ] Tested on a throttled (3G) connection

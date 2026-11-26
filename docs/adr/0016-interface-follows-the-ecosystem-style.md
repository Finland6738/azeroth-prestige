# 0016. The interface follows the ecosystem style of the owner's addons

- Status: Accepted
- Date: 2026-11-26 (as in Azeroth Accord, ADR 0021 there)

## Context

The owner's addons (Finland Dragon Credit Points, Azeroth Accord, Azeroth Unspoken) share one look: dark "nebula" surfaces, a title bar with the logo, tabs with an indicator, rounded 9-slice shapes, the Outfit, JetBrains Mono and Orbitron fonts. Azeroth Prestige should read as one more member of the family.

## Decision

1. Prestige copies Accord's `UI/Theme.lua`, `UI/Assets.lua`, `UI/Motion.lua`, the widget kit and the media and font tools (M3.2), renamed. FDCP and Accord are only read, never modified.
2. **Three themes** with the same token names: **Nebula** (dark) and **Aurora** (light) with the family's values, and **Prestige** (dark), made from the logo's palette (deep teal, antique gold and bronze, mint glow). The default is Prestige (proposal, [SPEC-11](../specs/SPEC-11-risks-open-questions.md) Q14). Textures are white and tinted at run time, so a theme changes without `/reload`.
3. No colour is written outside `UI/Theme.lua`; every string is a locale key; only the public name "Finland" appears in credits; every media file is listed in [`docs/third-party.md`](../third-party.md).
4. Rank badges and category emblems are the addon's own art: placeholders drawn by a tool until the final art ([SPEC-08 §14.7](../specs/SPEC-08-ui-badges.md)).
5. Prestige's own `docs/specs/ui-style.md` (written in M3.1) records only the differences from Accord's.

## Consequences

- Positive: one visual family; a tested theme and widget system instead of new code.
- Negative: duplicated UI code to keep in step by hand.

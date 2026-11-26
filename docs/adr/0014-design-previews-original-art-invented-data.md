# 0014. Design previews: original art, invented data, drawn from the addon's texts

- Status: Accepted
- Date: 2026-11-26 (as in Azeroth Accord, ADR 0019 there)

## Decision

1. Until the owner takes screenshots in the game, the pictures of the wiki and the READMEs are **design previews, not screenshots**, and say so in a strip at the bottom of every image.
2. They are drawn from the addon's own layout and **locale texts** by `tools/make_mockups.py` (from M3), so they cannot disagree with the interface, and the Italian previews come from `itIT`.
3. **Original art only**: the addon's logo, its own badges and shapes, the fonts it ships; no game screenshot, icon, texture or font, nothing loaded from a network.
4. **Invented data**: characters, guilds, realms and points are made up; no real player appears.
5. WebP, quality 80, under `docs/specs/mockups/`; `tools/check_docs.py` fails when a preview is missing or out of date.

## Consequences

- Positive: a manual with pictures before the first run in the game; no licensing question about game art.
- Negative: previews can differ from the real window and must be regenerated when a view changes.

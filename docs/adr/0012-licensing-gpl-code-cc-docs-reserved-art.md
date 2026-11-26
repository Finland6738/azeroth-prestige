# 0012. Licensing: GPL-3.0 code, CC BY 4.0 documentation, reserved artwork

- Status: Accepted
- Date: 2026-11-26 (the owner's choice: the scheme of Azeroth Unspoken, ADR 0034 there)

## Context

The code should stay open like the owner's other addons, but the visual identity (the logo, the rank badges, the emblems, the sounds) is what makes Azeroth Prestige recognisable, and the owner wants forks to have their own.

## Decision

1. **Code** (everything not listed below, including the rulesets in `Data/`, the TOC, `Tests/`, `tools/`, `.github/`): **GPL-3.0-or-later** ([`LICENSE`](../../LICENSE)), with the section 7(e) term that the name "Azeroth Prestige" is not licensed: a modified version distributed to others must have a different name.
2. **Documentation** (READMEs, CONTRIBUTING, CHANGELOG, ROADMAP, `docs/` except its code): **CC BY 4.0**.
3. **Artwork and sounds** (the logo in `assets/` and the badges, emblems, frames, particles and sounds in `AzerothPrestige/Media/`, except the fonts and the shapes drawn by the project's own tools): **all rights reserved**, with the permitted uses of [`LICENSE-CONTENT.md`](../../LICENSE-CONTENT.md): use with the addon, screenshots, videos and streams, short quotation. The media folder ships a `NOTICE.md` that says so (from M3).
4. The rulesets are code, not content: every peer must be able to read and recompute them ([ADR 0003](0003-points-recomputed-from-events.md)).
5. Third-party parts keep their licences (Ace3, LibDataBroker, LibDBIcon, fonts under SIL OFL 1.1), listed in [`docs/third-party.md`](../third-party.md). No Blizzard artwork is included.
6. The summary for readers is [`LICENSING.md`](../../LICENSING.md); contributions follow [CONTRIBUTING](../../CONTRIBUTING.md#licensing-of-contributions).

## Consequences

- Positive: open code that can move between the owner's GPL projects; a protected identity.
- Negative: three licences to explain. Images made with AI tools may have weak copyright protection in some countries ([SPEC-11](../specs/SPEC-11-risks-open-questions.md), R12); the reservation still covers the hand-made refinements and the selection.

# Third-party material and licences

Azeroth Prestige has a mixed licence: the code is GPL-3.0-or-later, the artwork and sounds are all rights reserved, the
documentation is CC BY 4.0 ([LICENSING.md](../LICENSING.md)). This page records where every library, font, picture and
sound that ships with the addon, or that the repository holds, comes from and under which licence. It is the single place
to update when one is added; from milestone M3 a media check fails when a file of `AzerothPrestige/Media/` is missing
from it.

## Libraries (embedded by the packager, never committed)

Pinned in [`.pkgmeta`](../.pkgmeta) and downloaded by `tools/fetch_libs.py` (from M1.2) for development and CI.

| Library | Version | Licence | Used for |
|---|---|---|---|
| Ace3 (AceAddon, AceEvent, AceComm, AceDB, AceLocale, AceConsole, CallbackHandler, LibStub, ChatThrottleLib) | `Release-r1403` | its own terms (BSD-style; LibStub public domain) | addon structure, events, comms with throttling, saved data, locales, commands |
| LibDataBroker-1.1 | `v1.1.4` | its own terms | the data broker |
| LibDBIcon-1.0 | `v8.0.4` | its own terms | the minimap button |

LibSerialize and LibDeflate will be added only if the M0 check V14 finds `C_EncodingUtil` missing.

## The logo (`assets/`)

| File | Origin | Licence |
|---|---|---|
| `assets/logo-source.png` | The project's logo (1024×1024), made for Azeroth Prestige with an image generation tool and chosen by the owner, 2026-11-26 | all rights reserved, [LICENSE-CONTENT.md](../LICENSE-CONTENT.md) |

From M3.2 `tools/make_media.py` derives the in-game logo files (`Media/logo_64.tga`, `Media/logo_256.tga`) from it.

## Fonts, icons, badges and sounds

None yet. From M3: the fonts Outfit, JetBrains Mono and Orbitron (SIL Open Font License 1.1, the same files as Azeroth
Accord, with their licence texts), the icons and placeholder badges drawn by the project's own tools (code licence), and
later the final badges, emblems, frames and sounds (all rights reserved). No Blizzard artwork, icon, texture, font or sound
is included.

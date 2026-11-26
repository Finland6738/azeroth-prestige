# 0010. Languages: a multilingual interface (English by default, Italian), bilingual manual

- Status: Accepted
- Date: 2026-11-26 (as in Azeroth Accord, ADR 0015 there; the owner asked for multi-language support from the start)

## Decision

1. **Every visible string is an AceLocale key** from the first line of code (M1.2). `Locales/enUS.lua` is the **base and the fallback**; `Locales/itIT.lua` ships with the same keys. The client's locale (`GetLocale()`) picks the table; any other locale falls back to English.
2. A new language is **one file** in `Locales/` plus one line in the TOC, with no code change. The translation kit of M7 prepares other languages; the tests treat every locale file present the same way.
3. Rank and category names (Wood, Dragonite, Legend, Vanguard, Delver...) stay in English in every language, as proper names; their descriptions are translated.
4. **Public documentation in English**: README, ADRs, CONTRIBUTING, CHANGELOG, code, comments, commits, issues and pull requests. `README.it.md` is the Italian front page.
5. **The user manual is bilingual**: every `docs/wiki/<Page>.md` has an Italian twin `<Page>-it.md` with the same images and links to Italian pages only; `tools/check_docs.py` checks it.
6. The internal specification in `docs/specs/` is in **Italian**, with code names, APIs and interface texts in English.
7. A test (`Tests/test_locales.lua`, M1.3) fails when a key is missing in a locale, a string is empty, placeholders differ in kind or order, or a key read in the code is missing in English. The `/azp debug` report is not translated (it is pasted into English bug reports).

## Consequences

- Positive: usable in Italian from the first release; more languages need no code.
- Negative: two README files, twin wiki pages and every locale file to keep in step.

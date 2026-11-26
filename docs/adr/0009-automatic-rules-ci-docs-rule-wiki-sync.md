# 0009. Automatic rules: CI, a docs rule and the wiki sync

- Status: Accepted
- Date: 2026-11-26 (as in Azeroth Accord, ADR 0014 there)

## Decision

1. **CI** (`ci.yml`, job `Tests`): `tools/check_docs.py` (relative links, wiki sidebar, links and Italian twins, ADR index, privacy scan for emails, personal paths and the owner's names listed locally, LF endings, the docs rule's own cases, the changelog) and, from M1, the package check and the offline addon tests.
2. **Docs rule** (`docs-check.yml`, job `Docs rule`): a pull request that changes `AzerothPrestige/` must also change `CHANGELOG.md` and a documentation file, unless it has the label `no-docs-needed`.
3. **Long tests** (`long-tests.yml`): the network simulator and the large scenarios, on changes to the network layer, weekly and on request.
4. **Wiki sync** as in [ADR 0008](0008-github-wiki-generated-from-docs-wiki.md); **Release** as in [RELEASING](../RELEASING.md); **DCO** as an advisory warning for external commits.
5. **Branch protection on `main`**: `Tests` and `Docs rule` required; no required reviews (shipping fast-forwards `main`); no force pushes; no deletion. The owner turns it on in the repository settings.
6. Actions are pinned to a commit and declare the least permissions they need.

## Consequences

- Positive: no merge with failing checks; docs and wiki travel with the code.
- Negative: a pull request that touches the addon needs a changelog entry and a doc (or the label).

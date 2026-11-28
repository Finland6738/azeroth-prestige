# Project decisions (ADRs)

The architecture and method decisions of Azeroth Prestige, one per file, in the [MADR](https://adr.github.io/madr/) format in English: **context**, **decision**, **alternatives considered**, **consequences**.

They record *why* the project is built a certain way. A decision that changes is not rewritten: a new ADR supersedes it, and the old one moves to the "superseded" status (or gets a dated *Update* section when the change is small). The detailed design is in the [specification](../specs/README.md) (Italian); the product decisions D-01 to D-41 are in [SPEC-00 §22](../specs/SPEC-00-vision-scope.md).

## Index

| No. | Decision | Status |
|---|---|---|
| [0001](0001-client-only-addon-peer-to-peer.md) | A client-only addon; data travels peer to peer | accepted |
| [0002](0002-wow-forever-target-and-api-dump.md) | Target WoW Forever (Interface 16001) and use the API dump as a reference | accepted (to verify in M0) |
| [0003](0003-points-recomputed-from-events.md) | Points are recomputed from events with a versioned ruleset, never declared | accepted |
| [0004](0004-trust-without-a-server.md) | Trust without a server: witnesses, trust levels and network-observed leaderboards | accepted |
| [0005](0005-versioned-peer-to-peer-protocol.md) | A versioned peer-to-peer protocol on addon messages | accepted (to verify in M0) |
| [0006](0006-embedded-ace3-savedvariables-and-schema-versions.md) | Embedded Ace3, SavedVariables and schema versions | accepted (updated in M1.1: no AceDB) |
| [0007](0007-git-flow-and-automated-shipping.md) | Git flow and automated shipping of milestone steps | accepted |
| [0008](0008-github-wiki-generated-from-docs-wiki.md) | The GitHub wiki: a user manual generated from `docs/wiki/` | accepted |
| [0009](0009-automatic-rules-ci-docs-rule-wiki-sync.md) | Automatic rules: CI, a docs rule and the wiki sync | accepted |
| [0010](0010-interface-and-documentation-languages.md) | Languages: a multilingual interface (English by default, Italian), bilingual manual | accepted |
| [0011](0011-offline-tests-with-lupa-and-a-mock-client.md) | Offline tests with lupa and a mock client | accepted |
| [0012](0012-licensing-gpl-code-cc-docs-reserved-art.md) | Licensing: GPL-3.0 code, CC BY 4.0 documentation, reserved artwork | accepted |
| [0013](0013-reuse-azeroth-accord-and-unspoken-foundations.md) | Reuse the foundations of Azeroth Accord and Azeroth Unspoken | accepted |
| [0014](0014-design-previews-original-art-invented-data.md) | Design previews: original art, invented data, drawn from the addon's texts | accepted |
| [0015](0015-one-version-per-milestone.md) | One version per milestone; `v1.0.0` after M7 | accepted |
| [0016](0016-interface-follows-the-ecosystem-style.md) | The interface follows the ecosystem style of the owner's addons | accepted |
| [0017](0017-feature-switches.md) | Feature switches keep unfinished features out of a release | accepted |
| [0018](0018-one-fresh-session-per-step.md) | One fresh development session per step, coordinated | accepted |
| [0019](0019-integrations-public-api-only.md) | Integrations with other addons: only a public read-only API | accepted |

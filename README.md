# Azeroth Prestige

<img src="assets/logo-source.png" alt="Azeroth Prestige logo" width="160" align="right">

**Prestige ranks, badges and leaderboards for World of Warcraft: Forever.** Azeroth Prestige rewards what you **complete** in the game (a boss, a dungeon, a quest, a battleground, a discovery, a recipe, an event you organised) with **Prestige Points** in **eight categories**. Points raise you through **22 tiers** (Wood to Dragonite, each with divisions IV to I) and then to **seven apex ranks** (Master to Legend) with at most **100 seats each**, won back every week. Your rank shows as a **badge** to the other players who run the addon, on nameplates, tooltips, unit frames and chat, with a profile, a history and leaderboards.

> **Status: in design.** The repository has its specification, decisions and plan; no addon code yet. The next milestone is **M0**, a probe that checks the risky game APIs in the real client, then **M1** (foundations) and the first test version `v0.1.0`. Nothing is published yet. See the [roadmap](ROADMAP.md).

[Italiano](README.it.md) · [Roadmap](ROADMAP.md) · [Specification (Italian)](docs/specs/README.md) · [Decisions](docs/adr/README.md) · [User manual](docs/wiki/Home.md) ([Italiano](docs/wiki/Home-it.md))

## The eight categories

| Category | What it rewards |
|---|---|
| **Vanguard** | Battlegrounds, killing blows, honorable kills, world PvP, duels |
| **Delver** | Dungeon and raid bosses, clears and full clears, first kills |
| **Pathfinder** | Sub-zones, whole zones, flight paths, curated secrets |
| **Adventurer** | Quests, storylines, reputation standings |
| **Diplomat** | Helping lower-level players, mentoring, commendations, social and RP events |
| **Artisan** | Profession skill, recipes, crafting for others |
| **Merchant** | Auction sales to distinct buyers, trades, variety of goods |
| **Steward** | Organising events, recruiting, running a guild, leading groups |

A ninth progression, **Global Prestige**, sums the eight with a bonus for variety (up to +40%).

## Principles

- **Recognition, not power.** Cosmetic only: no gameplay advantage, no rank requirement for groups, no filter by rank.
- **Completions, not hours.** Time spent gives nothing by itself; main activities count in full every time, and only actions farmable in seconds (duels, crafts, trades, commendations) have limits.
- **Never taken away.** Points and tiers never go down; an apex seat can be lost to others, but every title stays in your roll with its dates.
- **Fair play.** No points between characters of the same account, and no points while a player 10 or more levels above you carries you.
- **Honest about its limits.** No server: data travels **peer to peer** between players with the addon, leaderboards show what the network knows, and every profile shows how much of it is verified by witnesses.

## Languages

The interface is multilingual: **English** by default and **Italian**, one file per language, more can be added without code ([ADR 0010](docs/adr/0010-interface-and-documentation-languages.md)). The user manual is in English and Italian.

## For developers

- [CONTRIBUTING](CONTRIBUTING.md) explains the checks, the tests and the git flow; [CLAUDE.md](CLAUDE.md) holds the instructions for development sessions.
- The addon targets **WoW Forever, Interface 16001**, and is tested offline in Lua 5.1 on a mock client ([ADR 0011](docs/adr/0011-offline-tests-with-lupa-and-a-mock-client.md)).
- It reuses the foundations of the owner's other addons, Azeroth Accord and Azeroth Unspoken ([ADR 0013](docs/adr/0013-reuse-azeroth-accord-and-unspoken-foundations.md)), and exposes a read-only public API for other addons ([ADR 0019](docs/adr/0019-integrations-public-api-only.md)).

## Licence

The code is under the **GNU GPL v3.0 or later**; the documentation under **CC BY 4.0**; the logo, badges, emblems and sounds are **all rights reserved** with permitted uses. Details: [LICENSING.md](LICENSING.md).

Azeroth Prestige is an unofficial fan project, not affiliated with or endorsed by Blizzard Entertainment. World of Warcraft and Azeroth are trademarks of Blizzard Entertainment, Inc.

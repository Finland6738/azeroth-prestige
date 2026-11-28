# SPEC-10: Qualità, test e roadmap

> Parte della [specifica di Azeroth Prestige](README.md). Nata dal documento unico v0.4 del 2026-11-26, diviso in file nel bootstrap: la numerazione delle sezioni (§) è quella del documento originale, così i rimandi restano validi in tutti i file. Legenda: ✅ confermato dal proprietario · 🟡 proposta valida fino a diversa decisione ([SPEC-11](SPEC-11-risks-open-questions.md)) · 🔍 da verificare in M0.

## 20. Testing e QA

### 20.1 Test automatici (fuori dal gioco)

- **lupa** (Lua 5.1, `lupa==2.8`) + client finto in `Tests/mock/`, simulatore di rete in `Tests/sim/` ([ADR 0011](../adr/0011-offline-tests-with-lupa-and-a-mock-client.md)). Sostituisce busted del documento v0.4.
- Coperture obbligatorie:
  - `Scoring`: soglie, DR, cap, GP, apex, ruleset versioning.
  - `Ledger`: idempotenza, compattazione, ricalcolo.
  - `Codec`: roundtrip, chunking, messaggi malformati.
  - `ProfileStore`: merge prima/seconda mano, monotonicità, plausibilità.
  - `Leaderboard`: assegnazione a cascata dei 7 × 100 posti apex, spareggi, consenso `LBD`, apertura e chiusura dei regni.
  - `Celebrations/Queue`: tutte le transizioni della macchina a stati.
- CI GitHub Actions: `tools/check_docs.py`, controllo del pacchetto e **tutta** la suite offline a ogni PR (`ci.yml`), scenari lunghi in `long-tests.yml` ([ADR 0009](../adr/0009-automatic-rules-ci-docs-rule-wiki-sync.md)). Nessuna modifica senza test ([ADR 0007](../adr/0007-git-flow-and-automated-shipping.md)).

### 20.2 Test in gioco

- `/azp debug`: pannello con stato restrizioni, coda di rete, coda celebrazioni, profili noti.
- `/azp sim <ruleId> [n]`: genera eventi finti (solo in modalità debug, marcati `tl=0` e `src="SIM"`, mai trasmessi). La modalità debug è la build di sviluppo; `/azp sim clear` li toglie (proposta [Q22](SPEC-11-risks-open-questions.md), [SPEC-01 §9.7.15](SPEC-01-platform-architecture.md)).
- `/azp celebrate test <tier>`: anteprima delle celebrazioni.
- CVar di restrizione forzata (V16) per testare il comportamento in lockdown.

### 20.3 Casi di accettazione chiave

| # | Scenario | Atteso |
| --- | --- | --- |
| A1 | Boss kill in gruppo di 5, 3 utenti addon | Tutti e 3 ricevono gli stessi PP, ciascuno con 2 attestazioni |
| A2 | `/reload` subito dopo un boss | Nessun evento duplicato |
| A3 | Promozione durante il combattimento | Celebrazione solo dopo `PLAYER_REGEN_ENABLED` |
| A4 | Promozione con il gossip NPC aperto | Celebrazione alla chiusura |
| A5 | 3 promozioni simultanee (DEL, GP, PAT) | Una celebrazione combinata, GP per primo |
| A6 | Modifica manuale dei SavedVariables con +100k PP | Gli altri client segnano il profilo come flagged, escluso dagli apex |
| A7 | Utente che disinstalla | Il suo profilo resta visibile agli altri e viene rilanciato via `RLY` |
| A8 | Nameplate amica in dungeon | Nessun errore Lua. Badge su frame party e tooltip |
| A9 | Account trial | Tracking locale ok, nessun invio, avviso in UI |
| A10 | Reset settimanale con cambi di fascia apex | Regni chiusi e aperti con la data del reset, cinematica per ingressi e salite, toast per gli spodestati |
| A10b | 130 personaggi oltre la soglia Aspect | 100 Aspect; gli altri 30 competono per Keeper secondo la cascata |
| A10c | Personaggio spodestato da Legend e poi rientrato | Albo con 2 regni Legend distinti, ciascuno con le sue date |
| A11 | Trade, vendita AH o duello tra due personaggi dello stesso account | 0 PP, evento scartato con motivo `ALT` nella cronologia debug |
| A12 | 10 full clear consecutivi dello stesso dungeon | 10 × PP pieni, nessuna riduzione |
| A13 | Morte di un personaggio su realm Hardcore | Sigillo "Caduto" propagato, punti congelati, eventi successivi rifiutati |
| A14 | Personaggio con 5 categorie ≥ Silver IV | GP = somma × 1.25 |
| A15 | Livello 30 in gruppo con un livello 45 completa una quest di livello 30 | Il livello 30 prende 0 PP, motivo `BOOST:G`. Il livello 45 prende 45 / 15 = 3 PP per la quest + `DIP_HELP_LOW` |
| A15b | Livello 60 da solo uccide un boss di livello 58 | Punti pieni (differenza 2 < 10) |
| A16 | Livello 30 in gruppo con un livello 39 (differenza 9) | Punti pieni |
| A17 | Giocatore fuori gruppo di livello 50 attacca il mob del livello 25 | BOOSTED per 60 s; kill e avanzamenti di quest in quella finestra annullati |
| A18 | Buff ricevuto in città da un livello 60 fuori dal combattimento | Nessun effetto |
| A19 | Profilo con eventi a punti pieni ma `gmx ≥ pl + 10` | I peer lo marcano `Flagged` |

## 21. Roadmap

| Milestone | Contenuto | Uscita | Versione |
| --- | --- | --- | --- |
| **M0 — API spike** | Addon di prova `AzPr_Probe`, verifiche V1–V21, `docs/spike/M0-results.md`, revisione delle spec | Spec rivista | nessuna (probe mai distribuito) |
| **M1 — Fondamenta** | Scheletro, test offline, Core, Restrictions, Config, Ladder, Scoring, Ruleset, Ledger, Boost, diagnostica | Punti calcolati localmente | `v0.1.0` |
| **M2 — Tracker "oggettivi"** | Delver, Adventurer, Pathfinder, Artisan + Backfill | Alpha privata | `v0.2.0` |
| **M3 — UI e celebrazioni** | Tema e widget dell'ecosistema, badge segnaposto, finestra, profilo 3 livelli, cronologia, impostazioni, Celebration Queue | Alpha 2 | `v0.3.0` |
| **M4 — Rete e badge** | Codec, Comm, beacon, PRQ/PRF, attestazioni, ProfileStore, simulatore, badge (tooltip, nameplate, frame, chat, menu) | **Beta pubblica** | `v0.4.0` |
| **M5 — Tracker "sociali"** | Vanguard, Merchant, Diplomat, Steward, Commendations, Prestige Events, memoriale Hardcore | Beta 2 | `v0.5.0` |
| **M6 — Classifiche e apex** | Leaderboard, RLY, LBD, snapshot, posti apex, albo dei titoli, Hall of Prestige, ricompense | Release candidate | `v0.6.0` |
| **M7 — Estensioni e 1.0** | API pubblica, Prestige Contracts, adapter per altri addon, liste gilda e amici, arte definitiva, kit di traduzione, controllo completo di rilascio | **Release 1.0** | `v1.0.0` |

Dettaglio degli step: [ROADMAP.md](../../ROADMAP.md) e [docs/roadmap/](../roadmap/README.md). Una versione per milestone ([ADR 0015](../adr/0015-one-version-per-milestone.md)); il proprietario ha fissato `v1.0.0` dopo M7 (2026-11-26).

> Nota: il PO ha confermato tutte le 8 categorie dal day-1. La **release 1.0** (dopo M7) le include tutte. L'ordine delle milestone serve solo a sviluppare per prime le categorie più semplici da verificare, così da calibrare il ritmo su dati reali.

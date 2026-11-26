# Azeroth Prestige

<img src="assets/logo-source.png" alt="Logo di Azeroth Prestige" width="160" align="right">

**Rank di prestigio, badge e classifiche per World of Warcraft: Forever.** Azeroth Prestige premia ciò che **completi** nel gioco (un boss, un dungeon, una quest, un battleground, una scoperta, una ricetta, un evento che hai organizzato) con i **Prestige Points** in **otto categorie**. I punti ti fanno salire su **22 tier** (da Wood a Dragonite, ognuno con le divisioni da IV a I) e poi verso **sette rank apex** (da Master a Legend) con al massimo **100 posti ciascuno**, riassegnati ogni settimana. Il tuo rank appare come **badge** agli altri giocatori che usano l'addon, su nameplate, tooltip, frame delle unità e chat, con un profilo, una cronologia e le classifiche.

> **Stato: in progettazione.** Il repository ha la specifica, le decisioni e il piano; il codice dell'addon non c'è ancora. La prossima milestone è **M0**, un addon di prova che verifica nel client vero le API rischiose del gioco; poi **M1** (fondamenta) e la prima versione di prova `v0.1.0`. Non è ancora stato pubblicato nulla. Vedi la [roadmap](ROADMAP.md) (in inglese).

[English](README.md) · [Roadmap](ROADMAP.md) · [Specifica](docs/specs/README.md) · [Decisioni](docs/adr/README.md) · [Manuale](docs/wiki/Home-it.md) ([English](docs/wiki/Home.md))

## Le otto categorie

| Categoria | Cosa premia |
|---|---|
| **Vanguard** | Battleground, killing blow, honorable kill, PvP nel mondo, duelli |
| **Delver** | Boss di dungeon e raid, clear e full clear, prime kill |
| **Pathfinder** | Sotto-zone, zone intere, flight path, segreti selezionati |
| **Adventurer** | Quest, storyline, livelli di reputazione |
| **Diplomat** | Aiuto ai giocatori di livello basso, mentorship, encomi, eventi sociali e RP |
| **Artisan** | Skill delle professioni, ricette, craft per altri |
| **Merchant** | Vendite all'asta ad acquirenti diversi, scambi, varietà della merce |
| **Steward** | Organizzare eventi, reclutare, gestire una gilda, guidare i gruppi |

Una nona progressione, il **Global Prestige**, somma le otto con un bonus per la varietà (fino a +40%).

## Principi

- **Riconoscimento, non potere.** Solo cosmetico: nessun vantaggio di gioco, nessun requisito di rank per i gruppi, nessun filtro per rank.
- **Completamenti, non ore.** Il tempo da solo non vale nulla; le attività principali contano per intero a ogni ripetizione, e solo le azioni farmabili in pochi secondi (duelli, craft, scambi, encomi) hanno limiti.
- **Mai togliere.** Punti e tier non scendono mai; un posto apex si può perdere, ma ogni titolo resta nel tuo albo con le sue date.
- **Gioco corretto.** Niente punti tra personaggi dello stesso account, e niente punti mentre un giocatore di 10 o più livelli sopra di te ti porta.
- **Onesto sui suoi limiti.** Nessun server: i dati viaggiano **peer to peer** tra i giocatori con l'addon, le classifiche mostrano ciò che la rete conosce, e ogni profilo mostra quanto è verificato dai testimoni.

## Lingue

L'interfaccia è multilingua: **inglese** di default e **italiano**, un file per lingua, altre si aggiungono senza toccare il codice ([ADR 0010](docs/adr/0010-interface-and-documentation-languages.md)). Il manuale è in inglese e in italiano.

## Per chi sviluppa

- [CONTRIBUTING](CONTRIBUTING.md) spiega controlli, test e flusso git; [CLAUDE.md](CLAUDE.md) contiene le istruzioni per le sessioni di sviluppo (entrambi in inglese).
- L'addon è per **WoW Forever, Interface 16001**, ed è provato offline in Lua 5.1 su un client finto ([ADR 0011](docs/adr/0011-offline-tests-with-lupa-and-a-mock-client.md)).
- Riusa le fondamenta degli altri addon del proprietario, Azeroth Accord e Azeroth Unspoken ([ADR 0013](docs/adr/0013-reuse-azeroth-accord-and-unspoken-foundations.md)), ed espone un'API pubblica in sola lettura per gli altri addon ([ADR 0019](docs/adr/0019-integrations-public-api-only.md)).

## Licenza

Il codice è sotto **GNU GPL v3.0 o successive**; la documentazione sotto **CC BY 4.0**; logo, badge, emblemi e suoni sono **tutti i diritti riservati**, con gli usi permessi. Dettagli: [LICENSING.md](LICENSING.md) (in inglese).

Azeroth Prestige è un progetto amatoriale non ufficiale, non affiliato né approvato da Blizzard Entertainment. World of Warcraft e Azeroth sono marchi di Blizzard Entertainment, Inc.

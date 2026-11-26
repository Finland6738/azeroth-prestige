# SPEC-00: Visione, ambito e decisioni

> Parte della [specifica di Azeroth Prestige](README.md). Nata dal documento unico v0.4 del 2026-11-26, diviso in file nel bootstrap: la numerazione delle sezioni (§) è quella del documento originale, così i rimandi restano validi in tutti i file. Legenda: ✅ confermato dal proprietario · 🟡 proposta valida fino a diversa decisione ([SPEC-11](SPEC-11-risks-open-questions.md)) · 🔍 da verificare in M0.

## 1. Executive summary

**Azeroth Prestige** è un sistema di **identità e reputazione del personaggio**, parallelo alla progressione di WoW Forever. I giocatori guadagnano **Prestige Points (PP)** in **8 categorie** di attività. Al crescere dei punti salgono una scala di rank: **22 tier metallici e gemme** con divisioni IV→I, poi **7 rank apex** (da Master a Legend), ciascuno con una soglia di punti e **al massimo 100 posti** per categoria. Gli apex si possono perdere se si viene superati, ma ogni titolo ottenuto resta nell'albo del personaggio con date di inizio e fine. Una nona progressione, il **Global Prestige**, somma le otto categorie con un bonus per la varietà.

I punti premiano il **completamento di attività**, non il tempo trascorso. Le attività principali (dungeon, raid, boss, battleground) danno punti pieni **a ogni completamento**, senza riduzioni. I limiti esistono solo per le azioni farmabili in pochi secondi (duelli, craft, trade, encomi). Nessuna interazione tra personaggi dello stesso account genera punti, e chi viene **boostato** da un giocatore di 10+ livelli più alto non guadagna punti.

Il prestigio è **permanente**: non decade, non si resetta e resta visibile anche quando il proprietario disinstalla l'addon. I rank compaiono come **badge** sulle nameplate, nei tooltip, nel menu unità e in chat, e si possono consultare in un **profilo a tre livelli** e in **classifiche per categoria**.

**Scelta architetturale (✅):** l'addon è **solo client, per sempre**: nessun backend, nessuna companion app. I dati circolano tra gli utenti dell'addon con un protocollo **peer-to-peer** sopra il canale messaggi addon di WoW. Da questa scelta derivano tre conseguenze che il documento affronta in modo esplicito:

1. Le classifiche sono **"network-observed"**: mostrano ciò che la rete di utenti conosce, non una verità globale autorevole.
2. L'anti-cheat non può essere crittografico: si basa su **attestazioni dei testimoni**, **ricalcolo deterministico dei punti** e **controlli di plausibilità**.
3. Il badge è visibile **solo a chi usa l'addon**: è un limite tecnico invalicabile, e coincide con la decisione ✅ "profilo pubblico per gli utenti addon".

## 2. Analisi del lavoro precedente

### 2.1 Fonti analizzate

| Fonte | Contenuto |
| --- | --- |
| Chat A | Brief iniziale: 8 categorie, 29 rank, badge, architettura con backend, roadmap in 10 fasi, 6 domande (senza risposta nell'export) |
| Chat B | 5.7–5.10: chi compare in classifica, visibilità profilo, persistenza, utenti autorizzati, profilo a 3 livelli |
| Chat C | 5.21–5.22: badge su tutti i registrati con aggiornamento dinamico; quale badge mostrare (senza risposta) |
| Chat D | 5.32–5.33: durata delle celebrazioni, promozioni multiple |
| Chat E | 5.41–5.43: stile visivo delle celebrazioni, skip, suoni |
| Chat F | 5.51–5.60: celebrazioni durante finestre, NPC, viaggi, mappa |
| Wiki *Prestige Ranks* | Proposta di game design originale: tracce, formula punti, group credit, anti-farming, solo ricompense cosmetiche |

Le decisioni 5.1–5.6, 5.11–5.20, 5.23–5.31, 5.34–5.40 e 5.44–5.50 non compaiono negli export. Dove mancano, questo documento propone una scelta (🟡).

### 2.2 Cosa teniamo

| Elemento | Motivo |
| --- | --- |
| Le 8 categorie con identità distinte (✅ confermate tutte dal day-1) | Sono il cuore dell'idea: premiano stili di gioco diversi, non solo il combattimento |
| Rank stile ladder competitivo, con IV come divisione d'ingresso e I come divisione più alta | Convenzione nota e leggibile |
| Global Prestige come nona progressione | Premia i giocatori completi; le categorie premiano gli specialisti |
| Permanenza: nessun decay, nessun reset, profilo conservato dopo la disinstallazione (✅). Gli apex sono l'unica parte competitiva, ma i titoli ottenuti restano nell'albo | Coerente con la wiki: "no rank decay, no compulsory seasonal reset" |
| Classifiche con soli personaggi che usano o hanno usato l'addon (✅) | È anche l'unica opzione tecnicamente possibile |
| Profilo visibile solo agli utenti addon (✅) | Stesso motivo |
| Badge su tutti i registrati, con aggiornamento dinamico e cache locale (✅ 5.21-C) | Giusto, ma la cache passa dal backend alla rete P2P ([§12](SPEC-06-network-protocol.md)) |
| Profilo a 3 livelli: Overview, Category Details, Statistics | Buon equilibrio tra leggibilità e profondità |
| Celebrazioni: 7–8 s configurabili, sistema ibrido pannello/cinematico, skip dopo 2 s, rinvio con finestre o NPC aperti (✅) | Decisioni UX solide; vanno raccolte in un'unica macchina a stati ([§15](SPEC-09-celebrations.md)) |
| Dalla wiki: ricompense **solo cosmetiche**, group credit pieno a tutti i ruoli, provenienza degli incontri e idempotenza, "non è una skill rating" | Sono i principi anti-tossicità più importanti del progetto |

### 2.3 Cosa modifichiamo

| Elemento originale | Problema | Modifica |
| --- | --- | --- |
| Architettura Addon → Backend API → DB → Web Portal (chat A) | **Impossibile**: un addon WoW non può fare HTTP. Il PO ha escluso anche la companion app | Architettura **P2P solo client** ([§9](SPEC-01-platform-architecture.md), [§12](SPEC-06-network-protocol.md)) |
| "Badge visibile anche a chi non ha l'addon" (chat A, opzione 5) | Impossibile: nessun addon può modificare il client di un altro giocatore | Badge solo per gli utenti addon. Già coerente con ✅ 5.7 |
| 29 rank × 4 divisioni = 116 step | Troppi, e poco distinguibili | ✅ 22 tier × 4 divisioni + 7 apex |
| Apex a sola soglia | Una soglia non rende gli apex davvero esclusivi | ✅ Ogni apex = **soglia + max 100 posti**, con albo storico dei titoli (data di inizio e di fine, ripetibili) |
| "Utente autorizzato" verificato dal backend (5.9) | Senza server non esiste un'autenticazione | Un utente è "registrato" quando la rete ha ricevuto almeno un suo beacon di prima mano ([§11](SPEC-05-ledger-trust.md)) |
| Badge in nameplate "ovunque" (5.21) | Le nameplate amiche **nelle istanze sono forbidden** per gli addon | Fallback in istanza: tooltip, frame party/raid, target frame ([§14.4](SPEC-08-ui-badges.md)) |
| Celebrazioni: 6+ decisioni separate (finestre, NPC, mappa, viaggio…) | Rischio di regole incoerenti | Un'unica **Celebration Queue** con *blocking conditions* configurabili ([§15](SPEC-09-celebrations.md)) |
| Delver basato su kill di ogni creatura (formula della wiki) | Il combat log è **bloccato** dalle restrizioni Midnight (`COMBAT_LOG_EVENT_UNFILTERED` va in errore). Il trash è anche la principale fonte di farming | Solo **boss encounter** (`ENCOUNTER_END`) e completamento istanza. Il trash è escluso per scelta |
| Merchant basato su "economia" (volume d'oro) | Premia la ricchezza ed è farmabile con trasferimenti tra alt | Score su **varietà e controparti distinte**, scala logaritmica, cap settimanale ([§7.7](SPEC-03-activity-catalog.md)) |

### 2.4 Cosa scartiamo

- **Web portal pubblico**: escluso con la scelta "solo addon".
- **Ricompense mount, pet e oggetti in-game** (chat A, opzione 6): un addon non può assegnare oggetti. Questo coincide anche con la regola della wiki "nessun vantaggio di gameplay".
- **Badge sul nome 3D sopra la testa** al posto delle nameplate: il testo nativo del nome non si può modificare. Si usano le nameplate.
- **Testo aggiunto ai propri messaggi in chat** (es. `[Gold II] ciao`) per renderlo visibile ai non-utenti: è invasivo, spam-like e probabilmente contrario alla policy.

### 2.5 Cosa aggiungiamo

| Aggiunta | Perché |
| --- | --- |
| **Ledger eventi** per personaggio, append-only e ricalcolabile ([§11](SPEC-05-ledger-trust.md)) | Senza server, i punti devono essere ricalcolabili da regole pubbliche, mai dichiarati |
| **Attestazioni dei testimoni** ([§11.3](SPEC-05-ledger-trust.md)) | Il nome del mittente di un messaggio addon lo fornisce il server, quindi un testimone presente è l'unica prova non falsificabile disponibile |
| **Livelli di fiducia** (Verified / Self-reported / Flagged) | Trasparenza: la classifica mostra quanto è affidabile un punteggio |
| **Ruleset versionato** | Il bilanciamento cambierà; i punti già acquisiti non devono mai diminuire |
| **Commendations** (encomi tra giocatori, [§7.5](SPEC-03-activity-catalog.md)) | Unico modo sensato per misurare mentorship e supporto alla community in Diplomat e Steward |
| **Prestige Events** (eventi registrati con check-in, [§7.8](SPEC-03-activity-catalog.md)) | Rende misurabili "organizzazione eventi" e "interazioni RP" |
| **Hall of Prestige** ([§13.4](SPEC-07-leaderboards-hall.md)) | Rende permanente lo storico di tutti i titoli apex, come chiesto dal PO |
| **Snapshot settimanali al reset** | Stabilizza classifiche e posti apex in un sistema distribuito |
| **Integrazione con il sistema Legacy** di Forever 🔍 | Forever sostituisce gli achievement con i Legacy Points: è una fonte naturale per Pathfinder e Adventurer |
| **Milestone M0 "API spike"** | Molte API Midnight sono ristrette: va verificato tutto sul client live prima di scrivere codice |

### 2.6 Allineamento con la wiki *Prestige Ranks*

| Wiki | Azeroth Prestige |
| --- | --- |
| Tracce: Adventurer, Explorer, Honor, Gladiator, Challenger, City service | 8 categorie del PO. Le tracce della wiki confluiscono in: Adventurer (wiki) → **Delver**; Explorer (wiki) → **Pathfinder** + **Adventurer**; Honor → **Vanguard** |
| "Challenger" riservato ai dungeon a tempo | Nell'addon "Challenger" è un rank apex. Il conflitto di nomi è accettato: l'addon è un progetto indipendente |
| Ladder illustrativa Wood…Legend IV–I | Ladder estesa del PO ([§6.3](SPEC-02-progression-scoring.md)) |
| Per personaggio, cumulativo, senza decay | ✅ Identico |
| Nessun requisito di rank per accedere ad attività | 🟡 L'addon non offrirà filtri LFG per rank (§4) |
| Badge pubblici opzionali e con spiegazione | ✅ Tooltip esplicativo e opzione per nascondere il proprio badge ([§14.6](SPEC-08-ui-badges.md)) |

## 4. Principi di design

1. **Il prestigio è riconoscimento, non potere.** Nessun vantaggio di gameplay, nessun requisito di rank per accedere a gruppi. Non si offrono filtri LFG per rank, per non alimentare il gatekeeping.
2. **Non è una skill rating.** Il tooltip del badge spiega che cosa misura: impegno e varietà, non bravura.
3. **Completamenti, non ore.** ✅ I punti si guadagnano completando attività: un boss ucciso, un dungeon finito, un BG giocato, una quest consegnata. Il tempo trascorso non vale nulla da solo. Le attività principali sono **ripetibili senza limiti**, e la *prima volta* (prima kill, primo full clear) ha un bonus una tantum.
3b. **Limiti solo dove serve.** ✅ Riduzioni e cap valgono solo per le azioni farmabili in pochi secondi con un complice: duelli con lo stesso avversario, craft ripetuti, trade e vendite, Commendations ([§8.2](SPEC-02-progression-scoring.md)).
3c. **Niente punti tra alt.** ✅ Nessuna interazione tra personaggi dello stesso account genera punti ([§8.5](SPEC-02-progression-scoring.md)).
3d. **Niente punti col boost.** ✅ Se un giocatore di 10+ livelli più alto è nel tuo gruppo o ti aiuta da fuori gruppo, i tuoi punti valgono 0 in tutte le categorie ([§8.6](SPEC-02-progression-scoring.md)).
4. **Parità di ruolo.** Tank, healer, DPS e supporto ricevono lo stesso credito per lo stesso obiettivo.
5. **I punti non si dichiarano, si ricalcolano.** Il client trasmette eventi; ogni peer ricalcola i punti con il ruleset pubblico.
6. **Mai togliere.** Il ribilanciamento vale solo in avanti. Punti, tier e titoli già acquisiti non scendono mai. Si può perdere solo il *posto* apex attuale, mai il titolo nell'albo.
7. **Trasparenza sui limiti.** La classifica mostra quanti profili conosce e quanto sono affidabili.
8. **Non disturbare il gioco.** Niente celebrazioni in combattimento o durante dialoghi, niente traffico di rete in lockdown, CPU minima.

## 5. Glossario

| Termine | Definizione |
| --- | --- |
| **PP** | Prestige Points: punti di una categoria |
| **Categoria** | Una delle 8 progressioni tematiche |
| **Global Prestige (GP)** | Somma dei PP delle 8 categorie, con una ladder propria |
| **Tier** | Gradino della ladder (es. Gold) |
| **Divisione** | Sotto-gradino IV, III, II, I (I è la più alta) |
| **Apex** | I 7 rank da Master a Legend: senza divisioni, con soglia minima di PP e **max 100 posti** ciascuno per categoria (o per GP), assegnati a ogni reset settimanale |
| **Legend** | L'apex più alto |
| **Spodestamento** | Perdita di un posto apex perché altri hanno più punti |
| **Regno (Reign)** | Periodo continuo in cui un personaggio detiene uno specifico apex: data di inizio e, se spodestato, di fine |
| **Albo dei titoli** | Elenco permanente di tutti i regni apex di un personaggio |
| **Ledger** | Registro append-only degli eventi Prestige di un personaggio |
| **Evento Prestige** | Fatto di gioco tracciato (es. una boss kill) che il ruleset converte in PP |
| **Attestazione** | Conferma firmata dal server (nome del mittente) che un altro utente addon era presente all'evento |
| **Beacon** | Messaggio breve e periodico con cui un utente annuncia il proprio riepilogo |
| **Prima mano / seconda mano** | Dato ricevuto dal proprietario stesso / rilanciato da un terzo |
| **Ruleset** | Tabelle versionate di regole e punti (`Data/Ruleset_vN.lua`) |
| **Registrato** | Personaggio di cui la rete ha ricevuto almeno un beacon di prima mano |

## 22. Registro decisioni

| ID | Decisione | Stato | Fonte |
| --- | --- | --- | --- |
| D-01 | Nome: **Azeroth Prestige** | ✅ | Chat A, repo |
| D-02 | Architettura solo addon, P2P, nessun backend né companion app | ✅ | Revisione 2026-11-26 |
| D-03 | 8 categorie, tutte dal day-1 | ✅ | Revisione |
| D-04 | Global = somma delle categorie × (1 + 5% per categoria ≥ Silver IV, max +40%), soglie × 4 | ✅ | Revisione v0.2 |
| D-05 | Progressione per personaggio; riepilogo account locale; alt pubblici solo opt-in | ✅ | Revisione v0.2 |
| D-06 | 22 tier × 4 divisioni (permanenti) + 7 apex, ciascuno con soglia PP e max 100 posti, assegnati a cascata | ✅ | Revisione v0.3 |
| D-07 | IV = ingresso, I = vertice della divisione | 🟡 | Chat A, wiki |
| D-08 | In classifica solo chi usa o ha usato l'addon | ✅ | Chat B 5.7 |
| D-09 | Profilo pubblico solo per gli utenti addon | ✅ | Chat B 5.7 |
| D-10 | Profili permanenti, nessun decay | ✅ | Chat B 5.8 |
| D-11 | Profilo a 3 livelli | 🟡 | Chat B 5.10 |
| D-12 | Badge su tutti i registrati, aggiornamento dinamico | ✅ | Chat C 5.21 |
| D-13 | Badge: Global + categoria in evidenza, override del viewer | ✅ | Revisione v0.2 (5.22) |
| D-14 | Celebrazioni 7–8 s, configurabili | ✅ | Chat D 5.32 |
| D-15 | Promozioni multiple → celebrazione combinata | 🟡 | Chat D 5.33 |
| D-16 | Ibrido pannello / cinematica (apex) | ✅ | Chat E 5.41 |
| D-17 | Skip dopo 2 s | ✅ | Chat E 5.42 |
| D-18 | Suoni configurabili e differenziati | 🟡 | Chat E 5.43 |
| D-19 | Rinvio con finestre aperte | ✅ | Chat F 5.51 |
| D-20 | Rinvio durante le interazioni con NPC | ✅ | Chat F 5.52 |
| D-21 | Rinvio sui trasporti automatici | 🟡 | Chat F 5.53 |
| D-22 | Mappa aperta → sospensione | 🟡 | Chat F 5.60 |
| D-23 | Ricompense solo cosmetiche, interne all'addon | 🟡 | Wiki, vincolo tecnico |
| D-24 | Niente trash nel Delver, solo boss encounter | 🟡 | Vincolo Midnight + anti-farm |
| D-25 | Tutti gli apex richiedono `vr ≥ 0.6` | 🟡 | Questo documento |
| D-26 | Apex anche per il Global (7 × 100 posti, soglie × 4); Legend Global = "Legend of Azeroth" | ✅ | Revisione v0.2–v0.3 |
| D-34 | Apex spodestabili; ogni titolo ottenuto resta nell'albo con data di inizio e fine, regni ripetibili | ✅ | Revisione v0.3 |
| D-35 | Soglia minima per entrare negli apex = Dragonite I (263 460 PP) | ✅ | Revisione v0.3 |
| D-36 | Soglia Legend = 1 000 000 PP | 🟡 | Revisione v0.3 |
| D-37 | Anti-boost: con un giocatore di 10+ livelli più alto in gruppo o che aiuta da fuori gruppo, i punti valgono 0 in tutte le categorie | ✅ | Revisione v0.4 |
| D-38 | Chi aiuta prende Diplomat + i punti del contenuto depotenziati ([§8.7](SPEC-02-progression-scoring.md)) | ✅ | Revisione v0.4 |
| D-41 | Contenuto 10+ livelli sotto il giocatore: punti / differenza di livello, sempre (anche da soli) | ✅ | Revisione v0.4 |
| D-39 | Finestra BOOSTED di 60 s dopo l'ultimo segnale da fuori gruppo; buff fuori combattimento ignorati | 🟡 | Revisione v0.4 |
| D-40 | Eventi una tantum annullati per boost restano consumati | 🟡 | Revisione v0.4 |
| D-27 | Hardcore: memoriale con sigillo "Caduto", punti congelati, Hall of the Fallen | ✅ | Revisione v0.2 |
| D-28 | Backfill al 100% dei PP per i dati confermati dal server | ✅ | Revisione v0.2 |
| D-29 | Nessun punto per interazioni tra personaggi dello stesso account | ✅ | Revisione v0.2 |
| D-30 | Punti per completamento di attività, non per tempo; attività principali ripetibili senza limiti | ✅ | Revisione v0.2 |
| D-31 | Limiti e DR solo su duelli, craft ripetuti, trade/vendite, Commendations | ✅ | Revisione v0.2 |
| D-32 | Asset: placeholder generati, poi AI + rifinitura secondo l'art bible | ✅ | Revisione v0.2 |
| D-33 | Classifiche miste tra fazioni con filtro; Vanguard filtra la propria fazione di default | ✅ | Revisione v0.2 |
| D-42 | Licenze: codice GPL-3.0-or-later, documentazione CC BY 4.0, arte e suoni riservati ([ADR 0012](../adr/0012-licensing-gpl-code-cc-docs-reserved-art.md)) | ✅ | Proprietario, 2026-11-26 |
| D-43 | Versioni: M1–M6 → `v0.1.0`…`v0.6.0`, `v1.0.0` dopo M7 ([ADR 0015](../adr/0015-one-version-per-milestone.md)) | ✅ | Proprietario, 2026-11-26 |
| D-44 | Integrazioni con altri addon: solo un'API pubblica in sola lettura ([ADR 0019](../adr/0019-integrations-public-api-only.md)) | ✅ | Proprietario, 2026-11-26 |
| D-45 | Interfaccia multilingua: enUS base e fallback, itIT dal primo codice, una lingua = un file ([ADR 0010](../adr/0010-interface-and-documentation-languages.md)) | ✅ | Proprietario, 2026-11-26 |
| D-46 | Stile dell'ecosistema (FDCP, Accord), tema dal logo ([ADR 0016](../adr/0016-interface-follows-the-ecosystem-style.md)) | ✅ | Prompt del proprietario |

## 24. Fonti

- Chat di design A–F: private del proprietario, non pubblicate (le decisioni sono in §22).
- Wiki *Prestige and Competitive Recognition*: https://github.com/Finland6738/wow-forever-game-design-proposal/wiki/Prestige-Ranks
- World of Warcraft: Forever, Warcraft Wiki: https://warcraft.wiki.gg/wiki/WoW_Forever
- TOC format: https://warcraft.wiki.gg/wiki/TOC_format
- `C_ChatInfo.SendAddonMessage`: https://warcraft.wiki.gg/wiki/API_C_ChatInfo.SendAddonMessage
- Secret values: https://warcraft.wiki.gg/wiki/Secret_values
- Patch 12.0.0 API changes: https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes
- WoW Forever loads retail addons: https://www.warcrafttavern.com/forever/news/wow-forever-loads-your-retail-addons-keybinds/

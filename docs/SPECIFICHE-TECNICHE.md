# Azeroth Prestige — Specifiche Tecniche

> Addon per **World of Warcraft: Forever** · Documento di specifica v0.1 (bozza)
> Data: 2026-11-26 · Stato: **in revisione** · v0.2: risolte le 10 questioni aperte di v0.1 · v0.3: apex a posti limitati con albo dei titoli · v0.4: regola anti-boost
> Nome cartella addon: `AzerothPrestige` · Comandi slash: `/prestige`, `/azp`

**Legenda stati usata nel documento**

| Simbolo | Significato |
| --- | --- |
| ✅ | Decisione **confermata** dal Product Owner (nelle chat A–F o in questa revisione) |
| 🟡 | **Proposta** del team: valida fino a diversa decisione |
| 🔍 | **Da verificare** sul client live di WoW Forever (milestone M0) prima di implementare |

---

## Indice

1. [Executive summary](#1-executive-summary)
2. [Analisi del lavoro precedente](#2-analisi-del-lavoro-precedente)
3. [Vincoli della piattaforma WoW Forever](#3-vincoli-della-piattaforma-wow-forever)
4. [Principi di design](#4-principi-di-design)
5. [Glossario](#5-glossario)
6. [Modello di progressione](#6-modello-di-progressione)
7. [Catalogo attività per categoria](#7-catalogo-attività-per-categoria)
8. [Regole di scoring trasversali](#8-regole-di-scoring-trasversali)
9. [Architettura dell'addon](#9-architettura-delladdon)
10. [Modello dati e SavedVariables](#10-modello-dati-e-savedvariables)
11. [Ledger, attestazioni e livelli di fiducia](#11-ledger-attestazioni-e-livelli-di-fiducia)
12. [Protocollo di rete peer-to-peer](#12-protocollo-di-rete-peer-to-peer)
13. [Classifiche e Hall of Prestige](#13-classifiche-e-hall-of-prestige)
14. [UI/UX](#14-uiux)
15. [Sistema di celebrazioni](#15-sistema-di-celebrazioni)
16. [Ricompense](#16-ricompense)
17. [Prestazioni e budget](#17-prestazioni-e-budget)
18. [Localizzazione e accessibilità](#18-localizzazione-e-accessibilità)
19. [Compatibilità e policy](#19-compatibilità-e-policy)
20. [Testing e QA](#20-testing-e-qa)
21. [Roadmap](#21-roadmap)
22. [Registro decisioni](#22-registro-decisioni)
23. [Questioni aperte](#23-questioni-aperte)
24. [Fonti](#24-fonti)

---

## 1. Executive summary

**Azeroth Prestige** è un sistema di **identità e reputazione del personaggio**, parallelo alla progressione di WoW Forever. I giocatori guadagnano **Prestige Points (PP)** in **8 categorie** di attività. Al crescere dei punti salgono una scala di rank: **22 tier metallici e gemme** con divisioni IV→I, poi **7 rank apex** (da Master a Legend), ciascuno con una soglia di punti e **al massimo 100 posti** per categoria. Gli apex si possono perdere se si viene superati, ma ogni titolo ottenuto resta nell'albo del personaggio con date di inizio e fine. Una nona progressione, il **Global Prestige**, somma le otto categorie con un bonus per la varietà.

I punti premiano il **completamento di attività**, non il tempo trascorso. Le attività principali (dungeon, raid, boss, battleground) danno punti pieni **a ogni completamento**, senza riduzioni. I limiti esistono solo per le azioni farmabili in pochi secondi (duelli, craft, trade, encomi). Nessuna interazione tra personaggi dello stesso account genera punti, e chi viene **boostato** da un giocatore di 10+ livelli più alto non guadagna punti.

Il prestigio è **permanente**: non decade, non si resetta e resta visibile anche quando il proprietario disinstalla l'addon. I rank compaiono come **badge** sulle nameplate, nei tooltip, nel menu unità e in chat, e si possono consultare in un **profilo a tre livelli** e in **classifiche per categoria**.

**Scelta architetturale (✅):** l'addon è **solo client, per sempre**: nessun backend, nessuna companion app. I dati circolano tra gli utenti dell'addon con un protocollo **peer-to-peer** sopra il canale messaggi addon di WoW. Da questa scelta derivano tre conseguenze che il documento affronta in modo esplicito:

1. Le classifiche sono **"network-observed"**: mostrano ciò che la rete di utenti conosce, non una verità globale autorevole.
2. L'anti-cheat non può essere crittografico: si basa su **attestazioni dei testimoni**, **ricalcolo deterministico dei punti** e **controlli di plausibilità**.
3. Il badge è visibile **solo a chi usa l'addon**: è un limite tecnico invalicabile, e coincide con la decisione ✅ "profilo pubblico per gli utenti addon".

---

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
| Badge su tutti i registrati, con aggiornamento dinamico e cache locale (✅ 5.21-C) | Giusto, ma la cache passa dal backend alla rete P2P (§12) |
| Profilo a 3 livelli: Overview, Category Details, Statistics | Buon equilibrio tra leggibilità e profondità |
| Celebrazioni: 7–8 s configurabili, sistema ibrido pannello/cinematico, skip dopo 2 s, rinvio con finestre o NPC aperti (✅) | Decisioni UX solide; vanno raccolte in un'unica macchina a stati (§15) |
| Dalla wiki: ricompense **solo cosmetiche**, group credit pieno a tutti i ruoli, provenienza degli incontri e idempotenza, "non è una skill rating" | Sono i principi anti-tossicità più importanti del progetto |

### 2.3 Cosa modifichiamo

| Elemento originale | Problema | Modifica |
| --- | --- | --- |
| Architettura Addon → Backend API → DB → Web Portal (chat A) | **Impossibile**: un addon WoW non può fare HTTP. Il PO ha escluso anche la companion app | Architettura **P2P solo client** (§9, §12) |
| "Badge visibile anche a chi non ha l'addon" (chat A, opzione 5) | Impossibile: nessun addon può modificare il client di un altro giocatore | Badge solo per gli utenti addon. Già coerente con ✅ 5.7 |
| 29 rank × 4 divisioni = 116 step | Troppi, e poco distinguibili | ✅ 22 tier × 4 divisioni + 7 apex |
| Apex a sola soglia | Una soglia non rende gli apex davvero esclusivi | ✅ Ogni apex = **soglia + max 100 posti**, con albo storico dei titoli (data di inizio e di fine, ripetibili) |
| "Utente autorizzato" verificato dal backend (5.9) | Senza server non esiste un'autenticazione | Un utente è "registrato" quando la rete ha ricevuto almeno un suo beacon di prima mano (§11) |
| Badge in nameplate "ovunque" (5.21) | Le nameplate amiche **nelle istanze sono forbidden** per gli addon | Fallback in istanza: tooltip, frame party/raid, target frame (§14.4) |
| Celebrazioni: 6+ decisioni separate (finestre, NPC, mappa, viaggio…) | Rischio di regole incoerenti | Un'unica **Celebration Queue** con *blocking conditions* configurabili (§15) |
| Delver basato su kill di ogni creatura (formula della wiki) | Il combat log è **bloccato** dalle restrizioni Midnight (`COMBAT_LOG_EVENT_UNFILTERED` va in errore). Il trash è anche la principale fonte di farming | Solo **boss encounter** (`ENCOUNTER_END`) e completamento istanza. Il trash è escluso per scelta |
| Merchant basato su "economia" (volume d'oro) | Premia la ricchezza ed è farmabile con trasferimenti tra alt | Score su **varietà e controparti distinte**, scala logaritmica, cap settimanale (§7.7) |

### 2.4 Cosa scartiamo

- **Web portal pubblico**: escluso con la scelta "solo addon".
- **Ricompense mount, pet e oggetti in-game** (chat A, opzione 6): un addon non può assegnare oggetti. Questo coincide anche con la regola della wiki "nessun vantaggio di gameplay".
- **Badge sul nome 3D sopra la testa** al posto delle nameplate: il testo nativo del nome non si può modificare. Si usano le nameplate.
- **Testo aggiunto ai propri messaggi in chat** (es. `[Gold II] ciao`) per renderlo visibile ai non-utenti: è invasivo, spam-like e probabilmente contrario alla policy.

### 2.5 Cosa aggiungiamo

| Aggiunta | Perché |
| --- | --- |
| **Ledger eventi** per personaggio, append-only e ricalcolabile (§11) | Senza server, i punti devono essere ricalcolabili da regole pubbliche, mai dichiarati |
| **Attestazioni dei testimoni** (§11.3) | Il nome del mittente di un messaggio addon lo fornisce il server, quindi un testimone presente è l'unica prova non falsificabile disponibile |
| **Livelli di fiducia** (Verified / Self-reported / Flagged) | Trasparenza: la classifica mostra quanto è affidabile un punteggio |
| **Ruleset versionato** | Il bilanciamento cambierà; i punti già acquisiti non devono mai diminuire |
| **Commendations** (encomi tra giocatori, §7.5) | Unico modo sensato per misurare mentorship e supporto alla community in Diplomat e Steward |
| **Prestige Events** (eventi registrati con check-in, §7.8) | Rende misurabili "organizzazione eventi" e "interazioni RP" |
| **Hall of Prestige** (§13.4) | Rende permanente lo storico di tutti i titoli apex, come chiesto dal PO |
| **Snapshot settimanali al reset** | Stabilizza classifiche e posti apex in un sistema distribuito |
| **Integrazione con il sistema Legacy** di Forever 🔍 | Forever sostituisce gli achievement con i Legacy Points: è una fonte naturale per Pathfinder e Adventurer |
| **Milestone M0 "API spike"** | Molte API Midnight sono ristrette: va verificato tutto sul client live prima di scrivere codice |

### 2.6 Allineamento con la wiki *Prestige Ranks*

| Wiki | Azeroth Prestige |
| --- | --- |
| Tracce: Adventurer, Explorer, Honor, Gladiator, Challenger, City service | 8 categorie del PO. Le tracce della wiki confluiscono in: Adventurer (wiki) → **Delver**; Explorer (wiki) → **Pathfinder** + **Adventurer**; Honor → **Vanguard** |
| "Challenger" riservato ai dungeon a tempo | Nell'addon "Challenger" è un rank apex. Il conflitto di nomi è accettato: l'addon è un progetto indipendente |
| Ladder illustrativa Wood…Legend IV–I | Ladder estesa del PO (§6.3) |
| Per personaggio, cumulativo, senza decay | ✅ Identico |
| Nessun requisito di rank per accedere ad attività | 🟡 L'addon non offrirà filtri LFG per rank (§4) |
| Badge pubblici opzionali e con spiegazione | ✅ Tooltip esplicativo e opzione per nascondere il proprio badge (§14.6) |

---

## 3. Vincoli della piattaforma WoW Forever

### 3.1 Fatti accertati

| Aspetto | Valore |
| --- | --- |
| Prodotto | World of Warcraft: Forever (Blizzard), uscito il 4 novembre 2026 |
| Versione client | Patch 1.60.1 (build 69913). Include le modifiche "Modern" fino alla 12.1.5 (UI e API dell'era *Midnight*) |
| TOC | `## Interface: 16001`. File `AzerothPrestige_Forever.toc` (alias `_Camelot`), famiglia *mainline* |
| Contenuti | Level cap 60, fisso. Dungeon 10–60; raid Barrow Deeps (10), Hyjal Summit (20), Onyxia's Lair (40); BG Darkspear Islands; professioni; **Legacy system** al posto degli achievement |
| Realm | Un **mega-realm** per ruleset e regione: Normal, PvP, RP, RP-PvP, Hardcore |
| Messaggi addon | `C_ChatInfo.SendAddonMessage(prefix, msg, chatType, target)`. Prefisso ≤ 16 caratteri, messaggio ≤ 255 byte, niente `\0`. Throttle per prefisso: 10 messaggi di burst, ricarica 1/s. I whisper fuori dalle istanze ne sono esenti |
| Account trial | **Non possono inviare messaggi addon** (dalla 1.60.1) |
| Restrizioni Midnight | *Secret values*: in combattimento, encounter e mappe ristrette (dungeon, raid) molte API restituiscono valori segreti, su cui gli addon non possono confrontare, fare aritmetica o indicizzare. Esempi: `UnitHealth` su unità altrui, aura, cast, cooldown |
| Combat log | La registrazione di `COMBAT_LOG_EVENT_UNFILTERED` **va in errore** (mainline 12.0) |
| Chat lockdown | `C_ChatInfo.InChatMessagingLockdown()`; `SendAddonMessage` può restituire `Enum.SendAddonMessageResult.AddOnMessageLockdown` (11) |

### 3.2 Implicazioni architetturali

1. **Niente combat log.** Il tracciamento usa solo eventi di alto livello: encounter, quest, skill, PvP stats, mail, trade.
2. **Coda di invio obbligatoria.** In lockdown (encounter, mappe ristrette) i messaggi non partono. Ogni messaggio va in coda e viene ritentato quando `InChatMessagingLockdown()` torna `false`.
3. **Chat in istanza.** Il nome del mittente in chat può risultare *secret* nelle istanze. In quel caso i badge in chat vanno disattivati, invece di generare errori Lua.
4. **Nameplate amiche forbidden nelle istanze.** Va previsto un fallback.
5. **Mega-realm** = popolazione molto alta. Il protocollo deve scalare: beacon rari, profili scaricati solo su richiesta, cache con eviction.
6. **Account trial**: solo modalità locale, senza condivisione (va mostrato un avviso in UI).

### 3.3 Checklist di verifica M0 (🔍)

Ogni voce va testata sul client live con uno script di spike (`/azp spike`). L'esito va annotato in `docs/m0-api-report.md`.

| # | Verifica | Impatto se negativa |
| --- | --- | --- |
| V1 | `ENCOUNTER_END` (encounterID, name, difficultyID, groupSize, success) arriva con valori **non secret** | Delver va riprogettato (fallback: `BOSS_KILL`, loot, `CHAT_MSG_SYSTEM`) |
| V2 | `UnitName` / `UnitGUID` dei giocatori su nameplate e tooltip **non secret**, dentro e fuori istanza | Niente lookup dei badge nei contesti ristretti |
| V3 | `C_NamePlate.GetNamePlateForUnit` e `IsForbidden()` sulle nameplate amiche in istanza | Fallback nameplate |
| V4 | `SendAddonMessage` su `CHANNEL` di un canale custom: limiti, throttle, cross-faction | Strategia di discovery (§12.3) |
| V5 | Esatte condizioni di `AddOnMessageLockdown` | Logica della coda di invio |
| V6 | `QUEST_TURNED_IN`, `C_QuestLog.IsQuestFlaggedCompleted` | Adventurer |
| V7 | API del **Legacy system** (nome namespace, eventi) | Integrazione Legacy |
| V8 | `GetPVPLifetimeStats`, `PVP_MATCH_COMPLETE`, `C_PvP.GetActiveMatchWinner`, `DUEL_FINISHED` | Vanguard |
| V9 | Esplorazione: `C_MapExplorationInfo`, `UI_INFO_MESSAGE` per "Discovered", `C_TaxiMap.GetAllTaxiNodes` | Pathfinder |
| V10 | Professioni: `GetProfessions`, `GetProfessionInfo`, eventi di skill-up e learn recipe | Artisan |
| V11 | Auction House presente in Forever? `GetInboxInvoiceInfo`, eventi di trade | Merchant |
| V12 | `ChatFrameUtil.AddMessageEventFilter` / `ChatFrame_AddMessageEventFilter` in Forever | Badge in chat |
| V13 | `TooltipDataProcessor.AddTooltipPostCall`, `Menu.ModifyMenu("MENU_UNIT_PLAYER")` | Tooltip e menu |
| V14 | `C_EncodingUtil` (serialize/compress/base64) disponibile | Scelta tra lib native e LibSerialize/LibDeflate |
| V15 | `PLAYER_INTERACTION_MANAGER_FRAME_SHOW/HIDE`, `UnitOnTaxi`, `C_Calendar` | Celebrazioni, Prestige Events |
| V16 | CVar per forzare le restrizioni in test (`addonCombatRestrictionsForced` o `secretCombatRestrictionsForced`) | QA |
| V17 | Rilevamento realm Hardcore (game rules API) e `PLAYER_DEAD` affidabile per la morte permanente | Memoriale Hardcore |
| V18 | Scoreboard BG di fine match (`C_PvP.GetScoreInfo`, campo `killingBlows`) disponibile e non secret | `VAN_KB` |
| V19 | `UnitLevel` restituisce `-1` per i giocatori ostili molto più alti; `UnitLevel` dei membri del gruppo sempre leggibile | Trigger G e A1 |
| V20 | `sourceUnit` delle aure sul giocatore (`C_UnitAuras`) leggibile fuori dalle istanze, anche in combattimento | Trigger A3 |
| V21 | Token `nameplateNtarget` e `targettarget` con `UnitIsUnit` non secret nel mondo aperto | Trigger A1 e A2 |

---

## 4. Principi di design

1. **Il prestigio è riconoscimento, non potere.** Nessun vantaggio di gameplay, nessun requisito di rank per accedere a gruppi. Non si offrono filtri LFG per rank, per non alimentare il gatekeeping.
2. **Non è una skill rating.** Il tooltip del badge spiega che cosa misura: impegno e varietà, non bravura.
3. **Completamenti, non ore.** ✅ I punti si guadagnano completando attività: un boss ucciso, un dungeon finito, un BG giocato, una quest consegnata. Il tempo trascorso non vale nulla da solo. Le attività principali sono **ripetibili senza limiti**, e la *prima volta* (prima kill, primo full clear) ha un bonus una tantum.
3b. **Limiti solo dove serve.** ✅ Riduzioni e cap valgono solo per le azioni farmabili in pochi secondi con un complice: duelli con lo stesso avversario, craft ripetuti, trade e vendite, Commendations (§8.2).
3c. **Niente punti tra alt.** ✅ Nessuna interazione tra personaggi dello stesso account genera punti (§8.5).
3d. **Niente punti col boost.** ✅ Se un giocatore di 10+ livelli più alto è nel tuo gruppo o ti aiuta da fuori gruppo, i tuoi punti valgono 0 in tutte le categorie (§8.6).
4. **Parità di ruolo.** Tank, healer, DPS e supporto ricevono lo stesso credito per lo stesso obiettivo.
5. **I punti non si dichiarano, si ricalcolano.** Il client trasmette eventi; ogni peer ricalcola i punti con il ruleset pubblico.
6. **Mai togliere.** Il ribilanciamento vale solo in avanti. Punti, tier e titoli già acquisiti non scendono mai. Si può perdere solo il *posto* apex attuale, mai il titolo nell'albo.
7. **Trasparenza sui limiti.** La classifica mostra quanti profili conosce e quanto sono affidabili.
8. **Non disturbare il gioco.** Niente celebrazioni in combattimento o durante dialoghi, niente traffico di rete in lockdown, CPU minima.

---

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

---

## 6. Modello di progressione

### 6.1 Entità

- ✅ **Per personaggio.** I PP non si sommano tra personaggi dello stesso account.
- ✅ Una vista *Account Summary* mostra i personaggi dell'utente, senza unirne i punti. Di default è **solo locale**.
- ✅ **Collegamento pubblico degli alt, opt-in.** Il giocatore può pubblicare l'elenco dei propri personaggi collegati ("Altri personaggi: X, Y"). È disattivato di default e ogni personaggio va abilitato singolarmente. Il collegamento viaggia nel profilo (`alts`) solo se attivo, e revocarlo pubblica una nuova versione senza l'elenco.
- Identificativo: `Nome-RealmNormalizzato` (`GetNormalizedRealmName()`). Il GUID del giocatore si salva quando disponibile, per gestire rename e transfer 🔍.

### 6.2 Le 8 categorie (✅ tutte dal day-1)

| ID | Nome | Icona | Tema |
| --- | --- | --- | --- |
| `VAN` | Vanguard | ⚔️ | PvP, World PvP, duelli, battleground, obiettivi militari |
| `DEL` | Delver | 🏰 | Dungeon, raid, boss, progress |
| `PAT` | Pathfinder | 🧭 | Zone, flight path, segreti, esplorazione |
| `ADV` | Adventurer | 📜 | Quest, storyline, reputazione |
| `DIP` | Diplomat | 🤝 | Aiuto ai nuovi, mentorship, RP, socialità |
| `ART` | Artisan | ⚒️ | Professioni, ricette, craft |
| `MER` | Merchant | 💰 | Auction House, trading, contratti |
| `STE` | Steward | 🏛️ | Organizzazione eventi, reclutamento, gestione gilda, supporto |

**Confine Diplomat / Steward (🟡):** Diplomat premia la **relazione individuale**: aiutare, insegnare, partecipare. Steward premia l'**organizzazione collettiva**: creare eventi, guidare, gestire, reclutare. Una stessa azione non assegna mai punti a entrambe: un evento dà punti Steward all'organizzatore e punti Diplomat ai partecipanti.

### 6.3 Ladder dei rank (✅ struttura, 🟡 soglie)

**22 tier × 4 divisioni = 88 step**, con soglie a crescita geometrica (incremento base 100 PP, crescita 6% per step):

```
soglia(n) = round10( 100 × ((1.06)^n − 1) / 0.06 )      n = 0..87
```

| # | Tier | IV | III | II | I |
| --- | --- | ---: | ---: | ---: | ---: |
| 1 | 🌲 Wood | 0 | 100 | 210 | 320 |
| 2 | 🪨 Stone | 440 | 560 | 700 | 840 |
| 3 | 🥉 Copper | 990 | 1 150 | 1 320 | 1 500 |
| 4 | ⚙️ Tin | 1 690 | 1 890 | 2 100 | 2 330 |
| 5 | 🛡️ Bronze | 2 570 | 2 820 | 3 090 | 3 380 |
| 6 | ⛓️ Iron | 3 680 | 4 000 | 4 340 | 4 700 |
| 7 | ⚔️ Steel | 5 080 | 5 490 | 5 920 | 6 370 |
| 8 | ✨ Silver | 6 850 | 7 360 | 7 910 | 8 480 |
| 9 | 👑 Gold | 9 090 | 9 730 | 10 420 | 11 140 |
| 10 | 💠 Mithril | 11 910 | 12 730 | 13 590 | 14 510 |
| 11 | 🌟 Truesilver | 15 480 | 16 500 | 17 600 | 18 750 |
| 12 | 🖤 Dark Iron | 19 980 | 21 270 | 22 650 | 24 110 |
| 13 | 💜 Thorium | 25 660 | 27 300 | 29 030 | 30 880 |
| 14 | 🔴 Ruby | 32 830 | 34 900 | 37 090 | 39 420 |
| 15 | 🔵 Sapphire | 41 880 | 44 500 | 47 260 | 50 200 |
| 16 | 🟢 Emerald | 53 310 | 56 610 | 60 110 | 63 810 |
| 17 | 🟡 Topaz | 67 740 | 71 910 | 76 320 | 81 000 |
| 18 | 🟣 Amethyst | 85 960 | 91 220 | 96 790 | 102 700 |
| 19 | 🤍 Diamond | 108 960 | 115 600 | 122 640 | 130 090 |
| 20 | ⚜️ Arcanite | 138 000 | 146 380 | 155 260 | 164 680 |
| 21 | 🌋 Elementium | 174 660 | 185 240 | 196 450 | 208 340 |
| 22 | 🐉 Dragonite | 220 940 | 234 300 | 248 460 | 263 460 |

**Apex: 7 rank a posti limitati (✅).** Ogni apex richiede **una soglia di PP** e ammette **al massimo 100 personaggi** per categoria e realm. In totale ci sono 700 posti apex per ognuna delle 8 categorie e per il Global.

| Rank | Soglia minima PP categoria | Posti | Presentazione |
| --- | ---: | ---: | --- |
| 👑 Master | 263 460 (= Dragonite I, ✅ minimo unico per entrare negli apex) | 100 | Cinematica |
| 🏆 Grandmaster | 340 000 | 100 | Cinematica |
| ⚔️ Challenger | 410 000 | 100 | Cinematica |
| 👑 Titan | 500 000 | 100 | Cinematica |
| 🌌 Keeper | 620 000 | 100 | Cinematica |
| 🔥 Aspect | 780 000 | 100 | Cinematica |
| ✨ **Legend** | 1 000 000 (🟡) | 100 | Cinematica + Hall of Prestige |

**Assegnazione dei posti "a cascata"**, valutata a ogni reset settimanale (§13.3):

```
eleggibili = profili con PP ≥ 263 460, vr ≥ 0.6, src ≤ 2, non flagged, non Caduti
ordina eleggibili per PP decrescente
  (spareggio: chi ha raggiunto prima quel totale → timestamp dell'ultimo evento; poi nome)
per apex da Legend fino a Master:
    candidati = eleggibili non ancora assegnati con PP ≥ soglia(apex)
    assegna i primi 100 candidati a quell'apex
chi resta senza posto → il proprio tier a soglia (es. Dragonite I)
```

Esempi:

- Un personaggio con 800 000 PP che arriva 130° tra chi supera la soglia di Aspect **non** è Aspect: scende a competere per Keeper. Se lì trova posto è Keeper, altrimenti continua a scendere.
- Chi viene superato da altri giocatori può essere **spodestato**: scende all'apex inferiore o torna a Dragonite I.
- Una fascia può restare vuota o parzialmente piena finché nessuno raggiunge la soglia, soprattutto nei primi mesi.

**Ritmo espresso in attività (✅ principio, 🟡 valori da calibrare in beta).** Le soglie si leggono in *completamenti*, non in ore. Esempio Delver: un dungeon di livello 55 con 5 boss, completato per intero, vale 275 (boss) + 110 (clear) + 165 (full clear) = **550 PP**.

| Traguardo Delver | PP | Full clear equivalenti (dungeon liv. 55) |
| --- | ---: | ---: |
| Bronze IV | 2 570 | ~5 |
| Silver IV | 6 850 | ~12 |
| Gold IV | 9 090 | ~17 |
| Diamond IV | 108 960 | ~200 |
| Dragonite I / soglia Master | 263 460 | ~480 |
| Soglia Aspect | 780 000 | ~1 400 |
| Soglia Legend | 1 000 000 | ~1 800 |

I bonus una tantum (prime kill, primo clear dei raid) e i raid, che valgono di più per boss, accorciano molto il percorso reale. Gli apex restano traguardi da veterani. La beta tarerà i valori per categoria in modo che percorsi di attività equivalenti diano rank equivalenti in tutte le 8 categorie.

### 6.4 Global Prestige (✅)

```
GP = Σ PP(categorie) × (1 + 0.05 × N)
N  = numero di categorie con PP ≥ 6 850 (Silver IV), da 0 a 8  →  bonus massimo +40%
```

- **Somma con bonus varietà**: premia chi gioca più stili senza penalizzare gli specialisti.
- Il bonus è calcolato sui PP attuali, quindi il GP resta monotono: N può solo crescere.
- Ladder identica nella forma, con **tutte le soglie × 4**.
- ✅ Gli **apex Global** funzionano come quelli di categoria: 7 apex × 100 posti, con soglie × 4 (Master ≥ 1 053 840 GP … Legend ≥ 4 000 000 GP). Il Legend Global ha il titolo "Legend of Azeroth", il più prestigioso del sistema.

### 6.5 Permanenza, apex e albo dei titoli

**Tier 1–22 (Wood → Dragonite): permanenti (✅).** PP e tier non scendono mai. Lo stato salvato è `peakTier`.

**Apex: competitivi (✅).** Un posto apex si può perdere se altri giocatori ti superano. **Ogni titolo apex ottenuto però resta per sempre nell'albo** del personaggio, come un achievement, con data di inizio e data di fine:

```lua
apexReigns = {
  { cat = "VAN", rank = "ASPECT", start = 1767052800, finish = 1769472000 },  -- spodestato
  { cat = "VAN", rank = "KEEPER", start = 1769472000, finish = 1770681600 },  -- sceso di fascia, poi uscito
  { cat = "VAN", rank = "LEGEND", start = 1772064000, finish = nil },         -- regno in corso
}
```

- Ogni cambio di fascia **chiude** il regno corrente (`finish` = data del reset) e, se il personaggio ottiene un altro apex, ne **apre** uno nuovo (`start` = stessa data).
- Riconquistare un titolo già avuto apre un **nuovo regno** con nuove date. I regni precedenti restano.
- Il **badge** mostra il rank **attuale**: l'apex in corso, oppure il tier a soglia se non si ha un posto. Se il personaggio ha avuto un apex più alto in passato, il badge aggiunge un piccolo **sigillo storico** con il titolo migliore mai ottenuto (es. sigillo "Ex-Legend" su un badge Keeper).
- Il profilo (§14.2) mostra l'**albo dei titoli** completo: ogni apex, con date e durata.

---

## 7. Catalogo attività per categoria

**Convenzioni**

- `L` = livello nativo del contenuto: livello del boss o della quest (`UnitLevel` del boss non serve, il valore viene dal ruleset per `encounterID`).
- **Una tantum** = una sola volta per personaggio. **Ripetibile** = soggetto a diminishing returns (§8.2).
- Ogni regola ha un `ruleId` stabile, usato nel ledger.
- I valori sono **iniziali di calibrazione** (🟡) e stanno in `Data/Ruleset_v1.lua`.
- **Sorgente** indica eventi e API (🔍 secondo la checklist M0).

### 7.1 ⚔️ Vanguard

| ruleId | Attività | Sorgente | Punti | Tipo / anti-abuso |
| --- | --- | --- | --- | --- |
| `VAN_BG_WIN` | Battleground vinto | `PVP_MATCH_COMPLETE` + `C_PvP.GetActiveMatchWinner` | 120 | Ripetibile. Richiede ≥ 70% della durata in BG |
| `VAN_BG_LOSS` | Battleground perso | idem | 40 | Ripetibile. Partecipazione minima come sopra; niente credito se si esce prima |
| `VAN_BG_FIRST` | Primo match in un BG specifico | idem | 200 | Una tantum per BG |
| `VAN_KB` | Killing blow in battleground | scoreboard di fine match (`C_PvP.GetScoreInfo` → `killingBlows`) 🔍 | 8 / KB | Ripetibile, senza limiti |
| `VAN_HK` | Honorable kill (delta del contatore server) | `GetPVPLifetimeStats` (diff alla sessione) | 3 / HK | Ripetibile, senza limiti. Il contatore è autorevole lato server e il gioco non assegna HK su bersagli "grigi" |
| `VAN_WPVP_HK` | HK fuori dal BG (World PvP) | idem + zona non-BG | +2 bonus / HK | Ripetibile, senza limiti |
| `VAN_DUEL_WIN` | Duello vinto | `DUEL_FINISHED` + `CHAT_MSG_SYSTEM` (vincitore) | 15 | ⛔ **Limitato** (§8.2): max 3 conteggiati per avversario al giorno. Avversario di livello ≥ proprio − 5 |
| `VAN_DUEL_LOSS` | Duello perso | idem | 5 | ⛔ Stessi limiti |
| `VAN_DUEL_NEWOPP` | Primo duello contro un avversario mai affrontato | idem | 10 | Una tantum per avversario, ⛔ cap 10 al giorno |
| `VAN_MIL_OBJ` | Obiettivo militare (cattura, difesa, warfare di Forever) | 🔍 eventi warfare/area POI | 50–150 | Da definire dopo la verifica dei contenuti Forever |

### 7.2 🏰 Delver

Sorgente: `ENCOUNTER_END(encounterID, encounterName, difficultyID, groupSize, success == 1)`. È eleggibile chi è nel gruppo, nell'istanza e **non AFK** (`UnitIsAFK`). Morti e disconnessioni durante il pull **contano** (parità di ruolo e principio della wiki).

| ruleId | Attività | Punti | Tipo |
| --- | --- | --- | --- |
| `DEL_BOSS` | Boss di dungeon sconfitto | `L × 1.0` | Ripetibile, senza limiti |
| `DEL_BOSS_RAID` | Boss di raid | `L × fattore` (10-man 2.0, 20-man 2.5, 40-man 3.0) | Ripetibile, senza limiti (il gioco stesso impone il lockout) |
| `DEL_FIRST_KILL` | Prima kill di quel boss per il personaggio | `L × 3` (dungeon), `L × 10` (raid) | Una tantum |
| `DEL_CLEAR` | Ultimo boss di un'istanza (clear) | `L × 2` | Ripetibile, senza limiti |
| `DEL_FULL_CLEAR` | **Tutti i boss** dell'istanza nella stessa run (completamento del dungeon) | `L × 3` | Ripetibile, senza limiti |
| `DEL_FIRST_FULL_CLEAR` | Primo full clear di quell'istanza per il personaggio | `L × 6` | Una tantum |
| `DEL_PROGRESS` | Primo clear completo di un raid | 2 000 / 3 000 / 5 000 (10/20/40) | Una tantum |
| `DEL_WIPE_LEARN` | 🟡 Kill dopo ≥ 5 wipe sullo stesso boss nella stessa run ("perseveranza") | `L × 1` | Una tantum per boss |

Per contenuti 10+ livelli sotto il giocatore i punti sono depotenziati (§8.7).

Esempio: un dungeon di livello 55 con 5 boss, completato per intero da un personaggio di livello 50–60, dà 275 + clear 110 + full clear 165 = **550 PP** a ogni run. La prima volta si aggiungono 825 (prime kill) + 330 (primo full clear).

### 7.3 🧭 Pathfinder

| ruleId | Attività | Sorgente | Punti | Tipo |
| --- | --- | --- | --- | --- |
| `PAT_AREA` | Nuova sub-zona scoperta | `UI_INFO_MESSAGE` / `C_MapExplorationInfo` (diff dello stato esplorato) | 25 | Una tantum per area |
| `PAT_ZONE_FULL` | Zona esplorata al 100% | idem | 300 | Una tantum per zona |
| `PAT_FLIGHT` | Nuovo flight path appreso | `TAXIMAP_OPENED` + `C_TaxiMap.GetAllTaxiNodes` (diff) | 60 | Una tantum per nodo |
| `PAT_SECRET` | Segreto curato raggiunto (coordinate + raggio, definito nel ruleset) | `C_Map.GetBestMapForUnit` + `GetPlayerMapPosition`, polling a 1 Hz solo fuori dalle istanze | 100–500 | Una tantum. Lista segreti in `Data/Secrets.lua` |
| `PAT_LEGACY` | Legacy di esplorazione ottenuto | 🔍 API Legacy | `LegacyPoints × 20` | Una tantum |
| `PAT_CONTINENT` | Continente completato al 100% | derivato | 2 000 | Una tantum |

Nota: correre avanti e indietro su un confine non rende nulla, perché tutto è una tantum (principio della wiki).

### 7.4 📜 Adventurer

| ruleId | Attività | Sorgente | Punti | Tipo |
| --- | --- | --- | --- | --- |
| `ADV_QUEST` | Quest completata | `QUEST_TURNED_IN(questID)` | `max(10, L × 1.5)` | Una tantum per questID (il gioco non la ripropone). Le daily e le ripetibili sono ripetibili senza limiti |
| `ADV_QUEST_ELITE` | Quest elite o di gruppo | flag del ruleset per questID | ×2 | Una tantum |
| `ADV_STORY` | Capitolo o storyline completata (catena definita nel ruleset) | derivato da questID | 500–2 000 | Una tantum |
| `ADV_REP_STANDING` | Nuovo standing raggiunto con una fazione (Friendly → Exalted) | `UPDATE_FACTION` + standing | Friendly 100, Honored 250, Revered 600, Exalted 1 500 | Una tantum per fazione e standing |
| `ADV_LEGACY` | Legacy di quest o storia | 🔍 | `LegacyPoints × 20` | Una tantum |

Anti-abuso: un ciclo accetta/abbandona non rende, perché conta solo il turn-in. Le quest già completate prima dell'installazione si importano con un **backfill una tantum** (§7.9).

### 7.5 🤝 Diplomat

È la categoria più soggettiva. Usa solo **proxy misurabili** e **Commendations**.

| ruleId | Attività | Sorgente | Punti | Tipo / anti-abuso |
| --- | --- | --- | --- | --- |
| `DIP_HELP_LOW` | Completare un contenuto in gruppo (quest, boss) con un membro ≥ 10 livelli sotto di te e sotto il 60 | `UnitLevel` dei membri al momento dell'evento | 30 per membro aiutato, per evento | Ripetibile, senza limiti. Regola anti-alt (§8.5). È il rovescio della regola anti-boost (§8.6): chi aiuta prende questi punti, chi è aiutato non prende punti |
| `DIP_MENTOR` | Il membro aiutato è un utente addon e ti attesta come "mentore" | attestazione dal suo client | 150 | ⛔ È un'attestazione tra due persone, quindi segue le regole delle Commendations: una volta per coppia ogni 7 giorni |
| `DIP_COMMEND` | Commendation ricevuta, di tipo *Gentile*, *Guida* o *Paziente* | messaggio `CMD` (§12) | 50 | ⛔ Vedi regole sotto |
| `DIP_EVENT_ATTEND` | Check-in a un Prestige Event (RP, social) | §7.8 | 80 | Ripetibile. Requisiti di eleggibilità dell'evento (durata minima, partecipanti) |
| `DIP_RP_EVENT` | Check-in a un Prestige Event marcato *RP* (solo realm RP/RP-PvP) | §7.8 | +40 bonus | Idem |
| `DIP_GUILD_WELCOME` | 🟡 Primo gruppo con un nuovo membro di gilda entrato da < 7 giorni | roster + gruppo | 40 | Una tantum per membro |

**Regole delle Commendations (🟡):**

- Si possono dare solo a chi ha condiviso con te un gruppo per ≥ 15 minuti **e** almeno un evento completato (quest, boss, BG) nelle ultime 24 h.
- Ogni giocatore ne dà al massimo **5 a settimana**, **1 per destinatario ogni 7 giorni**.
- Chi dà deve essere di livello ≥ 20, con profilo registrato da ≥ 7 giorni.
- Tipi: Diplomat (*Gentile*, *Guida*, *Paziente*) e Steward (*Organizzatore*, *Leader*).
- Chi riceve ottiene PP pieni dalle prime 10 commendations della settimana; oltre, valgono il 25%.
- **Anti-collusione:** dallo stesso donatore, dopo 5 commendations a vita il valore scende al 10%.

### 7.6 ⚒️ Artisan

| ruleId | Attività | Sorgente | Punti | Tipo |
| --- | --- | --- | --- | --- |
| `ART_SKILL` | Punto di skill guadagnato in una professione | `GetProfessions` / `GetProfessionInfo` (diff) | 5 (primarie), 3 (secondarie) | Una tantum per punto (lo skill è monotono) |
| `ART_SKILL_MAX` | Professione al massimo | derivato | 1 500 | Una tantum per professione |
| `ART_RECIPE` | Nuova ricetta appresa | scansione all'apertura della trade skill (diff) | `10 + reqSkill / 10` | Una tantum per ricetta |
| `ART_RECIPE_RARE` | Ricetta rara (drop, reputazione: flag del ruleset) | idem | ×5 | Una tantum |
| `ART_FIRST_CRAFT` | Primo craft di una ricetta | `UNIT_SPELLCAST_SUCCEEDED("player")` + mapping spell→recipe | 20 | Una tantum per ricetta |
| `ART_CRAFT` | Craft ripetuto | idem | 2 | ⛔ **Limitato**: DR (§8.2), cap 100/giorno |
| `ART_CRAFT_FOR_OTHER` | Oggetto craftato da te consegnato in trade a un altro giocatore | trade + item crafted di recente | 25 | ⛔ Max 1 per partner al giorno, cap 250/giorno. Regola anti-alt (§8.5) |

### 7.7 💰 Merchant

Non si premia il volume d'oro. Si premiano **varietà, controparti distinte e continuità**.

| ruleId | Attività | Sorgente | Punti | Tipo / anti-abuso |
| --- | --- | --- | --- | --- |
| `MER_AH_SALE` | Asta venduta | mail invoice (`GetInboxInvoiceInfo`) 🔍 | `5 + 10 × log10(1 + prezzo_in_oro)` | ⛔ Cap 300/giorno. Valore pieno solo per il primo acquisto di ogni acquirente distinto nel giorno. Niente punti se l'acquirente è un alt (§8.5) |
| `MER_AH_BUYER` | Nuovo acquirente distinto nella settimana | invoice (nome buyer) | 10 | ⛔ Cap 200/settimana |
| `MER_TRADE` | Trade completato con scambio bilaterale (oggetto ↔ oro o oggetto) | `TRADE_*` events | 15 | ⛔ Max 2 per partner al giorno, cap 150/giorno. **Zero punti tra alt** (§8.5) |
| `MER_ITEM_VARIETY` | Primo oggetto *diverso* venduto (itemID mai venduto) | invoice | 8 | Una tantum per itemID |
| `MER_STREAK` | Settimana con ≥ 10 vendite in ≥ 4 giorni diversi | derivato | 200 | Una volta a settimana |
| `MER_CONTRACT` | Prestige Contract completato (§7.10) | protocollo | 100 | Max 3 al giorno |

✅ Il commercio tra personaggi dello stesso account **non dà punti** (§8.5). Scala log, cap e "acquirenti distinti" limitano anche gli scambi tra amici compiacenti.

### 7.8 🏛️ Steward

| ruleId | Attività | Sorgente | Punti | Tipo / anti-abuso |
| --- | --- | --- | --- | --- |
| `STE_EVENT_HOST` | Organizzare un Prestige Event concluso con ≥ 5 partecipanti distinti con check-in | protocollo `EVT` | 20 × partecipanti (max 25 conteggiati) | Ripetibile. Requisiti di eleggibilità (§7.8); i partecipanti alt dell'organizzatore non contano |
| `STE_EVENT_SERIES` | 4 eventi validi in 4 settimane diverse | derivato | 1 000 | Ripetibile, una volta ogni 4 settimane |
| `STE_RECRUIT` | Nuovo membro invitato da te (`GuildInvite` hook) e ancora in gilda dopo 14 giorni | roster | 150 | Ripetibile. Gli alt non contano |
| `STE_GUILD_ROLE` | Essere GM o officer di una gilda con ≥ 20 membri attivi (online almeno una volta in 7 giorni) | `GetGuildInfo`, roster | 100 a settimana | Una volta a settimana |
| `STE_COMMEND` | Commendation ricevuta di tipo *Organizzatore* o *Leader* | protocollo | 50 | Regole come in §7.5 |
| `STE_GROUP_LEAD` | Leader di un gruppo che completa un'istanza o vince un BG | `UnitIsGroupLeader` all'evento | 30 | Ripetibile, senza limiti |

**Prestige Events (🟡):**

1. L'organizzatore crea un evento dal pannello: nome, tipo (Social/RP/PvP/PvE/Guild), luogo e orario. L'evento viene annunciato su `GUILD` e sul canale di discovery.
2. All'avvio, gli utenti entro circa 40 yard dall'organizzatore (stessa sub-zona, conferma reciproca via whisper) fanno **check-in** con un clic.
3. A fine evento (min 20 min, max 4 h) l'organizzatore chiude l'evento. Ogni partecipante conserva l'attestazione `EVT_ATTEND` firmata dal mittente.

### 7.9 Backfill alla prima installazione (✅)

Al primo avvio su un personaggio già avanzato si importa ciò che è **interrogabile dal server**: quest completate, reputazioni, skill e ricette, flight path, esplorazione, HK lifetime e Legacy.

- Gli eventi importati entrano nel ledger come `BACKFILL` al **100% dei PP**: chi installa tardi non è penalizzato su ciò che il server può confermare. Il trust level è `Corroborated` (tl = 2). Non generano celebrazioni individuali: c'è un'unica celebrazione "Benvenuto in Azeroth Prestige" con il rank di partenza.
- Restano esclusi dal backfill boss kill, eventi sociali e commerciali (non interrogabili).

### 7.10 Prestige Contracts (🟡, fase 3)

Una bacheca P2P di richieste di craft:

1. Il buyer pubblica una richiesta (item, materiali forniti sì/no, compenso).
2. Un crafter la accetta.
3. Il contratto è completo quando un trade consegna l'item richiesto e il buyer lo attesta.
4. Punti: Merchant al buyer e al crafter, `ART_CRAFT_FOR_OTHER` al crafter.

---

## 8. Regole di scoring trasversali

### 8.1 Calcolo deterministico

```lua
pp = Ruleset[rv].rules[ruleId].points(ctx)      -- funzione pura
if Boost.voids(event) then pp = 0 end            -- anti-boost (§8.6)
pp = pp / LowLevelDivisor(ctx.pl, ctx.l)          -- contenuto 10+ livelli sotto (§8.7)
pp = pp * DR(ruleKey, window)                    -- diminishing returns
pp = min(pp, CapRemaining(ruleId, day/week))     -- cap
pp = floor(pp)
```

- `rv` è la versione del ruleset **in vigore al momento dell'evento**, salvata nell'evento. Ricalcolare con lo stesso `rv` dà sempre lo stesso risultato.
- Un nuovo ruleset vale solo per gli eventi successivi.

### 8.2 Limiti e diminishing returns (DR) — solo per le azioni farmabili (✅)

**Regola generale:** dungeon, raid, boss, battleground, killing blow, HK, quest daily e attività di gruppo sono **ripetibili senza limiti**, a punti pieni ogni volta.

DR e cap (segnati ⛔ nel catalogo) valgono **solo** per queste famiglie:

| Famiglia | Regole |
| --- | --- |
| Duelli | `VAN_DUEL_*` |
| Craft ripetuti | `ART_CRAFT`, `ART_CRAFT_FOR_OTHER` |
| Trade e vendite | `MER_*` |
| Commendations e attestazioni personali | `DIP_COMMEND`, `DIP_MENTOR`, `STE_COMMEND` |

Restano invece sempre attivi i **requisiti di eleggibilità**: non AFK, presenza minima all'encounter, durata minima degli eventi, regola anti-alt. Non sono limiti alla ripetizione, ma condizioni perché l'attività sia reale.

Per le famiglie limitate, ripetere la **stessa chiave** (es. `VAN_DUEL_WIN:avversario`) nella stessa finestra:

| Occorrenza nella finestra | Moltiplicatore |
| --- | --- |
| 1ª | 100% |
| 2ª | 75% |
| 3ª | 50% |
| 4ª | 25% |
| 5ª e oltre | 10% (floor) |

La finestra di default è il giorno (reset alle 00:00 server time). Le finestre sono definite per regola nel ruleset.

### 8.3 Group credit (dalla wiki)

- Ogni partecipante eleggibile riceve **i punti pieni**: non si dividono, non vanno al killer o al top DPS.
- Eleggibilità: nel gruppo, nella stessa istanza o area, non AFK, presente per ≥ 50% della durata dell'encounter (`ENCOUNTER_START` → `ENCOUNTER_END`).
- Si accetta il limite dichiarato dalla wiki: gruppi più grandi o contenuti più facili possono rendere più velocemente.

### 8.4 Idempotenza

- `eventId = hash(charKey, ruleId, contextKey, serverTimeBucket)`.
- Il bucket è di 60 s. Per le una tantum il `contextKey` basta da solo, senza componente temporale.
- Un evento con `eventId` già presente viene scartato: questo copre reconnect, `/reload` e doppia ricezione.

### 8.5 Regola anti-alt (✅)

**Nessuna interazione tra personaggi dello stesso account genera punti**: trade, vendite AH, duelli, aiuto ai nuovi, mentorship, Commendations, attestazioni, check-in a eventi, reclutamento.

**Rilevamento:**

1. **Locale (principale).** I SavedVariables di account (`AzerothPrestigeDB`) sono condivisi da tutti i personaggi dello stesso account WoW sullo stesso PC. L'addon registra ogni proprio personaggio in `myChars` al login. Ogni regola con una controparte scarta l'evento se la controparte è in `myChars`.
2. **Alt collegati pubblicamente (opt-in, §6.1).** Se un profilo pubblica `alts`, tutti i peer applicano la regola anche ai suoi eventi ricalcolati, e un'eventuale violazione rende l'evento `Flagged`.
3. **Testimoni.** Un alt non può attestare eventi del proprio account: anche le attestazioni tra personaggi in `myChars` vengono scartate.

> Limite dichiarato (anti-alt): senza server non si può riconoscere un secondo account WoW (o un altro PC) della stessa persona. Un client modificato può anche ignorare la regola. In questi casi restano a difendere il sistema i limiti delle famiglie farmabili (§8.2), il peso ridotto dei testimoni ricorrenti (§11.3) e i controlli di plausibilità (§11.5).

### 8.6 Regola anti-boost (✅)

**Principio:** chi viene "portato" da un giocatore molto più forte non guadagna punti. Se un giocatore di **almeno 10 livelli più alto** è nel tuo gruppo, oppure ti aiuta da fuori gruppo, **tutti i punti che guadagni in quel momento valgono 0**, in **tutte le 8 categorie**.

**Chi aiuta (✅):** la regola anti-boost colpisce solo chi riceve l'aiuto. Il giocatore più alto prende i punti Diplomat di `DIP_HELP_LOW` e i punti del contenuto **depotenziati** secondo §8.7, perché quel contenuto è molto sotto il suo livello.

#### 8.6.1 Stato BOOSTED

Il modulo `Domain/Boost.lua` mantiene uno stato `BOOSTED` per il giocatore. Ogni evento creato mentre lo stato è attivo, o il cui intervallo di attività lo ha attraversato, è registrato con `pp = 0` e motivo `BOOST`.

| Trigger | Rilevamento | Durata dello stato |
| --- | --- | --- |
| **G — In gruppo** | Un membro del gruppo o raid ha `UnitLevel ≥ livello_giocatore + 10`. Vale ovunque si trovi il membro, anche lontano o offline. Controllo a `GROUP_ROSTER_UPDATE`, `UNIT_LEVEL`, `PLAYER_LEVEL_UP` | Finché quel membro resta nel gruppo |
| **A1 — Assist in combattimento** | Giocatore **fuori gruppo** di livello +10, in combattimento, che bersaglia il tuo bersaglio o te: scansione dei token `nameplateN` con `UnitIsUnit("nameplateNtarget", "target")` o `"player"` | Fino a 60 s dopo l'ultimo segnale (🟡) |
| **A2 — Tanking per te** | Il tuo bersaglio (mob o nemico) sta attaccando un giocatore fuori gruppo di livello +10: `UnitIsUnit("targettarget", unit)` | Fino a 60 s dopo l'ultimo segnale |
| **A3 — Buff e cure in azione** | Un'aura su di te applicata **mentre sei in combattimento** (o nei 60 s prima) da un giocatore fuori gruppo di livello +10: `UNIT_AURA` + `sourceUnit` dell'aura 🔍 | Fino a 60 s dopo l'applicazione |
| **A4 — Trade** | Trade completato in cui ricevi oggetti o oro da un giocatore di livello +10 | Solo l'evento di quel trade (es. `MER_TRADE`) |

Note sul rilevamento del livello:

- Per un'unità ostile molto più alta, `UnitLevel` restituisce `-1` (livello "??"). `-1` viene trattato come "+10" 🔍 V19.
- Con il level cap a 60, un giocatore di livello ≥ 51 non può avere nessuno 10 livelli sopra: per lui la regola è di fatto inattiva.

Un buff ricevuto **fuori dal combattimento** (es. un buff di passaggio in città) **non** attiva lo stato. Questo evita di bloccare i punti per la lunga durata del buff.

#### 8.6.2 Applicazione per tipo di evento

| Tipo di evento | Quando è annullato |
| --- | --- |
| Boss encounter (`DEL_BOSS*`, `DEL_FIRST_KILL`) | BOOSTED in un qualsiasi momento tra `ENCOUNTER_START` ed `ENCOUNTER_END` |
| Clear e full clear di un'istanza | Almeno un boss della run è stato annullato per boost |
| Quest (`ADV_QUEST*`, `ADV_STORY`) | BOOSTED al turn-in, **oppure** un obiettivo della quest è avanzato mentre eri BOOSTED. Gli avanzamenti si tracciano con `QUEST_LOG_UPDATE` / `UNIT_QUEST_LOG_CHANGED` e un flag per questID |
| Reputazione (`ADV_REP_STANDING`) | Lo standing è stato raggiunto con guadagni di reputazione avvenuti mentre eri BOOSTED |
| PvP (`VAN_*`) | BOOSTED alla fine del match, all'HK o alla fine del duello |
| Esplorazione (`PAT_*`) | BOOSTED al momento della scoperta, del flight path o del segreto |
| Artisan, Merchant, Diplomat, Steward | BOOSTED al momento dell'evento (craft, vendita, check-in, Commendation ricevuta, ecc.) |

**Eventi una tantum annullati:** restano **consumati**. Il gioco non permette di riscoprire una zona o di riconsegnare una quest, quindi la prima volta fatta con un boost non si recupera. Per questo la UI avvisa in modo molto visibile (§14.8).

#### 8.6.3 Verificabilità

- Il trigger **G** è **ricalcolabile dai peer**: ogni evento salva nel contesto il livello del giocatore e il livello massimo del gruppo (`c.pl`, `c.gmx`). Un profilo con eventi a punti pieni che violano G viene marcato `Flagged`.
- I trigger **A1–A4** sono euristici e locali: il client registra l'esito, i peer non possono verificarlo.

> Limite dichiarato: senza combat log (bloccato dalle restrizioni Midnight) non si vedono le cure dirette senza aura e gli aiuti da giocatori fuori dal raggio delle nameplate. La regola blocca in modo affidabile il boost in gruppo, che è il caso più comune, e la maggior parte degli aiuti visibili da fuori gruppo.
> Il backfill (§7.9) importa dati di prima dell'installazione: lì non si può sapere se ci sia stato boost. Si accetta il limite.

### 8.7 Contenuto di livello molto inferiore (✅)

Se il contenuto è **10 o più livelli sotto** il giocatore, i punti delle regole basate sul livello del contenuto `L` si dividono per la differenza di livello:

```
diff = livello_giocatore − L
se diff ≥ 10:  pp = pp_normali / diff
altrimenti:    pp = pp_normali
```

- Vale per tutte le regole il cui valore dipende da `L`: boss, clear e first kill di Delver; quest e quest elite di Adventurer.
- Vale **sempre**, non solo quando si aiuta qualcuno: anche chi rifà da solo contenuti molto bassi prende punti ridotti.
- Il livello del giocatore è quello al momento dell'evento (`c.pl`). È salvato nel contesto, quindi la regola è ricalcolabile dai peer.

| Esempio | Calcolo | PP |
| --- | --- | ---: |
| Livello 60 uccide un boss di livello 58 | diff 2 < 10 → pieni: 58 × 1 | 58 |
| Livello 60 uccide un boss di livello 45 | 45 × 1 / 15 | 3 |
| Livello 60 consegna una quest di livello 30 | max(10, 30 × 1.5) / 30 = 45 / 30 | 1 |
| Livello 60 fa il primo kill di un boss di livello 40 | 40 × 3 / 20 | 6 |

I punti si arrotondano per difetto (§8.1). Il valore minimo può quindi essere 0.

---

## 9. Architettura dell'addon

### 9.1 Vista d'insieme

```
┌──────────────────────────── WoW Forever client ────────────────────────────┐
│                                                                            │
│  Game events ──► Trackers (8) ──► EventBus ──► Ledger ──► Scoring/Ranks    │
│                                     │            │            │            │
│                                     ▼            ▼            ▼            │
│                              Attestation    ProfileStore  Celebrations     │
│                                     │            ▲            │            │
│                                     ▼            │            ▼            │
│                Network (Comm + Throttle + Queue) ┘          UI layer       │
│                     ▲   │                         (Main window, Badges,    │
│   CHAT_MSG_ADDON ───┘   └──► SendAddonMessage      Tooltip, Chat, Menu)    │
│                                                                            │
│  SavedVariables: AzerothPrestigeDB (account) · AzerothPrestigeCharDB (pg)  │
└────────────────────────────────────────────────────────────────────────────┘
          ▲                        ▲                        ▲
          └──── altri client con Azeroth Prestige (GUILD/PARTY/RAID/WHISPER/CHANNEL)
```

### 9.2 Moduli

| Modulo | Responsabilità |
| --- | --- |
| `Core` | Bootstrap, namespace, versioning, EventBus interno (pub/sub), scheduler (`C_Timer`), logging |
| `Restrictions` | Stato centralizzato: in combattimento, encounter, chat lockdown, mappa ristretta, trial. Wrapper safe per i secret values (`canaccessvalue`) |
| `Boost` | Stato BOOSTED (trigger G, A1–A4), finestre di attività, flag per quest ed encounter (§8.6) |
| `Data` | Ruleset versionati, ladder, encounter/quest/zone tables, segreti, localizzazioni |
| `Trackers/*` | Un tracker per categoria: ascolta gli eventi di gioco, costruisce i `PrestigeEvent` |
| `Ledger` | Append, idempotenza, compattazione, export del digest |
| `Scoring` | Funzioni pure: PP, DR, cap, rank da PP, GP |
| `ProfileStore` | Profili noti di altri giocatori, merge, trust level, eviction |
| `Attestation` | Richiesta e rilascio di attestazioni, verifica, registro dei testimoni |
| `Network` | Codec, chunking, throttle (ChatThrottleLib), coda in lockdown, router dei messaggi |
| `Leaderboard` | Indici ordinati per categoria, snapshot settimanali, Legend |
| `Celebrations` | Coda, blocking conditions, renderer pannello e cinematico, suoni |
| `UI/*` | Finestra principale, profilo, classifiche, impostazioni, minimap/LDB |
| `Badges/*` | Provider di badge: Nameplate, Tooltip, Chat, UnitMenu, Party/Raid frame, Target frame |
| `API` | API pubblica per altri addon (§19.2) |

### 9.3 Struttura del repository

```
azeroth-prestige/
├─ AzerothPrestige/                  # cartella distribuita
│  ├─ AzerothPrestige_Forever.toc
│  ├─ embeds.xml
│  ├─ Libs/                          # LibStub, CallbackHandler, AceAddon, AceDB, AceComm,
│  │                                 # ChatThrottleLib, LibDataBroker, LibDBIcon, (LibSerialize, LibDeflate)
│  ├─ Locales/  enUS.lua  itIT.lua ...
│  ├─ Core/     Init.lua EventBus.lua Scheduler.lua Log.lua Restrictions.lua
│  ├─ Data/     Ladder.lua Ruleset_v1.lua Encounters.lua Quests.lua Zones.lua Secrets.lua
│  ├─ Domain/   Scoring.lua Ledger.lua ProfileStore.lua Attestation.lua Leaderboard.lua Boost.lua
│  ├─ Trackers/ Vanguard.lua Delver.lua Pathfinder.lua Adventurer.lua
│  │            Diplomat.lua Artisan.lua Merchant.lua Steward.lua Backfill.lua
│  ├─ Network/  Codec.lua Comm.lua Router.lua Discovery.lua Sync.lua
│  ├─ Celebrations/ Queue.lua Conditions.lua PanelView.lua CinematicView.lua Sounds.lua
│  ├─ Badges/   Provider.lua Nameplates.lua Tooltip.lua Chat.lua UnitMenu.lua GroupFrames.lua
│  ├─ UI/       MainFrame.lua ProfileView.lua LeaderboardView.lua HallOfPrestige.lua
│  │            HistoryView.lua Settings.lua Minimap.lua
│  ├─ API/      Public.lua
│  └─ Media/    Badges/*.tga  Categories/*.tga  Frames/*.tga  Sounds/*.ogg  Fonts/
├─ tests/                            # busted + mock WoW API
├─ tools/                            # generatori di ruleset/tabelle, packager
├─ docs/
│  ├─ SPECIFICHE-TECNICHE.md
│  └─ m0-api-report.md
└─ .pkgmeta                          # BigWigs packager (CurseForge/Wago)
```

### 9.4 TOC

```toc
## Interface: 16001
## Title: Azeroth Prestige
## Notes: Prestige ranks, badges & leaderboards for WoW Forever
## Author: Finland
## Version: @project-version@
## SavedVariables: AzerothPrestigeDB
## SavedVariablesPerCharacter: AzerothPrestigeCharDB
## IconTexture: Interface\AddOns\AzerothPrestige\Media\Icon
## Category: Achievements
## X-License: All Rights Reserved
## X-Curse-Project-ID: <tbd>
## X-Wago-ID: <tbd>

embeds.xml
Locales\Locales.xml
Core\Core.xml
Data\Data.xml
Domain\Domain.xml
Network\Network.xml
Trackers\Trackers.xml
Celebrations\Celebrations.xml
Badges\Badges.xml
UI\UI.xml
API\Public.lua
```

### 9.5 Librerie

| Libreria | Uso | Nota |
| --- | --- | --- |
| Ace3 (AceAddon, AceDB, AceComm, AceEvent, AceConsole) | Struttura, DB con profili, messaggi multi-parte | Standard de facto |
| ChatThrottleLib | Rispetto del throttle server | Raccomandata dalla wiki |
| `C_EncodingUtil` **oppure** LibSerialize + LibDeflate | Serializzazione e compressione | 🔍 V14: preferire le API native se presenti |
| LibDataBroker + LibDBIcon | Pulsante minimappa e broker | — |
| **Nessuna** libreria per le nameplate | Si aggancia alla nameplate di base | Gli adapter per Plater e simili stanno in §19.1 |

### 9.6 Regole di codice

- Namespace privato via `local ADDON, ns = ...`. Unica globale: `AzerothPrestige` (API pubblica).
- Niente codice offuscato (policy Blizzard).
- **Taint safety:** non modificare frame protetti in combattimento. Le operazioni sui frame di gruppo vanno rinviate a `PLAYER_REGEN_ENABLED`.
- Ogni accesso a dati potenzialmente secret passa da `Restrictions.SafeGet(fn, ...)`, che controlla con `issecretvalue` e restituisce `nil` invece di sollevare un errore.
- Funzioni di dominio (Scoring, Ledger, Codec, Leaderboard) **pure**, senza API WoW, testabili fuori dal gioco.

---

## 10. Modello dati e SavedVariables

### 10.1 `AzerothPrestigeCharDB` (per personaggio)

```lua
AzerothPrestigeCharDB = {
  schema = 1,
  charKey = "Thrall-Forever-EU",
  guid = "Player-xxxx-xxxxxxxx",
  createdAt = 1764115200,                 -- prima registrazione
  rv = 1,                                  -- ultimo ruleset usato
  points  = { VAN=0, DEL=0, PAT=0, ADV=0, DIP=0, ART=0, MER=0, STE=0 },
  peak    = { VAN=1, ... , GP=1 },         -- indice step ladder (mai decrescente)
  ledger  = {                              -- eventi recenti (≤ 30 gg), più vecchi compattati
    { id="9f3a…", t=1764200000, r="DEL_BOSS", k="enc:1234",
      c={ d=1, g=5, l=55, pl=52, gmx=54 },  -- pl = livello giocatore, gmx = livello massimo del gruppo
      pp=55, rv=1, w={"Jaina-Forever-EU"}, tl=2 },
    { id="a1c0…", t=1764203600, r="ADV_QUEST", k="q:812",
      c={ l=30, pl=28, gmx=45 }, pp=0, why="BOOST:G", rv=1, tl=1 },   -- annullato per boost
  },
  compact = { ["DEL_BOSS:enc:1234"] = { n=14, pp=520 } },   -- aggregati storici
  oneTime = { ["PAT_FLIGHT:node:23"]=true, ... },            -- set una tantum
  caps    = { day="2026-11-26", week="2026-W48", used={ VAN_HK=120 } },
  legendReigns = { },
  celebrationQueue = { },                  -- promozioni non ancora celebrate
  profileVersion = 42,                     -- monotono, ++ a ogni cambio pubblicato
  settings = { featuredCategory = "DEL", hideMyBadge = false },
}
```

### 10.2 `AzerothPrestigeDB` (account)

```lua
AzerothPrestigeDB = {
  schema = 1,
  profiles = {                              -- profili noti (altri + propri)
    ["Jaina-Forever-EU"] = {
      v = 17,                                -- profileVersion del proprietario
      seen = 1764200000,                     -- ultimo dato di prima mano
      src = 1,                               -- 1 = prima mano, 2 = seconda mano corroborata, 3 = seconda mano singola
      pts = { 1200, 5400, 300, 2200, 0, 800, 0, 150 },  -- ordine fisso categorie
      peak = { ... }, gp = 10050,
      fc = "DEL",                            -- categoria in evidenza
      vr = 0.72,                             -- verified ratio (§11.4)
      ar = { ... },                          -- apex reigns dichiarati (albo dei titoli)
      cls = 8, lvl = 60, gld = "Kirin Tor", fac = "A",   -- A / H
      alts = nil,                            -- elenco alt solo se opt-in pubblico (§6.1)
      hc = nil,                              -- Hardcore: { dead = ts, zone = "..." } (§13.5)
      relays = { ["Arthas-Forever-EU"]=17 }, -- chi ha rilanciato quale versione
      flags = 0,                             -- bit: flagged, hidden, trial
    },
  },
  myChars = { ["Thrall-Forever-EU"] = { guid = "...", firstSeen = 1764115200, publicAlt = false } },  -- regola anti-alt (§8.5)
  snapshots = {                              -- snapshot settimanali dei posti apex (§13.3)
    ["2026-W48"] = {
      VAN = { LEGEND = { "Jaina-Forever-EU", ... }, ASPECT = { ... }, ..., MASTER = { ... } },
      GP  = { ... },
    },
  },
  hallOfPrestige = {                         -- albo osservato di tutti i regni apex del realm (§13.4)
    ["Jaina-Forever-EU"] = { { cat="VAN", rank="LEGEND", start=..., finish=nil }, ... },
  },
  witnessLog = { },                          -- attestazioni rilasciate (§11.3), 90 gg
  settings = { ... },                        -- AceDB profile (UI, badge, celebrazioni, suoni)
}
```

### 10.3 Limiti di dimensione (🟡)

| Elemento | Limite | Politica |
| --- | --- | --- |
| Ledger dettagliato | 30 giorni o 5 000 eventi | Oltre, compattazione in `compact` |
| Profili noti | 20 000 | Eviction LRU con priorità: si tengono sempre i top 1 000 per categoria (tutti i candidati apex), chi compare nell'albo apex, gilda, amici e ultimi 7 giorni |
| `witnessLog` | 90 giorni | Pulizia al login |
| SavedVariables totali | < 15 MB | Monitorato con `/azp stats` |

---

## 11. Ledger, attestazioni e livelli di fiducia

### 11.1 Modello di minaccia

Senza un server, **chiunque può modificare i propri SavedVariables** e il codice dell'addon è pubblico: checksum o "firme" con chiavi incluse nel codice sono inutili. Le uniche garanzie forti sono due:

1. **Il nome del mittente di `CHAT_MSG_ADDON` lo garantisce il server.** Un messaggio arrivato direttamente da "Jaina" è davvero partito dal client di Jaina.
2. **Alcuni dati di gioco sono interrogabili e autorevoli**: livello e classe di un'unità visibile, gilda, a volte statistiche ispezionabili 🔍.

### 11.2 Livelli di fiducia di un evento

| tl | Nome | Condizione |
| --- | --- | --- |
| 3 | **Witnessed** | ≥ 1 attestazione ricevuta **direttamente** da un testimone ≠ proprietario, presente all'evento |
| 2 | **Corroborated** | Dato autorevole lato server, ad esempio delta HK, skill o quest completate (verificabile dal proprietario, plausibile per gli altri) |
| 1 | **Self-reported** | Nessuna prova esterna (esplorazione in solitaria, craft) |
| 0 | **Flagged** | Fallisce un controllo di plausibilità (§11.5) |

### 11.3 Attestazioni

1. Si verifica un evento di gruppo, ad esempio `ENCOUNTER_END` con success.
2. Ogni client del gruppo crea il proprio evento **in autonomia** (stesso `contextKey`).
3. Usciti dal lockdown, i client si scambiano su `PARTY`/`RAID` un messaggio `ATT`: `{contextKey, eventHash, t}`.
4. Ogni client salva le attestazioni ricevute dagli altri (`w = {names}`) e scrive nel proprio `witnessLog` quelle **rilasciate**.
5. Un terzo che vuole verificare può chiedere al testimone, via whisper (`ATQ`), "hai attestato `contextKey` per X?". La risposta arriva dal testimone in persona, quindi non è falsificabile da X.

> Limite dichiarato: due account controllati dalla stessa persona possono attestarsi a vicenda. Mitigazione: un testimone conta al massimo per il 20% degli eventi witnessed di un profilo, e i testimoni che compaiono solo con un profilo vengono pesati meno nel `vr`.

### 11.4 Verified ratio

```
vr = PP(tl ≥ 2) / PP_totali
```

- È mostrato nel profilo come percentuale e icona (🛡️ ≥ 70%, ◐ 40–70%, ○ < 40%).
- **Requisito apex** (tutti e 7): `vr ≥ 0.6` nella categoria.
- I rank a soglia **non** richiedono un `vr` minimo, per non penalizzare chi gioca da solo.

### 11.5 Controlli di plausibilità

Ogni peer li esegue alla ricezione di un profilo:

- PP per categoria ≤ massimo teorico dato il tempo trascorso da `createdAt`: tasso massimo per categoria, configurato nel ruleset.
- Contatori una tantum ≤ totale esistente (flight path, zone, ricette, quest).
- `profileVersion` mai decrescente. PP mai decrescenti a parità di `rv`.
- Salti improvvisi > X PP tra due versioni consecutive senza eventi corrispondenti nel digest.

Un profilo che fallisce viene marcato `flagged`: compare in classifica con un'icona ⚠ ed è escluso dagli apex. Il dato non viene cancellato.

---

## 12. Protocollo di rete peer-to-peer

### 12.1 Trasporto

- Prefisso: `AZPRES` (registrato con `C_ChatInfo.RegisterAddonMessagePrefix`).
- Envelope: `<ver:1><type:3><seq:2><payload>`, payload serializzato, compresso e codificato per il canale. Messaggi > 255 byte divisi con AceComm.
- Tutte le uscite passano da **ChatThrottleLib**, con priorità `ALERT` (attestazioni), `NORMAL` (profili) e `BULK` (sync).
- **Coda di lockdown:** se `InChatMessagingLockdown()` è vero, o l'invio restituisce `AddOnMessageLockdown`, il messaggio resta in coda (TTL 30 min) e viene ritentato a ogni cambio di stato.
- Account trial: invio disabilitato, ricezione attiva.

### 12.2 Tipi di messaggio

| Tipo | Canale | Contenuto | Frequenza |
| --- | --- | --- | --- |
| `HEL` (beacon) | GUILD, CHANNEL, PARTY/RAID | `v`, ruleset, `gp`, `peak[9]`, `fc`, `vr` e un hash del profilo (~60 byte) | Al login, ogni 15 min ± jitter, a ogni promozione |
| `PRQ` | WHISPER | Richiesta del profilo completo (`v` noto) | Su richiesta, max 1 ogni 2 s |
| `PRF` | WHISPER | Profilo completo + digest del ledger (chunked) | Risposta |
| `ATT` | PARTY/RAID/INSTANCE_CHAT | Attestazione evento | Dopo eventi di gruppo |
| `ATQ` / `ATA` | WHISPER | Query e risposta di verifica di un'attestazione | Su richiesta |
| `RLY` | CHANNEL, GUILD | Rilancio di riepiloghi di profili **offline** (seconda mano) | Max 20 profili ogni 10 min |
| `LBD` | CHANNEL, GUILD | Digest dei posti apex: un hash per ogni coppia categoria/apex (63 hash). L'elenco completo dei nomi di una fascia si scarica via WHISPER solo se il proprio hash non coincide con quello di maggioranza | Dopo il reset settimanale |
| `CMD` | WHISPER | Commendation | Su azione utente |
| `EVT` | GUILD, CHANNEL, WHISPER | Ciclo di vita di un Prestige Event (create, check-in, close) | Su azione utente |
| `CTR` | CHANNEL, WHISPER | Prestige Contracts (fase 3) | Su azione utente |

### 12.3 Discovery su un mega-realm

- **Canale custom nascosto**, ad esempio `AzPrestige1`: unito con `JoinTemporaryChannel` e rimosso dai chat frame. È il mezzo per raggiungere gli utenti fuori da gilda e gruppo. 🔍 V4: limiti del canale, cross-faction e numero di membri.
- **Budget di traffico:** con 10 000 utenti attivi e beacon ogni 15 min arrivano circa 11 msg/s, gestibili. Se il canale supera una soglia (🟡 > 20 msg/s osservati) il beacon passa a 30 min, e poi a sharding su più canali (`AzPrestige1..4` per hash del nome).
- **Lazy fetch:** se nameplate o tooltip mostrano un giocatore il cui hash è più recente della cache, parte un `PRQ`. Limiti: 1 ogni 2 s, max 30 al minuto, negative cache di 10 min.

### 12.4 Merge dei profili

1. Un dato di prima mano (mittente = proprietario) con `v` maggiore sostituisce sempre quello in cache.
2. Un dato di seconda mano (`RLY`) si accetta solo se:
   - non esiste un dato di prima mano con `v` ≥;
   - e almeno **2 relay distinti** riportano la stessa `v` e lo stesso hash (`src = 2`); altrimenti resta `src = 3` (mostrato, ma escluso dagli apex).
3. Un dato di seconda mano non può mai abbassare PP o peak rispetto a quanto già noto.

### 12.5 Persistenza dei profili di chi non usa più l'addon (✅ 5.8 / 5.21-C)

- Il profilo vive nelle cache degli altri e circola via `RLY`. Ogni client rilancia a rotazione i profili offline di valore: top della classifica, detentori ed ex detentori di apex, membri di gilda.
- Limite dichiarato: se **nessun** client conserva un profilo, quel profilo si perde. Con la politica di eviction (§10.3) i profili rilevanti, cioè top e albo apex, sono praticamente sempre conservati.

---

## 13. Classifiche e Hall of Prestige

### 13.1 Viste (✅ 9 classifiche: Global + 8 categorie)

| Filtro | Valori |
| --- | --- |
| Categoria | Global, VAN, DEL, PAT, ADV, DIP, ART, MER, STE |
| Ambito | Realm (default), Gilda, Amici, Gruppo attuale |
| Fazione (✅) | Tutte (default), Alliance, Horde. **Su Vanguard il default è la propria fazione** |
| Hardcore | Vivi / Caduti / Tutti (solo sui realm Hardcore) |
| Classe / Razza | Tutte o una specifica |
| Fiducia | Tutti / solo ≥ Corroborated / nascondi flagged |
| Stato | Tutti / attivi negli ultimi 30 giorni |

Colonne: Posizione, Badge + Rank, Nome, Classe, Gilda, PP, `vr`, Ultimo visto, Δ settimana.

### 13.2 Trasparenza

L'header di ogni classifica mostra "Profili conosciuti: 4 812 · Ultimo sync: 2 min fa". La posizione del giocatore è sempre visibile e fissata in fondo alla lista.

### 13.3 Assegnazione settimanale dei posti apex

1. A ogni reset settimanale (`C_DateAndTime.GetSecondsUntilWeeklyReset`), o al primo login successivo, il client esegue per ogni categoria e per il Global l'**assegnazione a cascata** di §6.3 sui profili eleggibili.
2. Pubblica il digest `LBD` e riceve quelli degli altri. Lo snapshot ufficiale *locale* è il **consenso di maggioranza** sugli hash ricevuti nelle prime 24 h. In mancanza di digest esterni vale il proprio.
3. Il confronto con lo snapshot precedente aggiorna l'albo, per ogni personaggio:

| Cambio rispetto alla settimana prima | Effetto sull'albo |
| --- | --- |
| Entra in un apex | Nuovo regno, `start` = data del reset |
| Sale di apex (es. Keeper → Aspect) | Chiude il regno Keeper, apre il regno Aspect |
| Scende di apex (spodestato) | Chiude il regno superiore, apre quello inferiore |
| Esce da tutti gli apex | Chiude il regno, torna al tier a soglia |
| Rientra in un apex già avuto | Nuovo regno con nuove date; i precedenti restano |

4. Notifiche al proprietario:
   - ingresso o salita in un apex → **celebrazione cinematica** (§15);
   - spodestamento → **toast discreto**, senza celebrazione: "Sei sceso da Aspect a Keeper in Vanguard. Il titolo Aspect resta nel tuo albo."

> Limite dichiarato: senza un'autorità centrale, client diversi possono avere snapshot leggermente diversi. Il consenso via `LBD` riduce le divergenze, ma non le elimina.

### 13.4 Hall of Prestige

Tab dedicata (sostituisce la "Hall of Legends" di v0.1) con:

- I **detentori attuali** di ogni apex, per categoria e per il Global, con il **Legend of Azeroth** in evidenza. Per ogni fascia si vede il numero di posti occupati (es. "Aspect 37/100").
- L'**albo storico**: ogni personaggio che ha detenuto un apex, con tutti i regni (titolo, date di inizio e fine) e la durata cumulata per titolo.
- Ricerca per nome. Record: "regno Legend più lungo", "più regni", "più categorie con un apex".

Le classifiche e gli apex sono **misti tra le fazioni** (✅): i 700 posti sono unici per realm e il filtro di fazione è solo una vista.

### 13.5 Realm Hardcore: memoriale (✅)

- Le classifiche sono già separate per realm, quindi Hardcore ha classifiche proprie.
- Quando un personaggio Hardcore muore, il suo client pubblica `hc.dead` (data, zona). Rilevamento: `PLAYER_DEAD` su un realm Hardcore 🔍 V17.
- Il profilo resta in classifica con il sigillo **"Caduto"** e la data di morte. I punti restano **congelati**: nessun evento successivo viene accettato.
- Un personaggio caduto conserva nell'albo tutti i titoli apex già ottenuti. Al reset successivo perde l'eventuale posto apex (il regno si chiude con la data del reset) e non può iniziarne di nuovi.
- **Hall of the Fallen**: tab che raccoglie i caduti con rank ≥ Gold in almeno una categoria, ordinati per GP. Mostra epitaffio automatico (rank migliore, data, zona).

---

## 14. UI/UX

### 14.1 Finestra principale (`/prestige`)

Finestra trascinabile (~820×560), stile coerente con la UI Midnight/Forever. Tab:

1. **Profilo**: il proprio, o quello del giocatore selezionato.
2. **Classifiche**
3. **Hall of Prestige**
4. **Cronologia**: ledger leggibile, filtrabile per categoria, con `ruleId` spiegato e PP.
5. **Eventi**: Prestige Events e Commendations (dare e ricevute).
6. **Impostazioni**: anche nel pannello di sistema via `Settings.RegisterCanvasLayoutCategory`.

Accesso anche da pulsante minimappa (LibDBIcon), broker LDB e menu contestuale del giocatore.

### 14.2 Profilo a 3 livelli (🟡, proposto in 5.10)

1. **Overview**: nome, livello, classe, razza, gilda; badge Global grande con rank e PP; griglia 8 categorie (badge, rank, PP, barra verso la divisione successiva); `vr`; apex attuali e sigilli storici.
2. **Category Details** (clic su una categoria): rank, divisione, PP, PP mancanti, data di raggiungimento di ogni tier (timeline), posizione in classifica, PP mancanti per la soglia apex successiva e posizione nella sua fascia.
2b. **Albo dei titoli**: tutti i regni apex del personaggio (titolo, categoria, data di inizio, data di fine o "in corso", durata), ordinati dal titolo più alto.
3. **Statistics**: contatori per regola (boss uccisi, flight path, ricette…), migliori settimane, distribuzione delle attività.

Per gli altri giocatori i livelli 1 e 2 sono sempre disponibili. Il livello 3 è disponibile se si è ricevuto il loro digest `PRF`.

### 14.3 Badge: cosa mostrare (✅ 5.22)

- **Default (opzione B):** badge **Global** + badge della **categoria in evidenza** del proprietario. La categoria in evidenza è il rank più alto, oppure quella scelta dal proprietario in `featuredCategory`.
- **Override del viewer:** "Solo Global" · "Global + evidenza" · "Solo una categoria specifica (per tutti)" · "Nessun badge".
- Dimensione, posizione (sinistra o destra del nome, sopra) e opacità sono configurabili.

### 14.4 Superfici dei badge

| Superficie | Implementazione | Note |
| --- | --- | --- |
| **Nameplate** | `NAME_PLATE_UNIT_ADDED/REMOVED` → `C_NamePlate.GetNamePlateForUnit(unit)`; se `plate:IsForbidden()` si salta; texture figlia ancorata alla plate | Nemici e amici fuori dalle istanze. **In istanza le amiche sono forbidden** 🔍 V3 |
| **Tooltip unità** | `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, fn)` | Riga "Prestige: [badge] Gold II (Global) · Delver Diamond IV" e una riga che spiega cosa misura |
| **Target / Focus frame** | Overlay sul ritratto | Funziona anche in istanza |
| **Frame party/raid** | Overlay sui `CompactUnitFrame`, creato e posizionato **fuori dal combattimento** | Fallback principale in istanza |
| **Chat** | Message event filter: anteponi `\|T<badge>:14\|t` al nome del mittente | Disattivato automaticamente se il nome del mittente è secret (chat lockdown) 🔍 V12 |
| **Menu unità** | `Menu.ModifyMenu("MENU_UNIT_PLAYER", …)` → "Apri profilo Prestige", "Dai una Commendation" | — |
| **Inspect / Who / Friends / Guild** | 🟡 fase 2: badge nelle liste gilda e amici | — |

Lookup: `charKey` → `ProfileStore`. Se il dato è assente non si mostra nulla. Se è vecchio, parte un lazy fetch (§12.3).

### 14.5 Grafica

- I **29 badge** (22 tier, 7 apex incluso Legend), più i **sigilli storici** "Ex-<apex>" (7 piccoli overlay), sono texture originali 64×64 (`.tga`, potenza di 2), con una versione da 16 px per la chat. Le emoji del brief sono solo riferimento: i font WoW non le rendono.
- **8 emblemi** di categoria + 1 Global. Il badge composto è emblema di categoria + cornice del tier.
- Le divisioni IV–I si rendono con 1–4 pip sotto il badge.
- Apex: cornice animata con flipbook leggero. Legend: glow pulsante.
- Tutta la grafica deve essere **originale**: niente asset Blizzard ridistribuiti, niente immagini prese dal web.

### 14.7 Pipeline degli asset e art bible (✅)

Gli asset si producono in due fasi:

1. **Placeholder (M1–M4).** Generati da `tools/gen_placeholders`: forma base (scudo per i tier, stella per gli apex) riempita con il colore del tier, iniziale del tier al centro, pip per le divisioni. Bastano per sviluppare e testare tutta la UI.
2. **Asset definitivi (da M4).** Generati con strumenti AI seguendo l'art bible qui sotto, poi **rifiniti a mano**: pulizia dei bordi, palette fissata, leggibilità a 16 px, esportazione nei formati richiesti.

**Specifiche tecniche**

| Asset | Quantità | Formato | Dimensioni |
| --- | --- | --- | --- |
| Badge tier | 22 | `.tga` 32-bit con alpha | 64×64 (+ 16×16 per la chat) |
| Badge apex | 6 | idem | 64×64 + flipbook 4×4 frame (256×256) |
| Sigilli storici "Ex-apex" | 7 | idem | 32×32 overlay |
| Badge Legend | 1 | idem | 128×128 + flipbook |
| Emblemi categoria + Global | 9 | idem | 64×64 |
| Cornici del profilo | 6 | idem | 256×128 |
| Particelle | ~6 | idem | 64×64 flipbook |
| Suoni | ~6 | `.ogg` 44.1 kHz | ordinari ≤ 2 s, apex ≤ 6 s |

**Linee guida di stile**

- Stile: emblema **fantasy medievale dipinto**, leggibile, coerente con la UI di WoW ma originale. Vista frontale, sfondo trasparente, nessun testo nell'immagine.
- Progressione visiva: il materiale stesso del tier è il soggetto (legno grezzo → pietra → metalli sempre più lavorati → gemme sfaccettate → materiali leggendari). Salendo crescono complessità della cornice, ornamenti e luminosità.
- Apex: cornice con elementi araldici (corona, ali, rune). Legend: aura cosmica e glow.
- Silhouette distinguibili anche in scala di grigi (accessibilità).

**Palette per tier (colore dominante)**

| Tier | Colore | Tier | Colore |
| --- | --- | --- | --- |
| Wood | `#8B5A2B` | Thorium | `#7A3FB0` |
| Stone | `#8A8A8A` | Ruby | `#C41E3A` |
| Copper | `#B87333` | Sapphire | `#0F52BA` |
| Tin | `#A9ACB6` | Emerald | `#2E8B57` |
| Bronze | `#CD7F32` | Topaz | `#FFC87C` |
| Iron | `#5A5F66` | Amethyst | `#9966CC` |
| Steel | `#7B8FA1` | Diamond | `#E8F4F8` |
| Silver | `#C0C0C0` | Arcanite | `#E0457B` |
| Gold | `#D4AF37` | Elementium | `#FF6A1A` |
| Mithril | `#5FB3C9` | Dragonite | `#1FA37A` |
| Truesilver | `#DDE6EA` | Apex | oro + colore della categoria |
| Dark Iron | `#2B2B30` | Legend | bianco + aura iridescente |

**Template di prompt (da adattare per ogni tier)**

```
Fantasy game rank emblem, heraldic shield badge made of <MATERIALE>,
<DETTAGLI ORNAMENTI DEL TIER>, dominant color <HEX>, painted hand-crafted style,
front view, centered, transparent background, no text, no letters,
clean silhouette readable at small size, soft rim light, high detail
```

Esempio Mithril: `MATERIALE = "polished blue-silver mithril with engraved runes"`, `DETTAGLI = "thin filigree border, small inset crystal at the top"`.

### 14.8 Avviso di boost (✅)

La regola anti-boost deve essere sempre evidente, perché può annullare per sempre eventi una tantum:

- **Indicatore permanente** sul pulsante minimappa, sul broker LDB e nella finestra principale mentre lo stato BOOSTED è attivo: icona ⚠ arancione e testo "Boost attivo: i punti sono sospesi".
- Il **tooltip** dell'indicatore spiega il motivo: "Nel gruppo: Thrall (60), tu sei 32" oppure "Aiuto da fuori gruppo: Jaina (58), 45 s rimanenti".
- **Avviso all'ingresso nel gruppo**: se entri in un gruppo con un membro di livello +10, compare un toast con il motivo e il suggerimento "Scoperte e quest completate ora non daranno punti, e quelle una tantum non si potranno recuperare".
- Nella **Cronologia**, gli eventi annullati compaiono barrati con il motivo (`BOOST:G`, `BOOST:A1`…).

Ogni asset generato va controllato prima dell'uso: originalità (nessuna somiglianza con loghi o asset esistenti), termini d'uso dello strumento AI per la distribuzione, leggibilità a 16 px.

### 14.6 Impostazioni principali

| Sezione | Opzioni |
| --- | --- |
| Badge | Modalità (§14.3), superfici attive, dimensione, posizione, opacità, "nascondi il mio badge agli altri" |
| Celebrazioni | Durata (3–15 s, default 7.5), skip abilitato, condizioni di rinvio (§15.3), anteprima |
| Suoni | On/off, canale audio (Master/SFX/Dialog), set suoni (Discreto/Epico), suono per apex on/off |
| Rete | Partecipa al canale realm on/off, rilancio profili on/off, livello traffico (Basso/Normale) |
| Privacy | Condividi il profilo dettagliato (livello 3) on/off, accetta Commendations on/off, accetta inviti a eventi, **mostra pubblicamente i miei alt** (opt-in per personaggio, default off) |
| Debug | Log level, `/azp stats`, export diagnostico |

---

## 15. Sistema di celebrazioni

### 15.1 Decisioni

| ID | Decisione | Stato |
| --- | --- | --- |
| 5.32 | Durata default **7–8 s** (implementata a 7.5 s), configurabile | ✅ |
| 5.33 | Promozioni multiple → **un'unica celebrazione combinata** | 🟡 (raccomandazione B, risposta non presente) |
| 5.41 | **Ibrido**: pannello centrale per i rank ordinari, cinematica per gli apex e Legend | ✅ |
| 5.42 | **Skip dopo 2 s** (ESC o pulsante Skip). La promozione è già registrata | ✅ |
| 5.43 | Suoni **configurabili**, differenziati per importanza (discreto / epico) | 🟡 (raccomandazione D+C) |
| 5.51 | Finestra di gioco aperta → **rinvio** alla chiusura | ✅ |
| 5.52 | Interazione con NPC → **rinvio** alla fine dell'interazione | ✅ |
| 5.53 | Viaggi → rinvio **solo sui trasporti automatici** (taxi, navi, zeppelin) | 🟡 (raccomandazione B) |
| 5.60 | Apertura della mappa durante una celebrazione → **sospensione** e ripresa | 🟡 (raccomandazione A, risposta "G" non interpretabile) |
| — | Combattimento → rinvio | ✅ (citato in 5.51 come già deciso) |

### 15.2 Macchina a stati

```
            promotion
   IDLE ───────────────► QUEUED ──(no blockers)──► PLAYING ──(timer end / skip)──► IDLE
     ▲                     │  ▲                       │
     │                     │  └──(blocker cleared)────┤
     │                     └──(blocker active)── WAITING
     │                                                 │
     └──────────── (all done) ◄── SUSPENDED ◄──(map open / blocker appears)
                                      └──(cleared) → PLAYING (ripresa dal punto sospeso)
```

- **Combinazione:** le promozioni arrivate entro 3 s l'una dall'altra, o accumulate mentre la coda è bloccata, si fondono in **una sola celebrazione**, con ordine: Global prima, poi le categorie in ordine di importanza del rank. Se una delle promozioni è l'ingresso o la salita in un apex, la celebrazione è cinematica. Gli spodestamenti non generano celebrazioni, solo un toast (§13.3).
- **Persistenza:** la coda sta in `CharDB.celebrationQueue` e sopravvive a `/reload` e logout. Le celebrazioni rimaste in coda per più di 24 h vengono riassunte in un toast.

### 15.3 Blocking conditions (configurabili, tutte attive di default)

| Condizione | Rilevamento |
| --- | --- |
| Combattimento | `InCombatLockdown()`, `PLAYER_REGEN_DISABLED/ENABLED` |
| Encounter in corso | `ENCOUNTER_START/END` |
| Interazione con NPC (gossip, quest, vendor, trainer, banca, AH, mail…) | `PLAYER_INTERACTION_MANAGER_FRAME_SHOW/HIDE` 🔍 V15 |
| Finestre di UI bloccanti (Character, Spellbook, Talenti, Quest log, Professioni…) | `GetUIPanel("left"/"center"/"right"/"doublewide")` + whitelist di frame |
| Mappa del mondo aperta | `WorldMapFrame:IsShown()` → SUSPEND |
| Trasporti automatici | `UnitOnTaxi("player")`; navi e zeppelin tramite zone/transport 🔍 |
| Cinematiche o filmati | `CINEMATIC_START/STOP`, `PLAY_MOVIE` |
| Schermata di caricamento | `LOADING_SCREEN_ENABLED/DISABLED` |
| Morto / fantasma | `UnitIsDeadOrGhost("player")` |

### 15.4 Presentazione

**Pannello (rank ordinari):** frame centrale ~420×260, fuori dalla zona dei frame di combattimento.

- 0–0.4 s: fade-in.
- 0.4 s: badge con scale 0.6→1.0.
- Testo: "DELVER · Gold II" e sotto "Delver ha raggiunto Gold II" più i PP.
- Particelle con texture flipbook.
- Fade-out negli ultimi 0.6 s.

**Cinematica (apex e Legend):** overlay a tutto schermo, `FULLSCREEN_DIALOG` strata.

- Sfondo che oscura gradualmente (alpha 0.75).
- Badge grande al centro, raggi e particelle, nome del rank in font decorativo.
- Sottotitolo con la frase del rank.
- Si aggiunge "Il tuo nome entra nella Hall of Prestige" e la posizione nella fascia (es. "Aspect · 12° di 100").

**Skip:** dopo 2 s appare "Skip [ESC]" in basso, discreto. ESC viene intercettato da un frame `OnKeyDown`, attivo solo durante la celebrazione, che **propaga** gli altri tasti. Tutto questo avviene sempre fuori dal combattimento, quindi `SetPropagateKeyboardInput` è utilizzabile.

**Suoni:** `PlaySoundFile` con file `.ogg` originali in `Media/Sounds`. Il volume per singolo suono non è controllabile, quindi l'opzione equivalente è la scelta del canale audio e del set di suoni.

---

## 16. Ricompense

Sono solo cosmetiche e solo all'interno dell'addon. L'addon non può assegnare nulla nel gioco, e la wiki lo esclude comunque.

| Traguardo | Ricompensa |
| --- | --- |
| Ogni tier | Nuovo badge e cornice |
| Gold, Diamond, Dragonite | Bordo del profilo dedicato |
| Apex (detenuto) | Cornice animata, titolo Prestige nel tooltip (es. "Delver Grandmaster") |
| Legend (detenuto) | Glow, titolo "Legend of the Vanguard" |
| Qualsiasi apex ottenuto in passato | Voce permanente nell'albo e nella Hall of Prestige, sigillo storico sul badge, titolo selezionabile in forma storica (es. "Ex-Legend of the Vanguard") |
| Varietà: 4 categorie ≥ Gold | Titolo "Hero of Azeroth" e badge Global speciale |
| Tutte le 8 categorie ≥ Silver | Titolo "Renaissance" |

🟡 Il **titolo Prestige** scelto dal giocatore compare nel suo tooltip e nel profilo, per gli altri utenti addon.

---

## 17. Prestazioni e budget

| Metrica | Budget |
| --- | --- |
| CPU media in idle | < 0.1 ms/frame. Nessun `OnUpdate` permanente: solo eventi e `C_Timer` |
| CPU in città affollata (50 nameplate) | < 0.5 ms/frame. Lookup O(1) per `charKey`, badge riusati via pool |
| Memoria | < 8 MB con 10 000 profili, < 15 MB al limite |
| Rete in uscita | ≤ 1 msg/s medio, burst ≤ 5 |
| Tempo di login | < 150 ms per caricare l'addon. Compattazione e sync differiti di 10 s |
| Polling posizione (segreti) | 1 Hz, solo fuori dalle istanze e solo se un segreto è entro 500 yard (precalcolo per mappa) |
| Scansione anti-boost (A1, A2) | 2 Hz, solo in combattimento, fuori dalle istanze e con livello del giocatore ≤ 50 |

---

## 18. Localizzazione e accessibilità

- Lingue: **enUS** (base, fallback) e **itIT** al lancio. Struttura pronta per deDE, frFR, esES. Le stringhe stanno in `Locales/*.lua` (pattern AceLocale).
- Nomi di rank e categorie restano in inglese in tutte le lingue (sono nomi propri), con descrizione localizzata.
- Accessibilità:
  - le divisioni sono comunicate da pip **e** numeri romani, non solo dal colore;
  - modalità "alto contrasto" per i badge;
  - opzione "riduci effetti" per disattivare particelle e flash nelle cinematiche.
- Il tooltip del badge spiega sempre cosa misura (principio della wiki).

---

## 19. Compatibilità e policy

### 19.1 Altri addon

- **Nameplate addon** (Plater, Platynator, KUI, ElvUI…): un adapter rileva l'addon e ancora il badge al suo frame del nome, se esposto. In alternativa ci si aggancia alla plate di base. Plater ha anche uno *script/mod* consigliato che chiama `AzerothPrestige.GetBadge(unit)`.
- **Unit frame addon** (ElvUI, Cell, VuhDo): esposta l'API pubblica. Adapter dedicati in fase 2.
- **Chat addon** (Prat, Chattynator): usare la catena standard dei message filter.

### 19.2 API pubblica (`AzerothPrestige`)

```lua
AzerothPrestige.GetProfile(charKey)        -- tabella read-only o nil
AzerothPrestige.GetRank(charKey, cat)      -- tierIndex, division, pp
AzerothPrestige.GetBadge(unitOrCharKey, mode) -- texturePath, coords, label
AzerothPrestige.RegisterCallback(event, fn)   -- "PROMOTION", "PROFILE_UPDATED", "LEGEND_CHANGED"
```

### 19.3 Policy Blizzard (UI Add-On Development Policy)

- Gratuito, codice non offuscato, niente pubblicità in gioco, niente raccolta di dati personali reali.
- Niente automazione del gameplay: tutte le azioni sono eventi ascoltati o clic dell'utente.
- Nessun traffico di rete che degradi il servizio: throttle e budget (§12, §17).
- Distribuzione su CurseForge e Wago con BigWigs packager.

---

## 20. Testing e QA

### 20.1 Test automatici (fuori dal gioco)

- **busted** + mock delle API WoW (`tests/mocks/wow.lua`).
- Coperture obbligatorie:
  - `Scoring`: soglie, DR, cap, GP, apex, ruleset versioning.
  - `Ledger`: idempotenza, compattazione, ricalcolo.
  - `Codec`: roundtrip, chunking, messaggi malformati.
  - `ProfileStore`: merge prima/seconda mano, monotonicità, plausibilità.
  - `Leaderboard`: assegnazione a cascata dei 7 × 100 posti apex, spareggi, consenso `LBD`, apertura e chiusura dei regni.
  - `Celebrations/Queue`: tutte le transizioni della macchina a stati.
- CI GitHub Actions: luacheck + busted a ogni PR.

### 20.2 Test in gioco

- `/azp debug`: pannello con stato restrizioni, coda di rete, coda celebrazioni, profili noti.
- `/azp sim <ruleId> [n]`: genera eventi finti (solo in modalità debug, marcati `tl=0`, mai trasmessi).
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

---

## 21. Roadmap

| Milestone | Contenuto | Uscita |
| --- | --- | --- |
| **M0 — API spike** | Script di verifica V1–V16, report `m0-api-report.md`, revisione di questo documento | Spec v0.2 |
| **M1 — Core** | Core, Restrictions, Data/Ladder, Scoring, Ledger, SavedVariables, test busted | Punti calcolati localmente |
| **M2 — Tracker "oggettivi"** | Delver, Adventurer, Pathfinder, Artisan + Backfill | Alpha privata |
| **M3 — UI e celebrazioni** | Finestra, profilo 3 livelli, cronologia, impostazioni, Celebration Queue completa | Alpha 2 |
| **M4 — Rete** | Comm, beacon, PRQ/PRF, attestazioni, ProfileStore, badge (tooltip, nameplate, frame, chat, menu) | **Beta pubblica** |
| **M5 — Tracker "sociali"** | Vanguard, Merchant, Diplomat, Steward, Commendations, Prestige Events | Beta 2 |
| **M6 — Classifiche e apex** | Leaderboard, RLY, LBD, snapshot, posti apex, albo dei titoli, Hall of Prestige | **Release 1.0** |
| **M7 — Estensioni** | Prestige Contracts, adapter per altri addon, liste gilda e amici, nuove lingue | 1.x |

> Nota: il PO ha confermato tutte le 8 categorie dal day-1. La **release 1.0** le include tutte. L'ordine delle milestone serve solo a sviluppare per prime le categorie più semplici da verificare, così da calibrare il ritmo su dati reali.

---

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
| D-38 | Chi aiuta prende Diplomat + i punti del contenuto depotenziati (§8.7) | ✅ | Revisione v0.4 |
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

---

## 23. Questioni aperte

Le 10 questioni di v0.1 sono risolte (D-04, D-05, D-13, D-26…D-33). Restano aperti:

1. **Decisioni 🟡 di design** ancora da confermare: D-07, D-11, D-15, D-18, D-21, D-22, D-23, D-24, D-25.
2. **Esito della milestone M0** (verifiche V1–V18): può cambiare sorgenti di eventi e superfici dei badge.
3. **Valori di calibrazione** di punti per regola e coefficienti delle categorie, da tarare in beta con dati reali, per rendere equivalenti percorsi di attività comparabili tra le 8 categorie.
4. **Obiettivi militari di Vanguard** (`VAN_MIL_OBJ`): da definire dopo aver verificato i contenuti warfare di Forever.

---

## 24. Fonti

- Chat di design A–F (`.gpt-ideas/`).
- Wiki *Prestige and Competitive Recognition*: https://github.com/Finland6738/wow-forever-game-design-proposal/wiki/Prestige-Ranks
- World of Warcraft: Forever, Warcraft Wiki: https://warcraft.wiki.gg/wiki/WoW_Forever
- TOC format: https://warcraft.wiki.gg/wiki/TOC_format
- `C_ChatInfo.SendAddonMessage`: https://warcraft.wiki.gg/wiki/API_C_ChatInfo.SendAddonMessage
- Secret values: https://warcraft.wiki.gg/wiki/Secret_values
- Patch 12.0.0 API changes: https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes
- WoW Forever loads retail addons: https://www.warcrafttavern.com/forever/news/wow-forever-loads-your-retail-addons-keybinds/

# SPEC-03: Catalogo delle attività per categoria

> Parte della [specifica di Azeroth Prestige](README.md). Nata dal documento unico v0.4 del 2026-11-26, diviso in file nel bootstrap: la numerazione delle sezioni (§) è quella del documento originale, così i rimandi restano validi in tutti i file. Legenda: ✅ confermato dal proprietario · 🟡 proposta valida fino a diversa decisione ([SPEC-11](SPEC-11-risks-open-questions.md)) · 🔍 da verificare in M0.

## 7. Catalogo attività per categoria

**Convenzioni**

- `L` = livello nativo del contenuto: livello del boss o della quest (`UnitLevel` del boss non serve, il valore viene dal ruleset per `encounterID`).
- **Una tantum** = una sola volta per personaggio. **Ripetibile** = soggetto a diminishing returns ([§8.2](SPEC-02-progression-scoring.md)).
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
| `VAN_DUEL_WIN` | Duello vinto | `DUEL_FINISHED` + `CHAT_MSG_SYSTEM` (vincitore) | 15 | ⛔ **Limitato** ([§8.2](SPEC-02-progression-scoring.md)): max 3 conteggiati per avversario al giorno. Avversario di livello ≥ proprio − 5 |
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

Per contenuti 10+ livelli sotto il giocatore i punti sono depotenziati ([§8.7](SPEC-02-progression-scoring.md)).

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
| `DIP_HELP_LOW` | Completare un contenuto in gruppo (quest, boss) con un membro ≥ 10 livelli sotto di te e sotto il 60 | `UnitLevel` dei membri al momento dell'evento | 30 per membro aiutato, per evento | Ripetibile, senza limiti. Regola anti-alt ([§8.5](SPEC-02-progression-scoring.md)). È il rovescio della regola anti-boost ([§8.6](SPEC-02-progression-scoring.md)): chi aiuta prende questi punti, chi è aiutato non prende punti |
| `DIP_MENTOR` | Il membro aiutato è un utente addon e ti attesta come "mentore" | attestazione dal suo client | 150 | ⛔ È un'attestazione tra due persone, quindi segue le regole delle Commendations: una volta per coppia ogni 7 giorni |
| `DIP_COMMEND` | Commendation ricevuta, di tipo *Gentile*, *Guida* o *Paziente* | messaggio `CMD` ([§12](SPEC-06-network-protocol.md)) | 50 | ⛔ Vedi regole sotto |
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
| `ART_CRAFT` | Craft ripetuto | idem | 2 | ⛔ **Limitato**: DR ([§8.2](SPEC-02-progression-scoring.md)), cap 100/giorno |
| `ART_CRAFT_FOR_OTHER` | Oggetto craftato da te consegnato in trade a un altro giocatore | trade + item crafted di recente | 25 | ⛔ Max 1 per partner al giorno, cap 250/giorno. Regola anti-alt ([§8.5](SPEC-02-progression-scoring.md)) |

### 7.7 💰 Merchant

Non si premia il volume d'oro. Si premiano **varietà, controparti distinte e continuità**.

| ruleId | Attività | Sorgente | Punti | Tipo / anti-abuso |
| --- | --- | --- | --- | --- |
| `MER_AH_SALE` | Asta venduta | mail invoice (`GetInboxInvoiceInfo`) 🔍 | `5 + 10 × log10(1 + prezzo_in_oro)` | ⛔ Cap 300/giorno. Valore pieno solo per il primo acquisto di ogni acquirente distinto nel giorno. Niente punti se l'acquirente è un alt ([§8.5](SPEC-02-progression-scoring.md)) |
| `MER_AH_BUYER` | Nuovo acquirente distinto nella settimana | invoice (nome buyer) | 10 | ⛔ Cap 200/settimana |
| `MER_TRADE` | Trade completato con scambio bilaterale (oggetto ↔ oro o oggetto) | `TRADE_*` events | 15 | ⛔ Max 2 per partner al giorno, cap 150/giorno. **Zero punti tra alt** ([§8.5](SPEC-02-progression-scoring.md)) |
| `MER_ITEM_VARIETY` | Primo oggetto *diverso* venduto (itemID mai venduto) | invoice | 8 | Una tantum per itemID |
| `MER_STREAK` | Settimana con ≥ 10 vendite in ≥ 4 giorni diversi | derivato | 200 | Una volta a settimana |
| `MER_CONTRACT` | Prestige Contract completato (§7.10) | protocollo | 100 | Max 3 al giorno |

✅ Il commercio tra personaggi dello stesso account **non dà punti** ([§8.5](SPEC-02-progression-scoring.md)). Scala log, cap e "acquirenti distinti" limitano anche gli scambi tra amici compiacenti.

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

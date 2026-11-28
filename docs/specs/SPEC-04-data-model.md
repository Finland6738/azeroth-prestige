# SPEC-04: Modello dati e SavedVariables

> Parte della [specifica di Azeroth Prestige](README.md). Nata dal documento unico v0.4 del 2026-11-26, diviso in file nel bootstrap: la numerazione delle sezioni (§) è quella del documento originale, così i rimandi restano validi in tutti i file. Legenda: ✅ confermato dal proprietario · 🟡 proposta valida fino a diversa decisione ([SPEC-11](SPEC-11-risks-open-questions.md)) · 🔍 da verificare in M0.

## 10. Modello dati e SavedVariables

Lo **schema 1** è quello che `Core/Config.lua` scrive da M1.5 ([SPEC-01 §9.7.8](SPEC-01-platform-architecture.md)). Contiene solo i campi che M1 usa. I campi delle milestone successive hanno già un nome riservato: arrivano con il loro default, senza migrazione (§10.6), e la loro forma esatta la fissa lo step di specifica della milestone. Le variabili sono tabelle Lua semplici, senza AceDB ([ADR 0006](../adr/0006-embedded-ace3-savedvariables-and-schema-versions.md), aggiornamento M1.1).

### 10.1 `AzerothPrestigeCharDB` (per personaggio)

```lua
AzerothPrestigeCharDB = {
  schema = 1,
  charKey = "Thrall-Forever",               -- Compat.Player.CharKey() al login ("Nome-RealmNormalizzato", §6.1)
  guid = "Player-0000-00000000",            -- nil finché il client non lo dà
  createdAt = 1764115200,                   -- primo login con l'addon (ora del server, UTC); mai cambiato
  rv = 1,                                   -- ruleset dell'ultimo evento aggiunto
  points = { VAN = 0, DEL = 0, PAT = 0, ADV = 0, DIP = 0, ART = 0, MER = 0, STE = 0 },  -- interi ≥ 0, cache del ricalcolo
  peak   = { VAN = 1, DEL = 1, PAT = 1, ADV = 1, DIP = 1, ART = 1, MER = 1, STE = 1, GP = 1 },  -- step 1..88, mai decrescente
  ledger = {                                -- eventi (§10.4), ordinati per (t, id); i più vecchi vanno in compact (§10.3)
    { id = "9f3a0c1d2b4e5f60", t = 1764200000, r = "DEL_BOSS", k = "enc:1234",
      c = { l = 55, d = 1, g = 5, pl = 52, gmx = 54 }, pp = 55, rv = 1, tl = 1 },
    { id = "a1c07e9b33d21f08", t = 1764203600, r = "ADV_QUEST", k = "q:812",
      c = { l = 30, pl = 28, gmx = 45 }, pp = 0, why = "BOOST:G", rv = 1, tl = 1 },   -- annullato per boost
  },
  compact = {                               -- aggregati degli eventi compattati, per "ruleId:soggetto"
    ["DEL_BOSS:enc:1234"] = { n = 14, pp = 520, pv = 520, t1 = 1761000000, t2 = 1763500000 },
  },
  oneTime = { ["PAT_FLIGHT:node:23"] = 1764190000 },   -- chiavi una tantum consumate → momento del consumo
  boost = {                                 -- stato anti-boost che deve sopravvivere a /reload (§8.6)
    spans  = { { a = 1764199000, b = 1764199240, g = "A1" } },   -- intervalli BOOSTED delle ultime 24 h
    quests = { [812] = 1764199100 },        -- questID con un obiettivo avanzato mentre eri BOOSTED
    reps   = { [69] = 1764199200 },         -- factionID con reputazione guadagnata mentre eri BOOSTED
  },
  bad = { },                                -- voci del ledger danneggiate, messe da parte (max 100), mai contate né cancellate
  settings = { },                           -- impostazioni del personaggio (M3, M4)
}
```

| Campo | Tipo | Regola |
| --- | --- | --- |
| `schema` | intero | `Config.SCHEMA` (§10.6) |
| `charKey` | stringa | Se al login cambia (rename 🔍), il nuovo valore sostituisce il vecchio e `myChars` tiene entrambi (§10.2) |
| `guid` | stringa o nil | Aggiornato a ogni login in cui è leggibile |
| `createdAt` | intero | Scritto una volta sola; serve ai controlli di plausibilità (§11.5) |
| `rv` | intero | `Ruleset.Current()` al momento dell'ultimo evento |
| `points` | 8 interi | Ricalcolabili dal ledger (§10.6): un ricalcolo non li abbassa mai |
| `peak` | 9 step | Lo step più alto mai raggiunto per categoria e per il Global (§6.5). Lo stato apex è a parte (M6) |
| `ledger` | lista di eventi | §10.4 |
| `compact` | mappa | `n` eventi, `pp` totali, `pv` = PP con `tl ≥ 2` (per il `vr`, §11.4), `t1`/`t2` = primo e ultimo evento |
| `oneTime` | mappa | Chiave `ruleId:soggetto` (§10.5) → `t`. Una chiave consumata non si libera mai (anche se annullata per boost, Q13) |
| `boost` | tabella | `spans` più vecchi di 24 h si tolgono al login; `quests` si tolgono al turn-in o all'abbandono; `reps` allo standing successivo |
| `bad` | lista | Una voce che non supera la validazione (manca `id`, `r` o `t`, tipi sbagliati) viene spostata qui con il motivo; resta per il debug |
| `settings` | tabella | Vuota in M1 |

Nomi riservati (aggiunti dalla loro milestone con un default): `apexReigns` (M6, la forma di §6.5), `celebrationQueue` (M3, §15), `profileVersion` (M4, intero monotono), `hc` (M5, §13.5), `settings.featuredCategory` e `settings.hideMyBadge` (M3/M4).

### 10.2 `AzerothPrestigeDB` (account)

```lua
AzerothPrestigeDB = {
  schema = 1,
  myChars = {                               -- i personaggi di questo account WoW su questo PC: regola anti-alt (§8.5)
    ["Thrall-Forever"] = { guid = "Player-0000-00000000", firstSeen = 1764115200, lastSeen = 1764200000,
                           publicAlt = false },
    ["Garrosh-Forever"] = { guid = "Player-0000-00000001", firstSeen = 1764000000, lastSeen = 1764100000,
                            publicAlt = false, renamedTo = "Grom-Forever" },   -- rename: la voce vecchia resta
  },
  settings = { },                           -- impostazioni dell'account (M3: UI, badge, celebrazioni, suoni)
}
```

- `Config:RegisterCharacter(now)` aggiorna la voce del personaggio a ogni login. Se il GUID è già registrato con un'altra chiave, la voce vecchia riceve `renamedTo` e resta: un rename non apre un buco nella regola anti-alt.
- `Config:IsMyChar(x)` accetta un `charKey` o un GUID e controlla tutte le voci, anche quelle rinominate.
- `publicAlt` è falso di default; lo usa il collegamento pubblico degli alt (§6.1, M4).

Nomi riservati, con la forma indicativa sotto (definitiva negli step M4.1 e M6.1): `profiles` (M4), `witnessLog` (M4, 90 giorni), `snapshots` (M6, §13.3), `hallOfPrestige` (M6, §13.4).

```lua
  profiles = {                              -- profili noti (altri + propri), M4
    ["Jaina-Forever"] = {
      v = 17,                                -- profileVersion del proprietario
      seen = 1764200000,                     -- ultimo dato di prima mano
      src = 1,                               -- 1 = prima mano, 2 = seconda mano corroborata, 3 = seconda mano singola
      pts = { 1200, 5400, 300, 2200, 0, 800, 0, 150 },  -- ordine fisso di Ladder.CATEGORIES
      peak = { ... }, gp = 10050,
      fc = "DEL",                            -- categoria in evidenza
      vr = 0.72,                             -- verified ratio (§11.4)
      ar = { ... },                          -- apex reigns dichiarati (albo dei titoli)
      cls = 8, lvl = 60, gld = "Kirin Tor", fac = "A",   -- A / H
      alts = nil,                            -- elenco alt solo se opt-in pubblico (§6.1)
      hc = nil,                              -- Hardcore: { dead = ts, zone = "..." } (§13.5)
      relays = { ["Arthas-Forever"] = 17 },  -- chi ha rilanciato quale versione
      flags = 0,                             -- bit: flagged, hidden, trial
    },
  },
  snapshots = {                              -- snapshot settimanali dei posti apex (§13.3), M6
    ["2026-W48"] = {
      VAN = { LEGEND = { "Jaina-Forever", ... }, ASPECT = { ... }, ..., MASTER = { ... } },
      GP  = { ... },
    },
  },
  hallOfPrestige = {                         -- albo osservato di tutti i regni apex del realm (§13.4), M6
    ["Jaina-Forever"] = { { cat = "VAN", rank = "LEGEND", start = ..., finish = nil }, ... },
  },
  witnessLog = { },                          -- attestazioni rilasciate (§11.3), 90 gg, M4
```

### 10.3 Limiti di dimensione (🟡)

| Elemento | Limite | Politica |
| --- | --- | --- |
| Ledger dettagliato | 30 giorni o 5 000 eventi | Oltre, compattazione in `compact`. Gli eventi degli **ultimi 8 giorni non si compattano mai**, anche oltre 5 000: servono al DR e ai cap delle finestre giornaliere e settimanali |
| `boost.spans` | 24 ore | Pulizia al login |
| `bad` | 100 voci | Oltre, si scarta la più vecchia (con una riga di log) |
| Profili noti | 20 000 | Eviction LRU con priorità: si tengono sempre i top 1 000 per categoria (tutti i candidati apex), chi compare nell'albo apex, gilda, amici e ultimi 7 giorni |
| `witnessLog` | 90 giorni | Pulizia al login |
| SavedVariables totali | < 15 MB | Monitorato con `/azp stats` |

**Compattazione** (`Ledger:Compact(now)`, 10 s dopo il login e poi una volta al giorno di gioco): sposta in `compact` gli eventi con `t < now − 30 giorni` e, se ne restano più di 5 000, i più vecchi fino a tornare a 5 000, senza toccare quelli degli ultimi 8 giorni. Ogni evento spostato aggiunge `n = 1`, il suo `pp`, il suo `pp` a `pv` se `tl ≥ 2`, e allarga `t1`/`t2` della chiave `ruleId:soggetto`. I `pp` si conservano come sono stati calcolati (§10.7): compattare non cambia i totali, e i test lo provano.

### 10.4 Evento del ledger

```lua
{ id  = "9f3a0c1d2b4e5f60",   -- §10.5
  t   = 1764200000,           -- ora del server (UTC) dell'evento di gioco, non del momento in cui il tracker lo vede
  r   = "DEL_BOSS",           -- ruleId (SPEC-03)
  k   = "enc:1234",           -- contextKey: "soggetto" oppure "soggetto#occorrenza" (§10.5)
  c   = { l = 55, d = 1, g = 5, pl = 52, gmx = 54 },   -- contesto (tabella sotto)
  pp  = 55,                   -- punti calcolati all'aggiunta con la catena di §10.7
  rv  = 1,                    -- ruleset in vigore (§8.1)
  tl  = 1,                    -- livello di fiducia 0..3 (§11.2)
  w   = nil,                  -- testimoni { charKey, ... } (M4)
  why = nil,                  -- perché pp è 0: "BOOST:G" | "BOOST:A1" … "BOOST:A4" | "ALT" | "CAP" | "LIMIT" | "OFF" | "UNKNOWN_RULE"
  src = nil,                  -- origine diversa dal gioco dal vivo: "BF" (backfill, §7.9) | "SIM" (/azp sim, Q22)
}
```

Campi di contesto `c` (chiavi di 1–3 lettere minuscole, perché viaggiano in rete). Gli step `.1` di M2 e M5 aggiungono qui quelli dei loro tracker.

| Campo | Quando | Significato |
| --- | --- | --- |
| `pl` | sempre | Livello del giocatore all'evento (§8.6.3, §8.7) |
| `gmx` | sempre | Livello più alto del gruppo, giocatore compreso; `pl` da solo; `-1` se un membro è "??" (🔍 V19) |
| `l` | regole `lowLevel` | Livello nativo del contenuto `L` (§7) |
| `dy` | regole con `window` | Indice del giorno del realm (`Ledger.DayIndex`): rende DR e cap ricalcolabili da chiunque (§10.7) |
| `d`, `g` | Delver (M2) | `difficultyID`, dimensione del gruppo |
| `o` | regole `counterpart` | `charKey` della controparte (anti-alt, M5) |

Un evento a 0 punti **resta nel ledger** con il suo `why`: serve alla cronologia e al debug (casi A11, A15), e un evento una tantum annullato consuma comunque la sua chiave (Q13). Un evento `SIM` ha `tl = 0`, non viene mai trasmesso e non entra nel digest (Q22).

### 10.5 `eventId` e bucket temporale

```
bucket = once and "*" or floor(t / 60)
id     = Hash.Short(charKey .. "\31" .. ruleId .. "\31" .. k .. "\31" .. bucket, 16)
```

- `charKey` è quello del proprietario del ledger: due personaggi non producono mai lo stesso id, nemmeno per lo stesso boss.
- `Hash.Short(…, 16)` = i primi 16 caratteri esadecimali di SHA-256, 64 bit: con 100 000 eventi la probabilità di una collisione è circa 3 × 10⁻¹⁰.
- Il bucket è di 60 s (§8.4). Le regole `once` non hanno bucket (`"*"`): l'id dipende solo da regola e contesto.
- `"\31"` (unit separator) non può comparire in nessun campo, quindi l'unione non è ambigua.

**Il `contextKey` `k`**: `"<tipo>:<id>"` (`enc:1234`, `q:812`, `node:23`, `opp:Jaina-Forever`), al massimo 64 byte, UTF-8 senza caratteri di controllo e senza `"\31"`; `#` solo come separatore dell'occorrenza.

- Il **soggetto** (la parte prima di `#`, `Ledger.Subject(k)`) dice *che cosa*: è la chiave del set `oneTime` (`ruleId:soggetto`), del DR e dei limiti per soggetto (§10.7).
- L'**occorrenza** (`#…`) distingue due eventi reali dello stesso soggetto nello stesso minuto, solo quando il gioco dà un identificativo naturale (il contatore HK lifetime, il `castGUID` di un craft). Un tracker non usa mai un contatore locale che ripartirebbe da capo dopo un `/reload`.
- Il tracker usa come `t` l'ora dell'evento di gioco. Se non può (uno stato letto di nuovo dopo un `/reload`), la regola deve essere `once` o avere un'occorrenza naturale.

**Duplicati**: `Ledger:Append` scarta un evento il cui `id` è già nel ledger (`"DUP"`) o la cui chiave una tantum è già in `oneTime` (`"ONCE"`): copre `/reload`, reconnect e doppia ricezione, anche dopo la compattazione. Rifiuta anche gli eventi più vecchi dell'orizzonte di compattazione (`"STALE"`, 30 giorni), salvo il backfill delle regole una tantum.

### 10.6 Contratto delle migrazioni

1. Ogni variabile ha `schema` (intero ≥ 0). `Config.SCHEMA` è lo schema che il codice scrive; in M1 vale 1.
2. `Config.migrations[scope][n]` (`scope` = `"account"` o `"char"`) porta una tabella dallo schema `n − 1` allo schema `n`. È una funzione **pura** (niente API di WoW, niente altri moduli, il tempo solo come argomento) e **idempotente**.
3. `Config:Load()` carica prima l'account e poi il personaggio. Per ciascuno:
   - variabile assente o tabella vuota → installazione nuova: i default dello schema corrente, senza problemi registrati;
   - `schema` assente in una tabella non vuota → schema 0, con un problema in `Config.issues`;
   - `schema` danneggiato (non intero, negativo) → schema 0, con un problema;
   - `schema` < `Config.SCHEMA` → i passi `schema + 1 … SCHEMA` girano su una **copia**; se tutti riescono, il contenuto della copia sostituisce quello originale **nella stessa tabella** (le SavedVariables tengono la loro identità); se un passo fallisce, l'originale resta intatto e l'addon va in **sola lettura** su quella variabile;
   - `schema` > `Config.SCHEMA` (dati scritti da una versione più nuova) → **sola lettura**: si lavora su una copia, l'originale non viene mai riscritto.
4. Dopo le migrazioni: i default mancanti si aggiungono senza sovrascrivere nulla; i valori di tipo sbagliato tornano al default e finiscono in `Config.issues`; gli eventi del ledger non validi vanno in `bad` (§10.1). Nulla viene cancellato.
5. In sola lettura `Config:Set`, `Ledger:Record` e `Ledger:Append` rispondono `"READONLY"`; i punti si mostrano ma non cambiano; `WARN_READ_ONLY` lo dice al giocatore una volta per sessione e `/azp debug` dice quale variabile e perché.
6. Una migrazione **non abbassa mai** `points`, `peak`, `oneTime`, `apexReigns` né i regni dell'albo ([ADR 0003](../adr/0003-points-recomputed-from-events.md), [ADR 0006](../adr/0006-embedded-ace3-savedvariables-and-schema-versions.md)). Dopo il caricamento `Ledger:Recompute()` ricalcola i punti; se una categoria risultasse più bassa del valore salvato, il valore salvato resta, il fatto va nel log e in `/azp debug` (è un difetto da correggere con un nuovo ruleset, mai togliendo punti). L'unica eccezione è `/azp sim clear` nelle build di sviluppo (Q22).
7. **Quando serve un nuovo schema**: aggiungere un campo con un default **non** richiede una migrazione; cambiare il significato o la forma di un campo esistente, spostare o rinominare dati sì. Ogni nuovo schema aggiunge il suo passo, una fixture `Tests/fixtures/<scope>_schema_<n−1>.lua` e un caso in `Tests/test_config.lua`, e aggiorna questa sezione e il CHANGELOG.
8. Il passo `0 → 1` non trasforma nulla: i dati senza schema passano dalla validazione del punto 4.

| Schema | Step | Account | Personaggio |
| --- | --- | --- | --- |
| 1 | M1.5 | `myChars`, `settings` | `charKey`, `guid`, `createdAt`, `rv`, `points`, `peak`, `ledger`, `compact`, `oneTime`, `boost`, `bad`, `settings` |

### 10.7 Formato del ruleset

Ogni versione è un file `Data/Ruleset_v<N>.lua` che registra una tabella in `ns.Rulesets[N]` ([ADR 0003](../adr/0003-points-recomputed-from-events.md)). Una versione pubblicata in un rilascio **non cambia più**: un valore nuovo, o un difetto corretto, è una nuova versione, che vale solo per gli eventi successivi. Una versione può nascere da un'altra con `Ruleset.Derive`, senza toccarla.

```lua
local _, ns = ...
ns.Rulesets = ns.Rulesets or {}
local R = {}
ns.Rulesets[1] = {
  rv = 1,
  format = 1,                                  -- versione di questo formato
  constants = {
    DR = { 1, 0.75, 0.5, 0.25, 0.10 },         -- §8.2: 1ª, 2ª, 3ª, 4ª, dalla 5ª
    LOW_LEVEL_GAP = 10,                        -- §8.7
    APEX_MIN_VR = 0.6,                         -- §11.4, Q10
  },
  rules = R,
}

R.DEL_BOSS = { cat = "DEL", boost = "encounter", lowLevel = true,
  points = function(c) return c.l * 1.0 end, sample = { l = 55, d = 1, g = 5 } }
R.PAT_FLIGHT = { cat = "PAT", boost = "instant", once = true, backfill = true,
  points = function() return 60 end }
R.VAN_DUEL_WIN = { cat = "VAN", boost = "instant", counterpart = true,
  family = "DUEL", window = "day", perKey = 3,
  points = function() return 15 end }
R.ART_CRAFT = { cat = "ART", boost = "instant", family = "CRAFT", window = "day", cap = 100,
  points = function() return 2 end }
R.VAN_MIL_OBJ = { cat = "VAN", boost = "instant", status = "off",   -- Q17
  points = function() return 0 end }
```

| Campo | Tipo | Obbligatorio | Significato |
| --- | --- | --- | --- |
| `cat` | `"VAN"` … `"STE"` | sì | Categoria (`Ladder.CATEGORIES`) |
| `points` | `function(c) → number` | sì | **Pura**: legge solo il contesto `c` (una copia) e `math`; restituisce un numero ≥ 0, anche decimale. Un campo mancante vale come 0 per la regola, non come errore |
| `boost` | `"instant"` \| `"encounter"` \| `"run"` \| `"quest"` \| `"rep"` | sì | Quando l'anti-boost annulla l'evento (§8.6.2): al momento dell'evento; tra `ENCOUNTER_START` ed `ENCOUNTER_END`; se un boss della run è stato annullato; al turn-in o con un obiettivo avanzato da BOOSTED; con reputazione guadagnata da BOOSTED |
| `once` | boolean | no | Una tantum: chiave `ruleId:soggetto` in `oneTime`, `eventId` senza bucket |
| `lowLevel` | boolean | no | Si applica il divisore di §8.7 (le regole il cui valore dipende da `L`) |
| `family` | `"DUEL"` \| `"CRAFT"` \| `"TRADE"` \| `"COMMEND"` | no | Famiglia limitata di §8.2: attiva il DR sulla chiave `ruleId:soggetto` nella finestra |
| `window` | `"day"` \| `"week"` | con `family` | Finestra di DR e limiti; l'evento salva `c.dy`. Il giorno inizia alle 00:00 del calendario del realm, la settimana il lunedì (Q23) |
| `cap` | intero | no, solo con `family` | PP massimi della regola per finestra |
| `perKey` | intero | no, solo con `family` | Eventi contati per soggetto per finestra (es. 3 duelli per avversario al giorno) |
| `maxCount` | intero | no, solo con `family` | Eventi contati per regola per finestra (es. 10 avversari nuovi al giorno) |
| `counterpart` | boolean | no | L'evento ha una controparte `c.o`: se è in `myChars`, `why = "ALT"` (§8.5) |
| `status` | `"off"` | no | Regola presente ma spenta: 0 punti, `why = "OFF"` |
| `backfill` | boolean | no | Importabile dal backfill (§7.9) |
| `sample` | tabella | no | Contesto d'esempio per `/azp sim` e per i test |

Le milestone successive possono aggiungere campi facoltativi (ad esempio i tassi massimi per categoria di §11.5 in `constants`, le regole speciali delle Commendations di §7.5) alzando `format` solo se un campo esistente cambia significato.

**Catena di calcolo** (`Scoring.EventPoints`, la forma esatta di §8.1). Per un evento `ev` con la sua regola:

1. Regola assente → 0, `why = "UNKNOWN_RULE"`; regola `off` → 0, `why = "OFF"`.
2. `raw = points(c)` in `pcall`; un risultato non numerico, negativo, infinito o `NaN` vale 0 (con un `Log.Warn`).
3. `ev.why` già deciso all'aggiunta (`BOOST:*`, `ALT`) → 0.
4. `lowLevel` e `c.pl − c.l ≥ LOW_LEVEL_GAP` → `raw / (c.pl − c.l)`.
5. Con `family`: `occorrenza` = 1 + gli eventi **contati** (`why` nil) della stessa chiave `ruleId:soggetto` con lo stesso indice di finestra (`c.dy`, o `WeekIndex(c.dy)`) e prima di `ev` in ordine `(t, id)`. Oltre `perKey`, o con `maxCount` eventi contati della regola nella finestra → 0, `why = "LIMIT"`. Altrimenti `× DR[min(occorrenza, 5)]`.
6. Con `cap`: `min(pp, cap − PP già contati della regola nella finestra)`; se il risultato è 0, `why = "CAP"`.
7. `pp = floor(pp)`.

Gli eventi annullati (`BOOST`, `ALT`, `OFF`, `LIMIT`, `CAP`) non consumano DR né cap. La catena dipende solo dall'evento, dalla sua `rv` e dagli eventi precedenti della stessa finestra, tutti salvati: il ricalcolo dà sempre lo stesso risultato, in locale e nei peer.

`Ruleset.Validate` (usato da `Tests/test_ruleset.lua`) rifiuta: `cat` o `boost` sconosciuti; `points` che non è una funzione; `window`, `cap`, `perKey` o `maxCount` senza `family`; `family` senza `window`; una famiglia fuori dall'elenco di §8.2; un `ruleId` che non è nel catalogo di [SPEC-03](SPEC-03-activity-catalog.md).

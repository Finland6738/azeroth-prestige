# SPEC-01: Piattaforma e architettura

> Parte della [specifica di Azeroth Prestige](README.md). Nata dal documento unico v0.4 del 2026-11-26, diviso in file nel bootstrap: la numerazione delle sezioni (§) è quella del documento originale, così i rimandi restano validi in tutti i file. Legenda: ✅ confermato dal proprietario · 🟡 proposta valida fino a diversa decisione ([SPEC-11](SPEC-11-risks-open-questions.md)) · 🔍 da verificare in M0.

## 3. Vincoli della piattaforma WoW Forever

### 3.1 Fatti accertati

| Aspetto | Valore |
| --- | --- |
| Prodotto | World of Warcraft: Forever (Blizzard), uscito il 4 novembre 2026 |
| Versione client | Patch 1.60.1 (build 69913). Include le modifiche "Modern" fino alla 12.1.5 (UI e API dell'era *Midnight*) |
| TOC | `## Interface: 16001`. Il client accetta `AzerothPrestige_Forever.toc` (alias `_Camelot`), famiglia *mainline*; il progetto usa `AzerothPrestige.toc` come Azeroth Accord ([ADR 0002](../adr/0002-wow-forever-target-and-api-dump.md)), da confermare in M0 |
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

Ogni voce va testata sul client live con l'addon di prova `AzPr_Probe` (`tools/probe/`, mai distribuito, comandi `/azpp`). La [specifica del probe](../spike/README.md) (in inglese) dà per ogni voce le chiamate e gli eventi esatti (segnalando quelli assenti dal dump delle API), i contesti in cui eseguirla, i criteri go / revise e le spec che cambiano con l'esito, oltre ai comandi e al formato dei record. L'esito va annotato in `docs/spike/M0-results.md` (milestone M0, [roadmap](../roadmap/M0-spike.md)).

| # | Verifica | Impatto se negativa |
| --- | --- | --- |
| V1 | `ENCOUNTER_END` (encounterID, name, difficultyID, groupSize, success) arriva con valori **non secret** | Delver va riprogettato (fallback: `BOSS_KILL`, loot, `CHAT_MSG_SYSTEM`) |
| V2 | `UnitName` / `UnitGUID` dei giocatori su nameplate e tooltip **non secret**, dentro e fuori istanza | Niente lookup dei badge nei contesti ristretti |
| V3 | `C_NamePlate.GetNamePlateForUnit` e `IsForbidden()` sulle nameplate amiche in istanza | Fallback nameplate |
| V4 | `SendAddonMessage` su `CHANNEL` di un canale custom: limiti, throttle, cross-faction | Strategia di discovery ([§12.3](SPEC-06-network-protocol.md)) |
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
| `Boost` | Stato BOOSTED (trigger G, A1–A4), finestre di attività, flag per quest ed encounter ([§8.6](SPEC-02-progression-scoring.md)) |
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
│  ├─ AzerothPrestige.toc
│  ├─ embeds.xml
│  ├─ Libs/                          # LibStub, CallbackHandler, Ace3 (AceAddon, AceEvent, AceConsole,
│  │                                 # AceLocale, AceComm), ChatThrottleLib, LibDataBroker, LibDBIcon,
│  │                                 # (LibSerialize, LibDeflate)
│  ├─ Locales/  Locales.xml enUS.lua itIT.lua ...   # una lingua = un file (ADR 0010)
│  ├─ Core/     Core.xml Init.lua Features.lua Log.lua EventBus.lua Compat.lua Scheduler.lua
│  │            Restrictions.lua Hash.lua Config.lua Diagnostics.lua Commands.lua      # §9.7
│  ├─ Data/     Ladder.lua Ruleset_v1.lua Encounters.lua Quests.lua Zones.lua Secrets.lua
│  ├─ Domain/   Ruleset.lua Scoring.lua Boost.lua Ledger.lua ProfileStore.lua Attestation.lua Leaderboard.lua
│  ├─ Trackers/ Vanguard.lua Delver.lua Pathfinder.lua Adventurer.lua
│  │            Diplomat.lua Artisan.lua Merchant.lua Steward.lua Backfill.lua
│  ├─ Network/  Codec.lua Comm.lua Router.lua Discovery.lua Sync.lua
│  ├─ Celebrations/ Queue.lua Conditions.lua PanelView.lua CinematicView.lua Sounds.lua
│  ├─ Badges/   Provider.lua Nameplates.lua Tooltip.lua Chat.lua UnitMenu.lua GroupFrames.lua
│  ├─ UI/       MainFrame.lua ProfileView.lua LeaderboardView.lua HallOfPrestige.lua
│  │            HistoryView.lua Settings.lua Minimap.lua
│  ├─ API/      Public.lua
│  └─ Media/    Badges/*.tga  Categories/*.tga  Frames/*.tga  Sounds/*.ogg  Fonts/
├─ Tests/                            # lupa + client finto (ADR 0011)
├─ tools/                            # controlli, spedizione degli step, media, mockup, probe
├─ docs/
│  ├─ specs/  adr/  roadmap/  wiki/  checklists/
│  └─ spike/M0-results.md
└─ .pkgmeta                          # BigWigs packager (CurseForge/Wago)
```

### 9.4 TOC

```toc
## Interface: 16001
## Title: Azeroth Prestige
## Notes: Prestige ranks, badges & leaderboards for WoW Forever
## Notes-itIT: Rank, badge e classifiche di prestigio per WoW Forever
## Author: Finland6738
## Version: @project-version@
## SavedVariables: AzerothPrestigeDB
## SavedVariablesPerCharacter: AzerothPrestigeCharDB
## IconTexture: Interface\AddOns\AzerothPrestige\Media\logo_64
## Category: Achievements
## X-License: GPL-3.0-or-later (code); artwork all rights reserved, see LICENSING.md
# ## X-Curse-Project-ID: 0   (Q15: GitHub only until the owner decides)

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
| Ace3 (AceAddon, AceEvent, AceConsole, AceLocale; AceComm da M4) | Struttura, eventi, comandi, localizzazione, messaggi multi-parte | Standard de facto. **AceDB non viene caricato**: `Core/Config.lua` gestisce direttamente le due tabelle salvate, come in Accord ([ADR 0006](../adr/0006-embedded-ace3-savedvariables-and-schema-versions.md), aggiornamento M1.1) |
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

### 9.7 Moduli di M1 e interfacce pubbliche

Scritto nello step M1.1, prima del codice: ogni step da M1.2 a M1.10 implementa la sua parte di questa sezione. Uno step che deve cambiare una firma aggiorna questa sezione nella stessa pull request. Le parti che dipendono dai risultati del probe di M0, non ancora arrivati, sono marcate 🔍: lo step M0.9 e quelli successivi le correggono se il probe le smentisce.

**Convenzioni comuni**

- Ogni file inizia con `local ADDON, ns = ...`. Il modulo è una tabella `ns.<Nome>`, registrata anche in `ns.modules.<Nome>` (per i test e per `/azp debug`). In M1 l'addon **non crea globali**: le sole globali sono le due SavedVariables. La globale `AzerothPrestige` arriva con l'API pubblica in M7, dietro lo switch `api` (§9.9).
- Le funzioni senza stato si chiamano con il punto (`Scoring.Rank(pp)`), quelle che usano lo stato del modulo con i due punti (`Ledger:Append(ev)`), come in Azeroth Accord.
- **Moduli puri**: `Core/Hash`, `Data/*`, `Domain/Ruleset`, `Domain/Scoring` e i nuclei di `Domain/Boost` e `Domain/Ledger` non toccano le API di WoW né `_G`, e ricevono il tempo come argomento (`now`, `t`). Le parti che ascoltano il gioco sono gli adattatori `:Start()`, che leggono il client solo tramite `Compat` e `Restrictions`.
- Una funzione pubblica **non solleva mai errori** per un input sbagliato: restituisce `nil` (o `false`) e un motivo, un codice breve in `UPPER_SNAKE` (`"DUP"`, `"READONLY"`).
- Ogni modulo con stato ha `:DebugLines()`, che restituisce righe in inglese senza nomi di giocatori per `/azp debug` ([ADR 0010](../adr/0010-interface-and-documentation-languages.md) punto 7).
- Avvio: ogni adattatore registra la sua funzione con `ns.OnEnable(fn)`. `Core/Init.lua` le chiama al `PLAYER_LOGIN`, nell'ordine del TOC, ciascuna in `pcall`, poi emette `CORE_READY`.

**Ordine di caricamento** (TOC di §9.4; il TOC elenca solo i file XML che esistono, e `tools/check_addon.py` lo controlla):

```
embeds.xml                LibStub, CallbackHandler, AceAddon, AceEvent, AceConsole, AceLocale
Locales\Locales.xml       enUS.lua, itIT.lua
Core\Core.xml             Init, Features, Log, EventBus, Compat, Scheduler, Restrictions, Hash, Config,
                          Diagnostics, Commands
Data\Data.xml             Ladder, Ruleset_v1
Domain\Domain.xml         Ruleset, Scoring, Boost, Ledger
```

**Ciclo di vita**

1. `ADDON_LOADED` → `addon:OnInitialize()` → `Config:Load()` (migrazioni, sola lettura) → `CONFIG_LOADED`.
2. `PLAYER_LOGIN` → `addon:OnEnable()` → controllo Forever (avviso `WARN_NOT_FOREVER` una volta) → `Config:RegisterCharacter(now)` → le funzioni di avvio (`Restrictions:Start`, `Boost:Start`, `Ledger:Start`, …) → `CORE_READY`.
3. `Ledger:Start` rinvia di 10 s la compattazione (§17).

| Step | Modulo | File | Responsabilità |
| --- | --- | --- | --- |
| M1.2 | `Init` | `Core/Init.lua` | Oggetto addon, controllo Forever, `/prestige` e `/azp` con il registro dei sottocomandi e `help` |
| M1.2 | `Features` | `Core/Features.lua` | Switch delle funzioni non finite (§9.9) |
| M1.2 | Localizzazioni | `Locales/*.lua` | Tabelle AceLocale con le stesse chiavi (§9.10) |
| M1.4 | `Log` | `Core/Log.lua` | Log a livelli in un buffer circolare |
| M1.4 | `Bus` | `Core/EventBus.lua` | Pub/sub interno (§9.8) |
| M1.4 | `Compat` | `Core/Compat.lua` | Unica porta verso le API del gioco |
| M1.4 | `Scheduler` | `Core/Scheduler.lua` | Timer `C_Timer`, mai `OnUpdate` permanenti |
| M1.4 | `Restrictions` | `Core/Restrictions.lua` | Stato delle restrizioni, `SafeGet`, rinvio fuori combattimento |
| M1.5 | `Config` | `Core/Config.lua` | SavedVariables, schema 1, migrazioni, sola lettura, `myChars` ([SPEC-04 §10](SPEC-04-data-model.md)) |
| M1.6 | `Ladder` | `Data/Ladder.lua` | Categorie, 22 tier × 4 divisioni, apex |
| M1.6 | `Scoring` | `Domain/Scoring.lua` | Funzioni pure di §6.4 e §8.1 |
| M1.7 | `Ruleset` | `Domain/Ruleset.lua`, `Data/Ruleset_v1.lua` | Ruleset versionati ([SPEC-04 §10.7](SPEC-04-data-model.md)) |
| M1.8 | `Hash` | `Core/Hash.lua` | SHA-256 per l'`eventId` |
| M1.8 | `Ledger` | `Domain/Ledger.lua` | Append idempotente, compattazione, ricalcolo, promozioni |
| M1.9 | `Boost` | `Domain/Boost.lua` | Stato BOOSTED e verdetti di §8.6 |
| M1.10 | `Diagnostics` | `Core/Diagnostics.lua` | Report di `/azp debug`, errori dell'addon |
| M1.10 | `Commands` | `Core/Commands.lua` | `/azp stats`, `/azp debug`, `/azp sim` |

#### 9.7.1 `Core/Init.lua` (M1.2)

```lua
ns.addon                                   -- oggetto AceAddon "AzerothPrestige" (mixin AceConsole-3.0, AceEvent-3.0)
ns.L                                       -- tabella AceLocale della lingua del client (fallback enUS)
ns.OnEnable(fn)                            -- registra la funzione di avvio di un modulo
addon:IsForever() -> bool                  -- WOW_PROJECT_ID == WOW_PROJECT_CAMELOT (costante assente dal dump, ADR 0002) 🔍
addon:Version() -> string                  -- la versione del TOC; "dev" in un checkout
addon:Print(text)                          -- una riga in chat con il prefisso dell'addon
addon:RegisterCommand(name, fn, helpKey, opts)   -- sottocomando di /azp e /prestige; fn(args) con args = elenco di parole;
                                           -- opts.dev = true: solo nelle build di sviluppo (Config.DEV, Q22)
addon:OnSlashCommand(input)                -- primo token in minuscolo = sottocomando; vuoto o "help" → PrintHelp
addon:PrintHelp()                          -- i comandi disponibili, ciascuno con L[helpKey]; quelli dev solo in sviluppo
addon:AddDebugSection(title, linesFn)      -- una sezione del report di /azp debug
```

Un sottocomando sconosciuto risponde `CMD_UNKNOWN`; un comando `dev` fuori dalle build di sviluppo risponde `CMD_DEV_ONLY`.

#### 9.7.2 `Core/Features.lua` (M1.2)

```lua
Features.On(name) -> bool    -- true se lo switch `name` è acceso, o lo è uno switch che lo implica; false per un nome sconosciuto
Features.IMPLIES             -- { [name] = { switch che, accesi, accendono anche `name` } }
Features.Names() -> list     -- tutti gli switch in ordine alfabetico (test, /azp debug)
```

I valori sono costanti della build: nessun comando li cambia in gioco. I test li cambiano direttamente nella tabella.

#### 9.7.3 `Core/Log.lua` (M1.4)

```lua
Log.Debug(area, fmt, ...)   Log.Info(area, fmt, ...)   Log.Warn(area, fmt, ...)   Log.Error(area, fmt, ...)
Log.Lines(n, minLevel) -> list   -- le ultime n righe (buffer circolare di 200) dal livello minLevel in su
Log.Counts() -> { debug, info, warn, error }
Log.echo                         -- true: le righe compaiono anche in chat (default: Config.DEV)
```

`area` è il nome del modulo (`"Ledger"`), `fmt` una stringa inglese per `string.format`. Chi scrive nel log non mette mai nomi di giocatori: solo id, `ruleId`, conteggi. `Log.Error` passa anche il testo a `Diagnostics.Record`.

#### 9.7.4 `Core/EventBus.lua` (M1.4)

```lua
ns.Bus:On(event, fn) -> bool          -- la stessa funzione si registra una volta sola per evento
ns.Bus:Off(event, fn) -> bool         -- fn nil: toglie tutti i listener dell'evento
ns.Bus:Emit(event, ...) -> n          -- chiama i listener in ordine, ciascuno in pcall; n = quelli senza errore
ns.Bus:ListenerCount(event) -> n
ns.Bus:DebugLines()
ns.Bus.EVENTS                         -- { [nome] = true }: gli eventi di §9.8
```

`On` o `Emit` con un nome fuori da `Bus.EVENTS` scrive un `Log.Warn`; nei test è un errore. L'errore di un listener non ferma gli altri e finisce nel report di debug.

#### 9.7.5 `Core/Compat.lua` (M1.4)

L'unica porta verso le API del gioco. Ogni chiamata è protetta: un'API mancante, che va in errore o che restituisce un valore *secret* spegne una funzione, mai l'addon. Le API marcate 🔍 passano da `pcall`. I test controllano che ogni nome della tabella `Compat.API` sia nel dump, a parte quelli segnati come assenti.

```lua
Compat.Resolve(path) -> value | nil         -- "C_ChatInfo.InChatMessagingLockdown" → la funzione o nil, senza errori
Compat.Call(path, ...) -> state, ...        -- state: "available" | "missing" | "error" | "restricted"; ogni valore secret → nil
Compat.IsSecret(v) -> bool                  -- issecretvalue, letto a ogni chiamata
Compat.Readable(v) -> bool                  -- canaccessvalue (o non secret)

Compat.Player.Name()  Compat.Player.Realm()   -- realm da GetNormalizedRealmName()
Compat.Player.CharKey() -> "Nome-Realm" | nil
Compat.Player.GUID()  .Level()  .MaxLevel()  .ClassID()  .Faction()   -- Faction: "A" | "H"
Compat.Player.IsTrial() -> bool | nil       -- IsTrialAccount() o IsVeteranTrialAccount(); nil se non si sa

Compat.Client.Locale()  .Build()  .Interface()
Compat.Client.RealmType() -> "normal" | "pvp" | "rp" | "rppvp" | "hardcore" | nil     -- 🔍 V17

Compat.Group.InGroup()  .InRaid()
Compat.Group.Units() -> list                -- "party1".."party4" o "raid1".."raid40", senza il giocatore
Compat.Group.MemberLevels() -> list         -- un elemento per membro: livello, -1 ("??") o false (secret, ignoto) 🔍 V19

Compat.Unit.Level(unit)  .IsPlayer(unit)  .IsUnit(a, b)  .InMyGroup(unit)  .AffectingCombat(unit)  -- nil se secret 🔍 V21
Compat.NamePlates.Units() -> list           -- i token "nameplateN" attivi
Compat.Auras.HelpfulOnPlayer() -> list      -- { auraInstanceID, sourceUnit o nil } per aura 🔍 V20
Compat.Instance.Info() -> inInstance, instanceType   -- "none" | "party" | "raid" | "pvp" | "arena" | "scenario"

Compat.Time.Server() -> secondi UTC         -- GetServerTime()
Compat.Time.Monotonic() -> secondi          -- GetTime()
Compat.Time.RealmDate() -> { year, month, day }   -- calendario del realm (C_DateAndTime.GetCurrentCalendarTime 🔍),
                                            -- altrimenti la data UTC di Time.Server()
Compat.Timer.After(s, fn) -> handle | nil   Compat.Timer.NewTicker(s, fn) -> handle | nil   -- usati solo da Scheduler
Compat.Chat.Line(text)                      -- una riga nella chat frame di default
Compat.API                                  -- { { id, path, note } }: le API usate, per il controllo sul dump
```

#### 9.7.6 `Core/Scheduler.lua` (M1.4)

```lua
Scheduler.After(seconds, fn, tag) -> handle | nil    -- una volta
Scheduler.Every(seconds, fn, tag) -> handle | nil    -- ripetuto, fermato da Cancel
Scheduler.Debounce(tag, seconds, fn)                 -- un solo timer per tag: una nuova chiamata sposta la scadenza
Scheduler.Cancel(handle)   Scheduler.CancelTag(tag)
Scheduler.Count() -> n                               -- timer attivi
Scheduler:DebugLines()
```

Solo `C_Timer` tramite `Compat.Timer`, mai `OnUpdate` permanenti (§17). Ogni callback gira in `pcall`; un errore va in `Log.Error`. Se il client non ha timer le funzioni restituiscono `nil` e il chiamante fa a meno della funzione.

#### 9.7.7 `Core/Restrictions.lua` (M1.4)

```lua
Restrictions:Start()
Restrictions.State() -> { combat, encounter, chatLockdown, restrictedMap, instanceType, trial }   -- una copia
Restrictions.InCombat()  .InEncounter()  .ChatLockdown()  .RestrictedMap()  .IsTrial()
Restrictions.SafeGet(fn, ...) -> ...        -- i valori di fn(...) in pcall: ogni valore secret diventa nil, un errore dà nil
Restrictions.OutOfCombat(tag, fn)           -- subito fuori dal combattimento, altrimenti al PLAYER_REGEN_ENABLED (una per tag)
Restrictions:DebugLines()
```

- Eventi ascoltati: `PLAYER_REGEN_DISABLED`/`ENABLED`, `ENCOUNTER_START`/`END`, `PLAYER_ENTERING_WORLD`, `ZONE_CHANGED_NEW_AREA`, `ADDON_RESTRICTION_STATE_CHANGED` 🔍 V5.
- `restrictedMap` è vero in dungeon e raid (`instanceType` `party` o `raid`); se valga anche nei battleground lo dice V5 🔍.
- Il chat lockdown non ha un evento affidabile 🔍 V5: mentre combattimento, encounter, mappa ristretta o lockdown sono attivi, un ticker di 1 s rilegge `C_ChatInfo.InChatMessagingLockdown()` e si ferma quando tutto torna falso.
- Ogni cambio emette `RESTRICTIONS_CHANGED(key, value)`.
- `Compat` usa la stessa logica di `SafeGet` per le API che espone: il codice fuori da `Compat` non chiama mai il client direttamente (§9.6).

#### 9.7.8 `Core/Config.lua` (M1.5)

```lua
Config.SCHEMA = 1
Config.VARIABLES = { account = "AzerothPrestigeDB", char = "AzerothPrestigeCharDB" }
Config.DEV                                  -- true in un checkout, false nei pacchetti (blocco --@debug@ del packager)
Config.defaults, Config.migrations          -- SPEC-04 §10.1, §10.2, §10.6
Config:Load() -> ok                         -- ADDON_LOADED: entrambe le variabili; emette CONFIG_LOADED(readOnly)
Config:IsReadOnly(scope) -> bool            -- "account", "char", o nil = almeno una delle due
Config:Account()   Config:Char()            -- le tabelle di lavoro (copie, se in sola lettura)
Config:Get(path)                            -- "char.settings.featuredCategory"
Config:Set(path, value) -> ok, reason       -- emette CONFIG_CHANGED(path); "READONLY", "BAD_PATH", "BAD_VALUE"
Config.CharKey(name, realm) -> "Nome-Realm" | nil
Config:MyCharKey()
Config:RegisterCharacter(now)               -- PLAYER_LOGIN: myChars, guid, firstSeen/lastSeen, charKey e createdAt del CharDB
Config:IsMyChar(charKeyOrGuid) -> bool      -- regola anti-alt (§8.5)
Config.issues                               -- i problemi trovati al caricamento (inglese, senza nomi)
Config.EstimateSize(value) -> byte          -- stima delle dimensioni salvate (/azp stats, /azp debug)
Config:DebugLines()
```

#### 9.7.9 `Data/Ladder.lua` (M1.6)

```lua
Ladder.CATEGORIES = { "VAN", "DEL", "PAT", "ADV", "DIP", "ART", "MER", "STE" }   -- ordine fisso, anche di `pts` nei profili
Ladder.CATEGORY_NAMES = { VAN = "Vanguard", DEL = "Delver", ... }   -- nomi propri, non tradotti (ADR 0010 punto 3)
Ladder.TIERS = { { id = "WOOD", name = "Wood" }, ..., { id = "DRAGONITE", name = "Dragonite" } }   -- 22
Ladder.DIVISIONS = { "IV", "III", "II", "I" }    -- IV = ingresso, I = vertice (Q2)
Ladder.STEPS = 88   Ladder.GLOBAL_FACTOR = 4   Ladder.SEATS = 100
Ladder.APEX = { { id = "MASTER", name = "Master", min = 263460 }, ..., { id = "LEGEND", name = "Legend", min = 1000000 } }
                                                 -- dal più basso al più alto; soglia di Legend: Q11
Ladder.Threshold(step, global) -> PP         -- soglia dello step 1..88 con la formula di §6.3 (× 4 se global)
Ladder.StepOf(pp, global) -> 1..88
Ladder.StepInfo(step) -> tierIndex, divisionIndex, tierId
Ladder.ApexFor(pp, global) -> list           -- gli id apex con soglia ≤ pp (i posti si assegnano in M6)
Ladder.SILVER_IV_STEP = 29                   -- per il bonus varietà di §6.4
```

Lo step 1 è Wood IV (soglia 0), lo step 88 è Dragonite I. `peak` salva gli step ([SPEC-04 §10.1](SPEC-04-data-model.md)).

#### 9.7.10 `Domain/Scoring.lua` (M1.6)

```lua
Scoring.Rank(pp, global) -> { step, tier, division, threshold, nextThreshold, toNext }   -- nextThreshold nil a Dragonite I
Scoring.GlobalPrestige(points) -> gp, n      -- §6.4: floor(Σ PP × (1 + 0.05 × n)), n = categorie con PP ≥ Silver IV
Scoring.LowLevelDivisor(pl, l, gap) -> d     -- pl − l se ≥ gap, altrimenti 1 (§8.7)
Scoring.DR(occurrence, steps) -> m           -- 1ª = 1, 2ª = 0.75, 3ª = 0.5, 4ª = 0.25, dalla 5ª 0.10 (§8.2)
Scoring.EventPoints(rule, raw, ctx, s) -> pp, why   -- la catena di §8.1 (SPEC-04 §10.7);
                                             -- s = { voidWhy, occurrence, counted, capUsed }, why nil se i punti contano
```

#### 9.7.11 `Domain/Ruleset.lua` e `Data/Ruleset_v1.lua` (M1.7)

```lua
ns.Rulesets[rv] = { rv, format, constants, rules }   -- formato in SPEC-04 §10.7
Ruleset.Current() -> rv                       -- il più alto caricato: vale per gli eventi nuovi
Ruleset.Get(rv) -> ruleset | nil
Ruleset.Rule(rv, ruleId) -> rule | nil
Ruleset.Points(rv, ruleId, ctx) -> raw, reason   -- raw ≥ 0, anche decimale; 0 e "UNKNOWN_RV" | "UNKNOWN_RULE" | "OFF" | "BAD_POINTS"
Ruleset.Constant(rv, name)                    -- APEX_MIN_VR (Q10), DR, LOW_LEVEL_GAP
Ruleset.RuleIds(rv) -> list                   -- in ordine alfabetico
Ruleset.Validate(ruleset) -> problems         -- vuoto = valido; usato dai test
Ruleset.Derive(baseRv, rv, changes) -> ruleset   -- copia profonda della base con le modifiche; la base non cambia
```

Una regola sconosciuta o una `rv` sconosciuta danno 0 punti e una riga di `Log.Warn`, mai un errore; l'evento resta nel ledger.

#### 9.7.12 `Core/Hash.lua` (M1.8)

```lua
Hash.SHA256(msg) -> 32 byte | nil, reason    -- FIPS 180-4, con la libreria `bit` del client
Hash.ToHex(bytes)   Hash.SHA256Hex(msg)
Hash.Short(msg, n) -> hex                    -- i primi n caratteri esadecimali (default 8) di SHA-256(msg)
Hash.Fast(s) -> intero a 32 bit              -- non crittografico: solo per i digest di rete (M4)
```

#### 9.7.13 `Domain/Ledger.lua` (M1.8)

```lua
Ledger.EventId(charKey, ruleId, k, t, once) -> 16 hex    -- SPEC-04 §10.5
Ledger.Subject(k) -> string                  -- la parte di k prima di "#"
Ledger.DayIndex(date) -> dy                  -- giorni dal 1970-01-01 della data { year, month, day }
Ledger.WeekIndex(dy) -> wk                   -- settimana che inizia il lunedì (Q23)
Ledger:Start()                               -- indici in memoria dal CharDB; compattazione dopo 10 s
Ledger:Record(ruleId, k, c, opts) -> ev | nil, reason
                                             -- per i tracker: t = Compat.Time.Server(), rv = Ruleset.Current(),
                                             -- c.pl e c.gmx da Boost, c.dy se la regola ha una finestra, why di boost e
                                             -- anti-alt; opts = { t, tl (default 1, §11.2), w, src }
Ledger:Append(ev) -> ok, reason              -- un evento completo (test, backfill); reason: "DUP" | "ONCE" | "READONLY" |
                                             -- "STALE" | "BAD_EVENT"
Ledger:Recompute() -> points                 -- da compact + ledger; non abbassa mai points né peak (SPEC-04 §10.6)
Ledger:Compact(now) -> moved                 -- SPEC-04 §10.3
Ledger:Points()   Ledger:Peak()              -- copie
Ledger:GP() -> gp, n
Ledger:IsConsumed(ruleId, subject) -> bool   -- già nel set oneTime
Ledger:Iterate(filter) -> iteratore          -- eventi dal più recente; filter = { cat, ruleId, why }
Ledger:Size() -> { events, compact, oneTime, bad }
Ledger:Digest() -> { n, h }                  -- n = eventi + chiavi di compact, h = Hash.Short degli id e dei pp in ordine;
                                             -- il formato di rete è di M4.1 (SPEC-06)
Ledger:DebugLines()
```

Dopo ogni aggiunta accettata: `LEDGER_APPENDED`, poi `POINTS_CHANGED` per la categoria (se i punti cambiano), poi `PROMOTION` per ogni step nuovo oltre `peak`, della categoria e del Global. In sola lettura `Record` e `Append` rispondono `READONLY` e non contano nulla; il giocatore lo legge una volta per sessione (`WARN_READ_ONLY`).

#### 9.7.14 `Domain/Boost.lua` (M1.9)

```lua
-- nucleo puro
Boost.LEVEL_GAP = 10   Boost.ASSIST_WINDOW = 60 (Q12)   Boost.SCAN_HZ = 2   Boost.SCAN_MAX_LEVEL = 50
Boost.New() -> state
Boost.GroupTrigger(pl, levels) -> bool       -- G: un membro con livello ≥ pl + 10 o -1 (🔍 V19); mai con pl ≥ 51
Boost.Signal(state, trigger, now)            -- A1, A2, A3: attivo fino a now + ASSIST_WINDOW
Boost.IsBoosted(state, now) -> bool, trigger
Boost.WasBoosted(state, from, to) -> bool, trigger   -- dagli intervalli registrati (encounter: da START a END)
Boost.Verdict(state, rule, ev, span) -> why | nil    -- "BOOST:G" | "BOOST:A1" … "BOOST:A4", secondo rule.boost (§8.6.2)
Boost.ContextFields(pl, levels) -> pl, gmx   -- gmx = il livello più alto del gruppo (pl da solo, -1 se c'è un "??")

-- adattatore
Boost:Start()                                -- GROUP_ROSTER_UPDATE, UNIT_LEVEL, PLAYER_LEVEL_UP, PLAYER_REGEN_DISABLED/ENABLED,
                                             -- UNIT_AURA("player"), QUEST_LOG_UPDATE, UNIT_QUEST_LOG_CHANGED, UPDATE_FACTION;
                                             -- scansione A1/A2 a 2 Hz solo in combattimento, fuori dalle istanze, pl ≤ 50
Boost:Now() -> bool, trigger
Boost:Context() -> { pl, gmx }               -- i campi di contesto di ogni evento
Boost:Span(from, to) -> bool, trigger        -- WasBoosted sullo stato corrente
Boost:QuestTainted(questID) -> bool          -- un obiettivo è avanzato mentre eri BOOSTED
Boost:RepTainted(factionID) -> bool
Boost:ClearQuest(questID)                    -- dopo il turn-in o l'abbandono
Boost:TradeFrom(level) -> why | nil          -- A4
Boost:DebugLines()
```

Gli intervalli BOOSTED e i flag di quest e reputazione sono salvati nel CharDB (`boost`, [SPEC-04 §10.1](SPEC-04-data-model.md)), così sopravvivono a `/reload` e logout. Ogni cambio di stato emette `BOOST_CHANGED(boosted, trigger)`.

#### 9.7.15 `Core/Diagnostics.lua` e `Core/Commands.lua` (M1.10)

```lua
Diagnostics.Install()                        -- raccoglie gli errori Lua dei file dell'addon (buffer di 10)
Diagnostics.Record(message)   Diagnostics.Errors()   Diagnostics.ClearErrors()
Diagnostics.CleanError(message) -> text      -- senza cartelle del PC, una riga, lunghezza massima
Diagnostics.Redact(text) -> text             -- i charKey noti (myChars, testimoni) diventano <name>
Diagnostics.Collect() -> sections            -- le sezioni di addon:AddDebugSection
Diagnostics.Report() -> text                 -- testo inglese, non tradotto (ADR 0010 punto 7)
Diagnostics.Show()                           -- un riquadro semplice da copiare (il tema arriva in M3)
```

| Comando | Cosa fa | Chi |
| --- | --- | --- |
| `/azp`, `/azp help` | Elenco dei comandi | tutti (M1.2) |
| `/azp stats` | Per categoria: rank, PP, PP alla divisione successiva; GP e `N`; eventi del ledger, chiavi di `compact` e dimensione stimata dei SavedVariables (§10.3) | tutti |
| `/azp debug` | Report: versione, client, Interface, locale, tipo di realm, restrizioni, switch, schemi e sola lettura, dimensioni, stato BOOSTED, listener del bus, timer, ultimi avvisi ed errori. Nessun nome | tutti |
| `/azp sim <ruleId> [n]` | `n` eventi (1–50, default 1) della regola, con il contesto `sample` della regola, `tl = 0`, `src = "SIM"`, mai trasmessi | solo build di sviluppo (Q22) |
| `/azp sim clear` | Toglie dal ledger gli eventi `SIM` e ricalcola | solo build di sviluppo (Q22) |

### 9.8 Eventi del bus interno (M1)

Regole: nome in `UPPER_SNAKE`, nella forma `<AREA>_<FATTO>` al passato; argomenti posizionali, valori semplici o tabelle salvate da **non modificare**; gli eventi di gioco non passano dal bus (gli adattatori li ricevono con AceEvent). Uno step che aggiunge un evento lo aggiunge a questa tabella e a `Bus.EVENTS`.

| Evento | Argomenti | Emesso da | Ascoltato da (M1, poi) |
| --- | --- | --- | --- |
| `CONFIG_LOADED` | `readOnly` (bool) | `Config:Load` | `Ledger`, `Diagnostics` |
| `CONFIG_CHANGED` | `path` | `Config:Set` | UI (M3) |
| `CORE_READY` | — | `Init`, dopo le funzioni di avvio | `Commands`; tracker (M2), rete (M4) |
| `RESTRICTIONS_CHANGED` | `key`, `value` (`key`: `combat`, `encounter`, `chatLockdown`, `restrictedMap`, `trial`) | `Restrictions` | `Boost`; coda di invio (M4), celebrazioni (M3) |
| `BOOST_CHANGED` | `boosted`, `trigger` | `Boost` | avviso di [§14.8](SPEC-08-ui-badges.md) (M3) |
| `LEDGER_APPENDED` | `ev` | `Ledger` | cronologia (M3), attestazioni (M4) |
| `LEDGER_REJECTED` | `reason`, `ruleId` | `Ledger` | `Diagnostics` (contatori) |
| `POINTS_CHANGED` | `cat`, `old`, `new` | `Ledger` | profilo e `profileVersion` (M4), UI (M3) |
| `PROMOTION` | `cat` (o `"GP"`), `fromStep`, `toStep`, `t` | `Ledger` | celebrazioni (M3) |
| `LEDGER_RECOMPUTED` | `points` | `Ledger:Recompute` | UI (M3) |
| `LEDGER_COMPACTED` | `moved` | `Ledger:Compact` | `Diagnostics` |

Le callback dell'API pubblica di §19.2 (`PROMOTION`, `PROFILE_UPDATED`, `LEGEND_CHANGED`) sono un'altra cosa: arrivano in M7 e si appoggiano a questi eventi.

### 9.9 Feature switch

`AzerothPrestige/Core/Features.lua` ([ADR 0017](../adr/0017-feature-switches.md)) nasce in M1.2 con **tutti gli switch spenti**. M1 non ne ha: comandi, ledger, scoring e anti-boost fanno parte di `v0.1.0` e non hanno nulla di visibile da nascondere. Ogni milestone accende i suoi switch nel suo ultimo step; lo step di preparazione al rilascio controlla che quelli delle milestone successive siano spenti, e `Tests/test_features.lua` prova i due stati.

| Switch | Milestone | Cosa copre (spento: niente eventi registrati, niente scritto, inviato o mostrato) |
| --- | --- | --- |
| `delver` · `adventurer` · `pathfinder` · `artisan` | M2 | Il tracker della categoria |
| `backfill` | M2 | L'import alla prima installazione (§7.9) |
| `ui` | M3 | Finestra, profilo, cronologia, impostazioni, minimappa |
| `celebrations` | M3 | Coda e presentazione delle promozioni; spento, `Ledger` non scrive `celebrationQueue` |
| `network` | M4 | Codec, invio e ricezione, discovery, attestazioni, `ProfileStore` |
| `badges` | M4 | I provider di badge |
| `vanguard` · `merchant` · `diplomat` · `steward` | M5 | Il tracker della categoria |
| `hardcore` | M5 | Memoriale Hardcore e sigillo "Caduto" |
| `leaderboards` | M6 | Classifiche, `RLY`, `LBD`, snapshot |
| `apex` | M6 | Posti apex, albo dei titoli, Hall of Prestige |
| `api` · `contracts` · `adapters` · `lists` | M7 | API pubblica, Prestige Contracts, adapter per altri addon, liste gilda e amici |

`Features.IMPLIES` (proposta, confermata dallo step `.1` della milestone): `network` è acceso anche quando lo sono `badges`, `leaderboards` o `contracts`; `leaderboards` anche quando lo è `apex`.

### 9.10 Localizzazione: chiavi

- Una chiave è ASCII in `UPPER_SNAKE`, nella forma `<AREA>_<NOME>`. Aree di M1: `ADDON_` (titolo), `WARN_` (avvisi), `HELP_<COMANDO>` (una riga di aiuto per comando), `CMD_` (risposte dei comandi), `STATS_` (righe di `/azp stats`), `CAT_<ID>_DESC` (descrizione della categoria), `WHY_<MOTIVO>` (motivo di un evento a 0 punti, ad esempio `WHY_BOOST_G`). Le milestone successive aggiungono le loro aree (`UI_`, `CEL_`, `BADGE_`, `NET_`, …) nello step `.1`.
- `Locales/enUS.lua` crea la tabella con `NewLocale(ADDON, "enUS", true)`: è la base e il fallback. `Locales/itIT.lua` usa `NewLocale(ADDON, "itIT")` e ha **le stesse chiavi nello stesso ordine**, con gli stessi commenti di sezione. Ogni valore è una stringa esplicita, mai `true`.
- Segnaposto: solo `%s` e `%d`, nello stesso numero, tipo e ordine in tutte le lingue. Nessun codice colore nei testi (i colori sono del tema, M3).
- Il codice legge `L["CHIAVE"]` con chiavi letterali. Le sole chiavi composte sono le famiglie `CAT_<ID>_DESC` (le 8 categorie) e `WHY_<MOTIVO>`, elencate in `Tests/test_locales.lua`.
- Nomi di categorie, tier e apex **non** sono chiavi: sono nomi propri inglesi in `Data/Ladder.lua` (ADR 0010 punto 3). Le divisioni restano numeri romani.
- Il report di `/azp debug` e il log non sono tradotti.
- Chiavi di M1 (gli step possono aggiungerne seguendo queste regole): `ADDON_TITLE`, `WARN_NOT_FOREVER`, `WARN_READ_ONLY`, `HELP_HEADER`, `HELP_HELP`, `HELP_STATS`, `HELP_DEBUG`, `HELP_SIM`, `CMD_UNKNOWN`, `CMD_DEV_ONLY`, `CMD_SIM_USAGE`, `CMD_SIM_UNKNOWN_RULE`, `CMD_SIM_DONE`, `CMD_SIM_CLEARED`, `STATS_HEADER`, `STATS_CATEGORY`, `STATS_CATEGORY_TOP`, `STATS_GLOBAL`, `STATS_LEDGER`, `CAT_VAN_DESC` … `CAT_STE_DESC`, `WHY_BOOST_G` … `WHY_BOOST_A4`, `WHY_ALT`, `WHY_CAP`, `WHY_LIMIT`, `WHY_OFF`, `WHY_UNKNOWN_RULE`.

### 9.11 File presi da Azeroth Accord

Copie indipendenti ([ADR 0013](../adr/0013-reuse-azeroth-accord-and-unspoken-foundations.md)): ogni file copiato dice nell'intestazione da dove viene. Accord si legge e non si modifica mai.

| File di Accord | File di Prestige | Step | Cosa cambia |
| --- | --- | --- | --- |
| `AzerothAccord/AzerothAccord.toc`, `embeds.xml` | `AzerothPrestige/AzerothPrestige.toc`, `embeds.xml` | M1.2 | Nomi e campi di §9.4; niente `Bindings.xml`, Compartment né `OptionalDeps`; `embeds.xml` carica solo le librerie di §9.7 (niente AceDB) |
| `Core/Init.lua` | `Core/Init.lua` | M1.2 | `/prestige` e `/azp`; registro dei sottocomandi con l'opzione `dev`; niente viste, binding né Compartment |
| `Core/Features.lua` | `Core/Features.lua` | M1.2 | Gli switch di §9.9; `On` e `IMPLIES` invariati, più `Names()` |
| `Locale/enUS.lua`, `itIT.lua` | `Locales/enUS.lua`, `itIT.lua`, `Locales.xml` | M1.2 | Cartella `Locales`; solo le chiavi di §9.10 |
| `tools/fetch_libs.py`, `install_addon.py`, `check_addon.py`, `check_package.py` | stessi nomi | M1.2 | Nomi dell'addon; `check_addon` controlla anche le chiavi delle due lingue e i file XML del TOC |
| `Tests/run_tests.py`, `Tests/lib/assert.lua`, `Tests/lib/harness.lua` | stessi nomi | M1.3 | Nome dell'addon e variabili d'ambiente `AZPRES_*`; niente `csv.lua` finché non serve |
| `Tests/mock/00_core`, `10_clock`, `20_frames`, `25_frames_more`, `30_timers`, `40_chat`, `60_client`, `65_group`, `66_classes`, `70_encoding` | stessi nomi | M1.3 | `40_chat`: messaggi addon con lockdown e throttle; `60_client`: locale, realm normalizzato, tipo di realm, trial; `65_group`: livelli dei membri (anche `-1` e secret); nuovo `90_secrets.lua` (secret values, `issecretvalue`, `canaccessvalue`, restrizioni forzate). Non si copiano gilda, club, calendario, LFG, professioni, banca, oggetti, borse e community: arrivano con i tracker che li usano (M2, M5) |
| `Tests/test_addon.lua`, `test_locales.lua`, `test_features.lua`, `test_mock.lua` | stessi nomi | M1.3 | Le regole di §9.10 e gli switch di §9.9 |
| `Core/Compat.lua` | `Core/Compat.lua` | M1.4 | Restano `Resolve`, `Call`, i secret values, `Player`, il tempo e i timer; si tolgono gilda, club, LFG, professioni, banca di gilda, calendario, BattleTag e canali; le restrizioni della chat passano a `Restrictions.lua`; si aggiungono `Client`, `Group.MemberLevels`, `Unit`, `NamePlates`, `Auras`, `Instance` (§9.7.5) |
| `Core/Bus.lua` | `Core/EventBus.lua` | M1.4 | Gli eventi di §9.8 e il controllo `Bus.EVENTS`; il resto identico |
| — (in Accord stanno dentro `Compat`) | `Core/Log.lua`, `Core/Scheduler.lua`, `Core/Restrictions.lua` | M1.4 | Nuovi, costruiti sulle funzioni di Accord per timer, restrizioni della chat e lockdown |
| `Core/Config.lua` | `Core/Config.lua` | M1.5 | Campo `schema` (non `schemaVersion`); le variabili e i default di SPEC-04 §10; niente token, tabelle per gilda né viste; `myChars` e `charKey`; regole di validazione degli eventi del ledger e tabella `bad`; caricamento, migrazioni, sola lettura e `--@debug@` identici |
| `Core/Hash.lua` | `Core/Hash.lua` | M1.8 | Restano `SHA256`, `ToHex`, `SHA256Hex`, `Short`, `Fast`; si tolgono HMAC e i byte casuali (nessun segreto in M1) |
| `Core/Diagnostics.lua` | `Core/Diagnostics.lua` | M1.10 | Le sezioni di §9.7.15; `Redact` usa `myChars` e i testimoni; un riquadro di copia semplice al posto del box del tema |

Non si copiano in M1: `Core/Demo.lua`, `Core/Role.lua`, `Data/*` di Accord, `Net/*` (Codec e trasporto arrivano in M4), il kit di interfaccia (M3) e il simulatore di rete `Tests/sim/` (M4).

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
- Nessun traffico di rete che degradi il servizio: throttle e budget ([§12](SPEC-06-network-protocol.md), §17).
- Distribuzione su CurseForge e Wago con BigWigs packager.

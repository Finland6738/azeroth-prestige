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
│  ├─ Libs/                          # LibStub, CallbackHandler, AceAddon, AceDB, AceComm,
│  │                                 # ChatThrottleLib, LibDataBroker, LibDBIcon, (LibSerialize, LibDeflate)
│  ├─ Locales/  enUS.lua  itIT.lua ...      # una lingua = un file (ADR 0010)
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

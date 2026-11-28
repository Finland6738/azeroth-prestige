# SPEC-02: Progressione e regole di punteggio

> Parte della [specifica di Azeroth Prestige](README.md). Nata dal documento unico v0.4 del 2026-11-26, diviso in file nel bootstrap: la numerazione delle sezioni (§) è quella del documento originale, così i rimandi restano validi in tutti i file. Legenda: ✅ confermato dal proprietario · 🟡 proposta valida fino a diversa decisione ([SPEC-11](SPEC-11-risks-open-questions.md)) · 🔍 da verificare in M0.

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

**Assegnazione dei posti "a cascata"**, valutata a ogni reset settimanale ([§13.3](SPEC-07-leaderboards-hall.md)):

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
- Il profilo ([§14.2](SPEC-08-ui-badges.md)) mostra l'**albo dei titoli** completo: ogni apex, con date e durata.

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
- Il formato del ruleset e la catena esatta, passo per passo (limiti `perKey` e `maxCount`, eventi annullati che non consumano DR né cap), sono in [SPEC-04 §10.7](SPEC-04-data-model.md).

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

La finestra di default è il giorno (reset alle 00:00 server time). Le finestre sono definite per regola nel ruleset: `day` o `week` (la settimana inizia il lunedì, proposta [Q23](SPEC-11-risks-open-questions.md)); l'evento salva l'indice del giorno `c.dy`, così DR e cap sono ricalcolabili ([SPEC-04 §10.7](SPEC-04-data-model.md)).

### 8.3 Group credit (dalla wiki)

- Ogni partecipante eleggibile riceve **i punti pieni**: non si dividono, non vanno al killer o al top DPS.
- Eleggibilità: nel gruppo, nella stessa istanza o area, non AFK, presente per ≥ 50% della durata dell'encounter (`ENCOUNTER_START` → `ENCOUNTER_END`).
- Si accetta il limite dichiarato dalla wiki: gruppi più grandi o contenuti più facili possono rendere più velocemente.

### 8.4 Idempotenza

- `eventId = hash(charKey, ruleId, contextKey, serverTimeBucket)`.
- Il bucket è di 60 s. Per le una tantum il `contextKey` basta da solo, senza componente temporale.
- La formula esatta (SHA-256 troncato a 64 bit), la forma del `contextKey` (soggetto e occorrenza) e i motivi di scarto sono in [SPEC-04 §10.5](SPEC-04-data-model.md).
- Un evento con `eventId` già presente viene scartato: questo copre reconnect, `/reload` e doppia ricezione.

### 8.5 Regola anti-alt (✅)

**Nessuna interazione tra personaggi dello stesso account genera punti**: trade, vendite AH, duelli, aiuto ai nuovi, mentorship, Commendations, attestazioni, check-in a eventi, reclutamento.

**Rilevamento:**

1. **Locale (principale).** I SavedVariables di account (`AzerothPrestigeDB`) sono condivisi da tutti i personaggi dello stesso account WoW sullo stesso PC. L'addon registra ogni proprio personaggio in `myChars` al login. Ogni regola con una controparte scarta l'evento se la controparte è in `myChars`.
2. **Alt collegati pubblicamente (opt-in, §6.1).** Se un profilo pubblica `alts`, tutti i peer applicano la regola anche ai suoi eventi ricalcolati, e un'eventuale violazione rende l'evento `Flagged`.
3. **Testimoni.** Un alt non può attestare eventi del proprio account: anche le attestazioni tra personaggi in `myChars` vengono scartate.

> Limite dichiarato (anti-alt): senza server non si può riconoscere un secondo account WoW (o un altro PC) della stessa persona. Un client modificato può anche ignorare la regola. In questi casi restano a difendere il sistema i limiti delle famiglie farmabili (§8.2), il peso ridotto dei testimoni ricorrenti ([§11.3](SPEC-05-ledger-trust.md)) e i controlli di plausibilità ([§11.5](SPEC-05-ledger-trust.md)).

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

**Eventi una tantum annullati:** restano **consumati**. Il gioco non permette di riscoprire una zona o di riconsegnare una quest, quindi la prima volta fatta con un boost non si recupera. Per questo la UI avvisa in modo molto visibile ([§14.8](SPEC-08-ui-badges.md)).

#### 8.6.3 Verificabilità

- Il trigger **G** è **ricalcolabile dai peer**: ogni evento salva nel contesto il livello del giocatore e il livello massimo del gruppo (`c.pl`, `c.gmx`). Un profilo con eventi a punti pieni che violano G viene marcato `Flagged`.
- I trigger **A1–A4** sono euristici e locali: il client registra l'esito, i peer non possono verificarlo.

> Limite dichiarato: senza combat log (bloccato dalle restrizioni Midnight) non si vedono le cure dirette senza aura e gli aiuti da giocatori fuori dal raggio delle nameplate. La regola blocca in modo affidabile il boost in gruppo, che è il caso più comune, e la maggior parte degli aiuti visibili da fuori gruppo.
> Il backfill ([§7.9](SPEC-03-activity-catalog.md)) importa dati di prima dell'installazione: lì non si può sapere se ci sia stato boost. Si accetta il limite.

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

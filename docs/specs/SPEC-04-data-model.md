# SPEC-04: Modello dati e SavedVariables

> Parte della [specifica di Azeroth Prestige](README.md). Nata dal documento unico v0.4 del 2026-11-26, diviso in file nel bootstrap: la numerazione delle sezioni (§) è quella del documento originale, così i rimandi restano validi in tutti i file. Legenda: ✅ confermato dal proprietario · 🟡 proposta valida fino a diversa decisione ([SPEC-11](SPEC-11-risks-open-questions.md)) · 🔍 da verificare in M0.

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

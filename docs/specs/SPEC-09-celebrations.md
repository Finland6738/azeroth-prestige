# SPEC-09: Sistema di celebrazioni

> Parte della [specifica di Azeroth Prestige](README.md). Nata dal documento unico v0.4 del 2026-11-26, diviso in file nel bootstrap: la numerazione delle sezioni (§) è quella del documento originale, così i rimandi restano validi in tutti i file. Legenda: ✅ confermato dal proprietario · 🟡 proposta valida fino a diversa decisione ([SPEC-11](SPEC-11-risks-open-questions.md)) · 🔍 da verificare in M0.

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

- **Combinazione:** le promozioni arrivate entro 3 s l'una dall'altra, o accumulate mentre la coda è bloccata, si fondono in **una sola celebrazione**, con ordine: Global prima, poi le categorie in ordine di importanza del rank. Se una delle promozioni è l'ingresso o la salita in un apex, la celebrazione è cinematica. Gli spodestamenti non generano celebrazioni, solo un toast ([§13.3](SPEC-07-leaderboards-hall.md)).
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

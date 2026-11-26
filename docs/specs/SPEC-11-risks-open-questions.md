# SPEC-11: Rischi e domande aperte

> Parte della [specifica di Azeroth Prestige](README.md). Sostituisce §23 del documento v0.4. Le domande sono del **proprietario**: ciascuna ha una **risposta proposta**, che il codice applica finché il proprietario non decide, e un **punto unico** dove la risposta si cambia ([ADR 0007](../adr/0007-git-flow-and-automated-shipping.md) punto 8). Quando il proprietario risponde, la riga riporta la risposta con la data e il passo che la applica.

## 1. Rischi

| # | Rischio | Probabilità | Impatto | Risposta |
|---|---|---|---|---|
| R1 | `ENCOUNTER_END` o altri eventi chiave arrivano con valori *secret* nelle istanze (V1) | media | alto | Delver con fonti alternative (`BOSS_KILL`, completamento dell'istanza); decisione in M0.9 |
| R2 | Il canale custom di discovery ha limiti bassi, non è cross-faction o viene bloccato (V4) | media | alto | beacon solo su GUILD/PARTY/RAID e lazy fetch via WHISPER; classifiche più locali; revisione di [SPEC-06](SPEC-06-network-protocol.md) dopo M0 |
| R3 | Traffico eccessivo su un mega-realm con migliaia di utenti | media | alto | budget di §12.3, intervallo dei beacon adattivo, sharding; provato nel simulatore (M4.7) prima del rilascio |
| R4 | Nameplate amiche *forbidden* in istanza, badge invisibili dove servono (V3) | alta | medio | fallback su tooltip, target e frame di gruppo ([SPEC-08 §14.4](SPEC-08-ui-badges.md)) |
| R5 | Taint dei frame protetti (party/raid, menu unità) | media | alto | nessuna modifica in combattimento, overlay creati fuori combattimento, step con modello Opus high; controllo in-game di ogni milestone |
| R6 | Client modificati o SavedVariables editate gonfiano i punti | alta | medio | ricalcolo dal ruleset, plausibilità, `vr` minimo per gli apex, profili `Flagged` ([ADR 0004](../adr/0004-trust-without-a-server.md)) |
| R7 | Più account della stessa persona si fanno da testimoni a vicenda | media | medio | peso massimo del 20% per testimone, testimoni ricorrenti pesati meno (§11.3); limite dichiarato |
| R8 | Pochi utenti dell'addon: classifiche vuote e badge invisibili | media | alto | valore anche in solitaria (profilo, celebrazioni, cronologia); trasparenza sul numero di profili noti |
| R9 | Crescita delle SavedVariables (profili, ledger, albo) oltre i limiti di §10.3 | media | medio | compattazione, eviction con priorità, `/azp stats`; misurato nel simulatore (M6.10) |
| R10 | Divergenza degli snapshot apex tra client diversi | media | medio | consenso di maggioranza `LBD` (§13.3); limite dichiarato nell'interfaccia |
| R11 | API mancanti su Forever per Legacy, Auction House, scoreboard BG, game rules Hardcore (V7, V11, V17, V18) | media | medio | regole spente dal feature switch della categoria finché non c'è una fonte; Q17 per gli obiettivi militari |
| R12 | Immagini generate con strumenti AI (logo, badge definitivi): tutela del diritto d'autore debole in alcuni paesi, termini d'uso dello strumento | media | basso | rifinitura a mano, controllo di originalità e dei termini prima dell'uso ([SPEC-08 §14.7](SPEC-08-ui-badges.md)); la riserva di [ADR 0012](../adr/0012-licensing-gpl-code-cc-docs-reserved-art.md) copre comunque rifinitura e selezione |
| R13 | Livelli dei contenuti (`L` di boss, quest, zone) non leggibili dal client e non copiabili da database di terzi | media | alto | fonte decisa in M0 (API del client dove esistono, altrimenti tabelle curate a mano nel ruleset); step M2.2 dedicato |
| R14 | Un aggiornamento del client cambia API o restrizioni | media | medio | Compat, `pcall` sulle API 🔍, nuovo controllo del dump a ogni build |

## 2. Domande aperte per il proprietario

Le prime righe vengono dalle decisioni 🟡 di [SPEC-00 §22](SPEC-00-vision-scope.md); le altre sono nate nel bootstrap.

| # | Domanda | Proposta (applicata finché non decidi) | Punto unico |
|---|---|---|---|
| Q1 | Nomi tecnici: cartella `AzerothPrestige`, prefisso dei messaggi `AZPRES`, comandi `/prestige` e `/azp`, probe `AzPr_Probe` con `/azpp` | come proposto | TOC, `Core/Init.lua` (M1.2), `Network/Comm.lua` (M4.3) |
| Q2 | D-07: la divisione IV è l'ingresso e la I il vertice di ogni tier | sì | `Data/Ladder.lua` (M1.6) |
| Q3 | D-11: profilo a 3 livelli (Overview, Category Details con albo, Statistics) | sì | `UI/ProfileView.lua` (M3.5) |
| Q4 | D-15: promozioni entro 3 s, o accumulate in coda, in un'unica celebrazione combinata (Global per primo) | sì, finestra di 3 s | `Celebrations/Queue.lua`, `COMBINE_WINDOW` (M3.8) |
| Q5 | D-18: suoni configurabili con due set (Discreto, Epico) e scelta del canale audio | sì, default Discreto | `Celebrations/Sounds.lua` (M3.9) |
| Q6 | D-21: rinvio delle celebrazioni solo sui trasporti automatici (taxi, navi, zeppelin), non a piedi o in sella | sì | `Celebrations/Conditions.lua` (M3.8) |
| Q7 | D-22: mappa aperta durante una celebrazione → sospensione e ripresa dal punto sospeso | sì | `Celebrations/Conditions.lua` (M3.8) |
| Q8 | D-23: ricompense solo cosmetiche e interne all'addon | sì (anche vincolo tecnico) | [SPEC-08 §16](SPEC-08-ui-badges.md) |
| Q9 | D-24: niente punti per il trash, solo boss encounter e completamento dell'istanza | sì | `Data/Ruleset_v1.lua` (M1.7) |
| Q10 | D-25: tutti gli apex richiedono `vr ≥ 0.6` nella categoria | sì | `Data/Ruleset_v1.lua`, `APEX_MIN_VR` (M1.7) |
| Q11 | D-36: soglia di Legend a 1 000 000 PP (Global 4 000 000) | sì | `Data/Ladder.lua` (M1.6) |
| Q12 | D-39: stato BOOSTED per 60 s dopo l'ultimo segnale da fuori gruppo; buff ricevuti fuori combattimento ignorati | sì | `Domain/Boost.lua`, `ASSIST_WINDOW` (M1.9) |
| Q13 | D-40: un evento una tantum annullato per boost resta consumato (non si recupera) | sì, con l'avviso molto visibile di [SPEC-08 §14.8](SPEC-08-ui-badges.md) | `Domain/Boost.lua` (M1.9) |
| Q14 | Tema di default e crediti: i temi sono Nebula, Aurora e **Prestige** (dal logo). Quale è il default? La gilda NEBULA va citata nei crediti come in Accord? | default **Prestige**; crediti "Created and designed by Finland", famiglia di addon citata nella pagina About, NEBULA non citata (l'addon è per tutto il reame) | `UI/Theme.lua` `DEFAULT_THEME`, `UI/About.lua` (M3.2, M3.4) |
| Q15 | Distribuzione: solo GitHub Releases, o anche CurseForge e Wago? | solo GitHub finché non decidi; la riga del progetto CurseForge resta commentata nel TOC | TOC, segreto `CF_API_KEY` ([RELEASING](../RELEASING.md)) |
| Q16 | Valori di calibrazione: punti per regola e coefficienti per categoria, comprese le regole 🟡 `DEL_WIPE_LEARN` e `DIP_GUILD_WELCOME` | i valori iniziali di [SPEC-03](SPEC-03-activity-catalog.md), da tarare in beta (M4–M6) con un nuovo ruleset, mai togliendo punti | `Data/Ruleset_v1.lua` |
| Q17 | Obiettivi militari di Vanguard (`VAN_MIL_OBJ`): quali contenuti warfare di Forever contano? | regola spenta finché M0 non trova i contenuti; definita in M5.1 | `Data/Ruleset_v1.lua` |
| Q18 | Regole delle Commendations (§7.5): 5 a settimana, 1 per destinatario ogni 7 giorni, 15 minuti di gruppo, livello ≥ 20, profilo di 7 giorni | come proposto | `Domain/Commendations.lua` (M5.4) |
| Q19 | Prestige Events (§7.8): check-in entro circa 40 yard, durata 20 min–4 h, minimo 5 partecipanti | come proposto | `Domain/Events.lua` (M5.6) |
| Q20 | Confine Diplomat / Steward (§6.2): Diplomat premia la relazione individuale, Steward l'organizzazione collettiva, mai la stessa azione per entrambi | come proposto | `Data/Ruleset_v1.lua` (M5.1) |
| Q21 | Dati alla disinstallazione: il profilo resta nelle cache degli altri e circola via `RLY` (D-10). Serve un comando "dimentica il mio profilo" che chieda agli altri di cancellarlo? | no: un addon non può garantire la cancellazione negli altri client; `/azp privacy` spiega cosa resta e il pannello Privacy permette di non condividere il profilo dettagliato | [SPEC-08 §14.6](SPEC-08-ui-badges.md), wiki *Privacy and Data* (M4) |

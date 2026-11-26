# SPEC-07: Classifiche e Hall of Prestige

> Parte della [specifica di Azeroth Prestige](README.md). Nata dal documento unico v0.4 del 2026-11-26, diviso in file nel bootstrap: la numerazione delle sezioni (§) è quella del documento originale, così i rimandi restano validi in tutti i file. Legenda: ✅ confermato dal proprietario · 🟡 proposta valida fino a diversa decisione ([SPEC-11](SPEC-11-risks-open-questions.md)) · 🔍 da verificare in M0.

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

1. A ogni reset settimanale (`C_DateAndTime.GetSecondsUntilWeeklyReset`), o al primo login successivo, il client esegue per ogni categoria e per il Global l'**assegnazione a cascata** di [§6.3](SPEC-02-progression-scoring.md) sui profili eleggibili.
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
   - ingresso o salita in un apex → **celebrazione cinematica** ([§15](SPEC-09-celebrations.md));
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

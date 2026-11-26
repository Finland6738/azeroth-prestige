# SPEC-05: Ledger, attestazioni e livelli di fiducia

> Parte della [specifica di Azeroth Prestige](README.md). Nata dal documento unico v0.4 del 2026-11-26, diviso in file nel bootstrap: la numerazione delle sezioni (§) è quella del documento originale, così i rimandi restano validi in tutti i file. Legenda: ✅ confermato dal proprietario · 🟡 proposta valida fino a diversa decisione ([SPEC-11](SPEC-11-risks-open-questions.md)) · 🔍 da verificare in M0.

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

# SPEC-06: Protocollo di rete peer-to-peer

> Parte della [specifica di Azeroth Prestige](README.md). Nata dal documento unico v0.4 del 2026-11-26, diviso in file nel bootstrap: la numerazione delle sezioni (§) è quella del documento originale, così i rimandi restano validi in tutti i file. Legenda: ✅ confermato dal proprietario · 🟡 proposta valida fino a diversa decisione ([SPEC-11](SPEC-11-risks-open-questions.md)) · 🔍 da verificare in M0.

## 12. Protocollo di rete peer-to-peer

### 12.1 Trasporto

- Prefisso: `AZPRES` (registrato con `C_ChatInfo.RegisterAddonMessagePrefix`).
- Envelope: `<ver:1><type:3><seq:2><payload>`, payload serializzato, compresso e codificato per il canale. Messaggi > 255 byte divisi con AceComm.
- Tutte le uscite passano da **ChatThrottleLib**, con priorità `ALERT` (attestazioni), `NORMAL` (profili) e `BULK` (sync).
- **Coda di lockdown:** se `InChatMessagingLockdown()` è vero, o l'invio restituisce `AddOnMessageLockdown`, il messaggio resta in coda (TTL 30 min) e viene ritentato a ogni cambio di stato.
- Account trial: invio disabilitato, ricezione attiva.

### 12.2 Tipi di messaggio

| Tipo | Canale | Contenuto | Frequenza |
| --- | --- | --- | --- |
| `HEL` (beacon) | GUILD, CHANNEL, PARTY/RAID | `v`, ruleset, `gp`, `peak[9]`, `fc`, `vr` e un hash del profilo (~60 byte) | Al login, ogni 15 min ± jitter, a ogni promozione |
| `PRQ` | WHISPER | Richiesta del profilo completo (`v` noto) | Su richiesta, max 1 ogni 2 s |
| `PRF` | WHISPER | Profilo completo + digest del ledger (chunked) | Risposta |
| `ATT` | PARTY/RAID/INSTANCE_CHAT | Attestazione evento | Dopo eventi di gruppo |
| `ATQ` / `ATA` | WHISPER | Query e risposta di verifica di un'attestazione | Su richiesta |
| `RLY` | CHANNEL, GUILD | Rilancio di riepiloghi di profili **offline** (seconda mano) | Max 20 profili ogni 10 min |
| `LBD` | CHANNEL, GUILD | Digest dei posti apex: un hash per ogni coppia categoria/apex (63 hash). L'elenco completo dei nomi di una fascia si scarica via WHISPER solo se il proprio hash non coincide con quello di maggioranza | Dopo il reset settimanale |
| `CMD` | WHISPER | Commendation | Su azione utente |
| `EVT` | GUILD, CHANNEL, WHISPER | Ciclo di vita di un Prestige Event (create, check-in, close) | Su azione utente |
| `CTR` | CHANNEL, WHISPER | Prestige Contracts (fase 3) | Su azione utente |

### 12.3 Discovery su un mega-realm

- **Canale custom nascosto**, ad esempio `AzPrestige1`: unito con `JoinTemporaryChannel` e rimosso dai chat frame. È il mezzo per raggiungere gli utenti fuori da gilda e gruppo. 🔍 V4: limiti del canale, cross-faction e numero di membri.
- **Budget di traffico:** con 10 000 utenti attivi e beacon ogni 15 min arrivano circa 11 msg/s, gestibili. Se il canale supera una soglia (🟡 > 20 msg/s osservati) il beacon passa a 30 min, e poi a sharding su più canali (`AzPrestige1..4` per hash del nome).
- **Lazy fetch:** se nameplate o tooltip mostrano un giocatore il cui hash è più recente della cache, parte un `PRQ`. Limiti: 1 ogni 2 s, max 30 al minuto, negative cache di 10 min.

### 12.4 Merge dei profili

1. Un dato di prima mano (mittente = proprietario) con `v` maggiore sostituisce sempre quello in cache.
2. Un dato di seconda mano (`RLY`) si accetta solo se:
   - non esiste un dato di prima mano con `v` ≥;
   - e almeno **2 relay distinti** riportano la stessa `v` e lo stesso hash (`src = 2`); altrimenti resta `src = 3` (mostrato, ma escluso dagli apex).
3. Un dato di seconda mano non può mai abbassare PP o peak rispetto a quanto già noto.

### 12.5 Persistenza dei profili di chi non usa più l'addon (✅ 5.8 / 5.21-C)

- Il profilo vive nelle cache degli altri e circola via `RLY`. Ogni client rilancia a rotazione i profili offline di valore: top della classifica, detentori ed ex detentori di apex, membri di gilda.
- Limite dichiarato: se **nessun** client conserva un profilo, quel profilo si perde. Con la politica di eviction ([§10.3](SPEC-04-data-model.md)) i profili rilevanti, cioè top e albo apex, sono praticamente sempre conservati.

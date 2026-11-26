# Azeroth Prestige: specifiche di progetto

Addon **non ufficiale** per **WoW: Forever**: un sistema di **identità e reputazione del personaggio**, parallelo alla progressione del gioco. Si guadagnano **Prestige Points** in **8 categorie** completando attività (non passando ore), si sale una scala di **22 tier** con divisioni IV→I e **7 rank apex** a posti limitati, e si mostrano badge, profilo e classifiche agli altri utenti dell'addon, con una rete **peer-to-peer** senza server.

- Stato: **v0.5 (2026-11-26)**, il documento v0.4 diviso in file nel bootstrap, con le risposte del proprietario dello stesso giorno (licenze, versioni, integrazioni, lingue: D-42–D-46)
- Client di riferimento: WoW Forever `1.60.1`, `## Interface: 16001`, `WOW_PROJECT_ID == WOW_PROJECT_CAMELOT` ([ADR 0002](../adr/0002-wow-forever-target-and-api-dump.md))
- Distribuzione: GitHub Releases (CurseForge e Wago facoltativi, [Q15](SPEC-11-risks-open-questions.md))
- Lingue dell'addon: inglese (base e fallback) e italiano dal primo codice, struttura multilingua ([ADR 0010](../adr/0010-interface-and-documentation-languages.md))
- Lingua di questi documenti: italiano; nomi di codice, API e testi dell'interfaccia in inglese
- Cartella dell'addon: `AzerothPrestige` · comandi: `/prestige`, `/azp`

## Legenda

| Simbolo | Significato |
| --- | --- |
| ✅ | Decisione **confermata** dal proprietario |
| 🟡 | **Proposta**: valida fino a diversa decisione; è una domanda aperta in [SPEC-11](SPEC-11-risks-open-questions.md) |
| 🔍 | **Da verificare** sul client live di WoW Forever (milestone M0) prima di implementare |

## Indice

La numerazione delle sezioni (§) è quella del documento unico v0.4: un rimando come "§8.6" vale in tutti i file ed è un link al file giusto.

| # | Documento | Sezioni | Contenuto |
|---|---|---|---|
| 00 | [Visione, ambito e decisioni](SPEC-00-vision-scope.md) | §1, §2, §4, §5, §22, §24 | executive summary, lavoro precedente, principi, glossario, registro delle decisioni D-01–D-46, fonti |
| 01 | [Piattaforma e architettura](SPEC-01-platform-architecture.md) | §3, §9, §17, §19 | vincoli di Forever, verifiche V1–V21 di M0, moduli, struttura, TOC, librerie, regole di codice, prestazioni, compatibilità, API pubblica, policy |
| 02 | [Progressione e punteggio](SPEC-02-progression-scoring.md) | §6, §8 | categorie, ladder, apex a posti limitati, Global Prestige, albo; calcolo deterministico, DR e cap, group credit, idempotenza, anti-alt, anti-boost, contenuto di livello inferiore |
| 03 | [Catalogo delle attività](SPEC-03-activity-catalog.md) | §7 | le regole `ruleId` delle 8 categorie, backfill, Prestige Contracts |
| 04 | [Modello dati](SPEC-04-data-model.md) | §10 | `AzerothPrestigeCharDB`, `AzerothPrestigeDB`, limiti di dimensione |
| 05 | [Ledger e fiducia](SPEC-05-ledger-trust.md) | §11 | modello di minaccia, livelli di fiducia, attestazioni, verified ratio, plausibilità |
| 06 | [Protocollo di rete](SPEC-06-network-protocol.md) | §12 | trasporto, tipi di messaggio, discovery sul mega-realm, merge dei profili, persistenza |
| 07 | [Classifiche e Hall of Prestige](SPEC-07-leaderboards-hall.md) | §13 | viste e filtri, trasparenza, assegnazione settimanale degli apex, Hall of Prestige, memoriale Hardcore |
| 08 | [Interfaccia e badge](SPEC-08-ui-badges.md) | §14, §16, §18 | finestra, profilo, badge e superfici, grafica e art bible, avviso di boost, impostazioni, ricompense, localizzazione e accessibilità |
| 09 | [Celebrazioni](SPEC-09-celebrations.md) | §15 | decisioni, macchina a stati, condizioni di blocco, presentazione |
| 10 | [Qualità, test e roadmap](SPEC-10-quality-release.md) | §20, §21 | test offline e in gioco, casi di accettazione A1–A19, milestone e versioni |
| 11 | [Rischi e domande aperte](SPEC-11-risks-open-questions.md) | ex §23 | rischi R1–R14, domande Q1–Q21 con risposta proposta e punto unico |

Altri documenti: [decisioni architetturali (ADR)](../adr/README.md) · [roadmap e step](../roadmap/README.md) · [manuale utente (wiki)](../wiki/Home.md) · [checklist in gioco](../checklists/README.md). Lo stile dell'interfaccia (`ui-style.md`) arriva con lo step M3.1.

## Come si cambia una specifica

Ogni step che cambia un comportamento aggiorna la spec nella stessa pull request. Una decisione del proprietario entra nel registro di §22 (✅) e, se cambia l'architettura o il metodo, in un nuovo ADR. Una domanda aperta si chiude nella sua riga di [SPEC-11](SPEC-11-risks-open-questions.md), con la data e il passo che applica la risposta.

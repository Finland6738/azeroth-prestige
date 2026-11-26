# SPEC-08: Interfaccia, badge, ricompense e localizzazione

> Parte della [specifica di Azeroth Prestige](README.md). Nata dal documento unico v0.4 del 2026-11-26, diviso in file nel bootstrap: la numerazione delle sezioni (§) è quella del documento originale, così i rimandi restano validi in tutti i file. Legenda: ✅ confermato dal proprietario · 🟡 proposta valida fino a diversa decisione ([SPEC-11](SPEC-11-risks-open-questions.md)) · 🔍 da verificare in M0.

## 14. UI/UX

### 14.1 Finestra principale (`/prestige`)

Finestra trascinabile (~820×560), stile coerente con la UI Midnight/Forever. Tab:

1. **Profilo**: il proprio, o quello del giocatore selezionato.
2. **Classifiche**
3. **Hall of Prestige**
4. **Cronologia**: ledger leggibile, filtrabile per categoria, con `ruleId` spiegato e PP.
5. **Eventi**: Prestige Events e Commendations (dare e ricevute).
6. **Impostazioni**: anche nel pannello di sistema via `Settings.RegisterCanvasLayoutCategory`.

Accesso anche da pulsante minimappa (LibDBIcon), broker LDB e menu contestuale del giocatore.

### 14.2 Profilo a 3 livelli (🟡, proposto in 5.10)

1. **Overview**: nome, livello, classe, razza, gilda; badge Global grande con rank e PP; griglia 8 categorie (badge, rank, PP, barra verso la divisione successiva); `vr`; apex attuali e sigilli storici.
2. **Category Details** (clic su una categoria): rank, divisione, PP, PP mancanti, data di raggiungimento di ogni tier (timeline), posizione in classifica, PP mancanti per la soglia apex successiva e posizione nella sua fascia.
2b. **Albo dei titoli**: tutti i regni apex del personaggio (titolo, categoria, data di inizio, data di fine o "in corso", durata), ordinati dal titolo più alto.
3. **Statistics**: contatori per regola (boss uccisi, flight path, ricette…), migliori settimane, distribuzione delle attività.

Per gli altri giocatori i livelli 1 e 2 sono sempre disponibili. Il livello 3 è disponibile se si è ricevuto il loro digest `PRF`.

### 14.3 Badge: cosa mostrare (✅ 5.22)

- **Default (opzione B):** badge **Global** + badge della **categoria in evidenza** del proprietario. La categoria in evidenza è il rank più alto, oppure quella scelta dal proprietario in `featuredCategory`.
- **Override del viewer:** "Solo Global" · "Global + evidenza" · "Solo una categoria specifica (per tutti)" · "Nessun badge".
- Dimensione, posizione (sinistra o destra del nome, sopra) e opacità sono configurabili.

### 14.4 Superfici dei badge

| Superficie | Implementazione | Note |
| --- | --- | --- |
| **Nameplate** | `NAME_PLATE_UNIT_ADDED/REMOVED` → `C_NamePlate.GetNamePlateForUnit(unit)`; se `plate:IsForbidden()` si salta; texture figlia ancorata alla plate | Nemici e amici fuori dalle istanze. **In istanza le amiche sono forbidden** 🔍 V3 |
| **Tooltip unità** | `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, fn)` | Riga "Prestige: [badge] Gold II (Global) · Delver Diamond IV" e una riga che spiega cosa misura |
| **Target / Focus frame** | Overlay sul ritratto | Funziona anche in istanza |
| **Frame party/raid** | Overlay sui `CompactUnitFrame`, creato e posizionato **fuori dal combattimento** | Fallback principale in istanza |
| **Chat** | Message event filter: anteponi `\|T<badge>:14\|t` al nome del mittente | Disattivato automaticamente se il nome del mittente è secret (chat lockdown) 🔍 V12 |
| **Menu unità** | `Menu.ModifyMenu("MENU_UNIT_PLAYER", …)` → "Apri profilo Prestige", "Dai una Commendation" | — |
| **Inspect / Who / Friends / Guild** | 🟡 fase 2: badge nelle liste gilda e amici | — |

Lookup: `charKey` → `ProfileStore`. Se il dato è assente non si mostra nulla. Se è vecchio, parte un lazy fetch ([§12.3](SPEC-06-network-protocol.md)).

### 14.5 Grafica

- I **29 badge** (22 tier, 7 apex incluso Legend), più i **sigilli storici** "Ex-<apex>" (7 piccoli overlay), sono texture originali 64×64 (`.tga`, potenza di 2), con una versione da 16 px per la chat. Le emoji del brief sono solo riferimento: i font WoW non le rendono.
- **8 emblemi** di categoria + 1 Global. Il badge composto è emblema di categoria + cornice del tier.
- Le divisioni IV–I si rendono con 1–4 pip sotto il badge.
- Apex: cornice animata con flipbook leggero. Legend: glow pulsante.
- Tutta la grafica deve essere **originale**: niente asset Blizzard ridistribuiti, niente immagini prese dal web.

### 14.7 Pipeline degli asset e art bible (✅)

Gli asset si producono in due fasi:

1. **Placeholder (M1–M4).** Generati da `tools/make_badges.py` (step M3.3): forma base (scudo per i tier, stella per gli apex) riempita con il colore del tier, iniziale del tier al centro, pip per le divisioni. Bastano per sviluppare e testare tutta la UI.
2. **Asset definitivi (da M4).** Generati con strumenti AI seguendo l'art bible qui sotto, poi **rifiniti a mano**: pulizia dei bordi, palette fissata, leggibilità a 16 px, esportazione nei formati richiesti.

**Specifiche tecniche**

| Asset | Quantità | Formato | Dimensioni |
| --- | --- | --- | --- |
| Badge tier | 22 | `.tga` 32-bit con alpha | 64×64 (+ 16×16 per la chat) |
| Badge apex | 6 | idem | 64×64 + flipbook 4×4 frame (256×256) |
| Sigilli storici "Ex-apex" | 7 | idem | 32×32 overlay |
| Badge Legend | 1 | idem | 128×128 + flipbook |
| Emblemi categoria + Global | 9 | idem | 64×64 |
| Cornici del profilo | 6 | idem | 256×128 |
| Particelle | ~6 | idem | 64×64 flipbook |
| Suoni | ~6 | `.ogg` 44.1 kHz | ordinari ≤ 2 s, apex ≤ 6 s |

**Linee guida di stile**

- Stile: emblema **fantasy medievale dipinto**, leggibile, coerente con la UI di WoW ma originale. Vista frontale, sfondo trasparente, nessun testo nell'immagine.
- Progressione visiva: il materiale stesso del tier è il soggetto (legno grezzo → pietra → metalli sempre più lavorati → gemme sfaccettate → materiali leggendari). Salendo crescono complessità della cornice, ornamenti e luminosità.
- Apex: cornice con elementi araldici (corona, ali, rune). Legend: aura cosmica e glow.
- Silhouette distinguibili anche in scala di grigi (accessibilità).

**Palette per tier (colore dominante)**

| Tier | Colore | Tier | Colore |
| --- | --- | --- | --- |
| Wood | `#8B5A2B` | Thorium | `#7A3FB0` |
| Stone | `#8A8A8A` | Ruby | `#C41E3A` |
| Copper | `#B87333` | Sapphire | `#0F52BA` |
| Tin | `#A9ACB6` | Emerald | `#2E8B57` |
| Bronze | `#CD7F32` | Topaz | `#FFC87C` |
| Iron | `#5A5F66` | Amethyst | `#9966CC` |
| Steel | `#7B8FA1` | Diamond | `#E8F4F8` |
| Silver | `#C0C0C0` | Arcanite | `#E0457B` |
| Gold | `#D4AF37` | Elementium | `#FF6A1A` |
| Mithril | `#5FB3C9` | Dragonite | `#1FA37A` |
| Truesilver | `#DDE6EA` | Apex | oro + colore della categoria |
| Dark Iron | `#2B2B30` | Legend | bianco + aura iridescente |

**Template di prompt (da adattare per ogni tier)**

```
Fantasy game rank emblem, heraldic shield badge made of <MATERIALE>,
<DETTAGLI ORNAMENTI DEL TIER>, dominant color <HEX>, painted hand-crafted style,
front view, centered, transparent background, no text, no letters,
clean silhouette readable at small size, soft rim light, high detail
```

Esempio Mithril: `MATERIALE = "polished blue-silver mithril with engraved runes"`, `DETTAGLI = "thin filigree border, small inset crystal at the top"`.

### 14.8 Avviso di boost (✅)

La regola anti-boost deve essere sempre evidente, perché può annullare per sempre eventi una tantum:

- **Indicatore permanente** sul pulsante minimappa, sul broker LDB e nella finestra principale mentre lo stato BOOSTED è attivo: icona ⚠ arancione e testo "Boost attivo: i punti sono sospesi".
- Il **tooltip** dell'indicatore spiega il motivo: "Nel gruppo: Thrall (60), tu sei 32" oppure "Aiuto da fuori gruppo: Jaina (58), 45 s rimanenti".
- **Avviso all'ingresso nel gruppo**: se entri in un gruppo con un membro di livello +10, compare un toast con il motivo e il suggerimento "Scoperte e quest completate ora non daranno punti, e quelle una tantum non si potranno recuperare".
- Nella **Cronologia**, gli eventi annullati compaiono barrati con il motivo (`BOOST:G`, `BOOST:A1`…).

Ogni asset generato va controllato prima dell'uso: originalità (nessuna somiglianza con loghi o asset esistenti), termini d'uso dello strumento AI per la distribuzione, leggibilità a 16 px.

### 14.6 Impostazioni principali

| Sezione | Opzioni |
| --- | --- |
| Badge | Modalità (§14.3), superfici attive, dimensione, posizione, opacità, "nascondi il mio badge agli altri" |
| Celebrazioni | Durata (3–15 s, default 7.5), skip abilitato, condizioni di rinvio ([§15.3](SPEC-09-celebrations.md)), anteprima |
| Suoni | On/off, canale audio (Master/SFX/Dialog), set suoni (Discreto/Epico), suono per apex on/off |
| Rete | Partecipa al canale realm on/off, rilancio profili on/off, livello traffico (Basso/Normale) |
| Privacy | Condividi il profilo dettagliato (livello 3) on/off, accetta Commendations on/off, accetta inviti a eventi, **mostra pubblicamente i miei alt** (opt-in per personaggio, default off) |
| Debug | Log level, `/azp stats`, export diagnostico |

## 16. Ricompense

Sono solo cosmetiche e solo all'interno dell'addon. L'addon non può assegnare nulla nel gioco, e la wiki lo esclude comunque.

| Traguardo | Ricompensa |
| --- | --- |
| Ogni tier | Nuovo badge e cornice |
| Gold, Diamond, Dragonite | Bordo del profilo dedicato |
| Apex (detenuto) | Cornice animata, titolo Prestige nel tooltip (es. "Delver Grandmaster") |
| Legend (detenuto) | Glow, titolo "Legend of the Vanguard" |
| Qualsiasi apex ottenuto in passato | Voce permanente nell'albo e nella Hall of Prestige, sigillo storico sul badge, titolo selezionabile in forma storica (es. "Ex-Legend of the Vanguard") |
| Varietà: 4 categorie ≥ Gold | Titolo "Hero of Azeroth" e badge Global speciale |
| Tutte le 8 categorie ≥ Silver | Titolo "Renaissance" |

🟡 Il **titolo Prestige** scelto dal giocatore compare nel suo tooltip e nel profilo, per gli altri utenti addon.

## 18. Localizzazione e accessibilità

- Lingue: **enUS** (base, fallback) e **itIT** al lancio. Struttura pronta per deDE, frFR, esES. Le stringhe stanno in `Locales/*.lua` (pattern AceLocale).
- Nomi di rank e categorie restano in inglese in tutte le lingue (sono nomi propri), con descrizione localizzata.
- Accessibilità:
  - le divisioni sono comunicate da pip **e** numeri romani, non solo dal colore;
  - modalità "alto contrasto" per i badge;
  - opzione "riduci effetti" per disattivare particelle e flash nelle cinematiche.
- Il tooltip del badge spiega sempre cosa misura (principio della wiki).

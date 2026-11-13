# UI-ontwerp: Veilspire

Antwoord op de vraag van de eigenaar (13-11-2026): tot nu toe stond het UI-ontwerp verspreid over code en changelog. Dit document is de vaste plek voor de uitwerking. De huidige UI is **functioneel**: platte panelen met een steenkleurige rand. De verfijnde versie hieronder is het doel van roadmapblok **V.11 UI-afwerking**.

`docs/SMAAK.md` blijft leidend: gestileerd, strakke vormen, heldere silhouetten, rustig maar rijk. Referentie voor scherpte en leesbaarheid: de recente UI van RuneScape 3.

## Stijlregels

| Onderdeel | Regel |
|---|---|
| Panelen | Donker leisteen (#1E2125 tot #353A42, 95% dekkend), dunne rand in steen #E6E1D3, binnenrand in goud #D9A441 bij belangrijke vensters. Hoeken 6 tot 10 px. |
| Ornament | Kleine hoekstukken in goud (gestileerde kroonpunt, verwijzing naar de Sundered Crown). Geen drukke patronen. |
| Kleuren voor betekenis | Health: vuur #D9552E. Stamina: gras #4CB46A. XP: goud #D9A441. Klasse-resource: kleur van de klasse. Gevaar en afgesloten: vuur. Klaar en beschikbaar: gras. |
| Tekst | Engels in het spel. Titels in een serif met karakter (CC0 of OFL-font, nog te kiezen). Lopende tekst in de huidige schreefloze letter. Altijd een donkere omlijning over de 3D-wereld. |
| Iconen | Eigen vectoriconen in code of SVG: één vorm, één accentkleur, lichte binnengloed. Geen iconen uit andere games. |
| Beweging | Kort en functioneel: 0,15 tot 0,25 s. Een flits bij gebruik, een zachte puls bij "klaar". |

## Schermindeling (1280 × 720 en groter)

```
┌──────────────────────────────────────────────────────────────┐
│ [doelwit: naam + balk]                      [fps]  [tracker] │
│                                                              │
│                        3D-wereld                             │
│                                                              │
│ [meldingen]                                  [rugzak-paneel] │
│ ◯ health-orb  ◯ resource-orb     [ 1 ][ 2 ][ 3 ][ 4 ]  [knoppen]│
│ [XP-balk over de volle breedte, dun]                         │
└──────────────────────────────────────────────────────────────┘
```

## Onderdelen

### Health en resource (nu: twee platte balken)
- **Doel:** twee ronde orbs links onder, zoals RuneScape en klassieke ARPG's, met een stenen rand en kroonpunt bovenop. Links health (vuur), rechts de klasse-resource. Vloeistof met een zachte golf (shader) die meezakt. Het getal staat in de orb.
- Stamina wordt een dunne boog langs de health-orb, zodat er geen derde balk nodig is.
- Bij lage health pulseert de rand en verschijnt een lichte vignet. Dat bestaat al als flits.

### Klasse-resource (nog niet gebouwd, voorstel)
| Klasse | Resource | Werking |
|---|---|---|
| Vanguard | **Fury** | Bouwt op door treffers, zakt buiten gevecht. Zware skills kosten Fury. |
| Ranger | **Focus** | Laadt op als je stilstaat of mikt. |
| Arcanist | **Mana** | Klassiek: langzaam herstel. |
| Priest | **Faith** | Bouwt op door genezen, wordt besteed aan Smite. |
| Warlock | **Corruption** | Krachtiger naarmate hij voller is, maar kost health als hij overloopt. |

Dit is een smaakkeuze. Voorstel: eerst een keuze-issue openen voordat het gebouwd wordt.

### Skillbalk (nu: 4 vlakke vakjes met eenvoudige iconen)
- **Doel:** een gebogen stenen balk met 4 vakken, later 8, plus een vak voor eten. De toets staat klein in de hoek.
- Cooldown loopt als een **radiale sweep** in plaats van een verticale vulling. Als een skill weer klaar is, licht een gouden rand kort op.
- Een vergrendelde skill is gedimd met een slotje. Een tooltip in paneelstijl toont naam, kosten en cooldown.
- Slepen vanuit de skilltree naar een vak om de balk zelf in te delen (RuneScape-stijl).

### XP
- Een dunne gouden lijn over de volle breedte onderaan, met het level in een klein schild. Bij een level-up loopt er een glans over de lijn.

### Doelwit
- Naam met level en een klein klasse- of type-icoon. Balk in vuurkleur met een witte "nasleep" die het verlies kort laat zien.

### Vensters (skilltree, rugzak, questlog, pauze)
- Zelfde paneel met titelbalk en sluitknop. Skilltree als echte **boom**: knopen als ronde of ruitvormige iconen met lijnen ertussen, niet als knoppen in kolommen. De klassekleur zit in de rand van de geleerde knopen.
- Rugzak: vakjes met een lichte inzet. Items krijgen eigen iconen in plaats van gekleurde ruitjes.
- Dialoog: onderaan in beeld met een portret van de spreker (later: een render van het 3D-model).

### Hoofdmenu en instellingen (fase 6)
- Achtergrond: een langzame camerarit over Saltwick bij zonsondergang met de scherf in de lucht. De titel in een serif met gouden gloed.
- Instellingen: grafische kwaliteit, gevoeligheid, volume en toegankelijkheid (tekstgrootte, kleurenblindmodus voor health en vijandbalken).

## Status

| Onderdeel | Nu | Doel (V.11) |
|---|---|---|
| Rennen | **knop "Run: ON/OFF" naast de orb (gebouwd)** | ronde run-orb met stamina |
| Health en stamina | **health-orb met golvende vloeistof en een stamina-boog (gebouwd 13-11-2026)** | afwerking: textuur op de rand, waarschuwing bij lage health |
| Resource | ontbreekt | orb per klasse (eerst een keuze-issue) |
| Skillbalk | **8 vakken (1-8), radiale cooldown, skills uit de boom en eten uit de rugzak erop te slepen, slepen tussen vakken, rechtsklik leegt (gebouwd 13-11-2026)** | gebogen stenen balk, meer balken bij hogere levels |
| Skilltree | knoppen in kolommen | boom met iconen en verbindingslijnen |
| Rugzak | gekleurde ruitjes | eigen itemiconen |
| Dialoog | paneel zonder portret | paneel met portret |

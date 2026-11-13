# Roadmap

Blokken van ongeveer 60 minuten. De bouwagent pakt elke run het eerste niet-afgevinkte blok (feedback gaat voor).

**Werkwijze bij de start van elke run:** naast issues met label `feedback` ook alle bestanden in de map `feedback/` lezen (behalve README). Verwerkte bestanden gaan naar `feedback/verwerkt/` met een notitie wat er gedaan is. Deze map is op verzoek van de eigenaar toegevoegd (13-11-2026).

## Eerst volgende run (uit zelfcontrole)

- **Pad naar de Veilspire.** De rots heeft nu richels, maar je kunt er nog niet op. Een pad of trap langs de richels omhoog.
- **Bergring overdag** is te vlak grijs-wit. Meer leisteenblauw in de flanken, scherpere sneeuwgrens.

## Fase 1: speelbare kern (snel en vloeiend)

- [x] **1.1 Fundament.** Projectstructuur, CI naar GitHub Pages, testgebied met belichting en mist, third-person controller (lopen, sprinten, springen met coyote time, dash met i-frames), SpringArm-camera (muis en gamepad, FOV bij sprinten), procedureel personage met loopcyclus, minimale HUD, rooktests en screenshotscript.
- [x] **1.2 Gevecht: aanvallen.** Lichte combo van 3 slagen, zware aanval, luchtaanval, annuleren met ontwijken, stamina. Zwaard-trail.
- [x] **1.3 Vijand: Leeghuls.** Eén vijandtype met state machine (idle, achtervolgen, aanloop, aanval, getroffen, dood), hitboxes en hurtboxes, schade en dood.
- [x] **1.4 Treffergevoel en lock-on.** Hitstop, impactdeeltjes, camera shake bij treffers, knockback, lock-on met doelwissel.
- [x] **1.5 HUD en pauzemenu.** Vijandbalk boven doelwit, pauzemenu (hervatten, besturing, gevoeligheid), muisvangst netjes regelen.
- [x] **1.6a Afwerking kern.** Stof bij sprintstappen, landen en ontwijken.
- [ ] **1.6b Afwerking kern.** Ontwijk-nabeeld, betere idle-pose, gamepad-test, hero-gezicht verfijnen.

## Fase 2: open wereld (episch en helder)

- [ ] 2.1 Terrein in chunks met streaming en LOD, groter dan de testvallei.
- [x] 2.2a Gras met wind (MultiMesh, 14.000 plukjes rond de arena, vervaagt op afstand).
- [ ] 2.2b Terreinshader verfijnen (paden, rotsrichels). Klif onder de toren is al vervangen door een gefacetteerde rots met grasrichels.
- [ ] 2.3 Water (meer en rivier) met golvende shader.
- [x] 2.4 Hemel met wolken (eigen sky-shader), dag-nachtcyclus van 16 minuten met maan en sterren, mist en ambient per tijdstip.
- [ ] 2.5 Landmarks: hoofdberg, Veilspire, ruïnes, een dorp.
- [ ] 2.6 Snelle verplaatsing: glijden (glider) of klimmen.
- [ ] 2.7 Deeltjes in de wereld: bladeren, vuurvliegjes, stof.

## Fase 3: RPG-systemen en character creator

- [ ] 3.1 Keuze-issue: opzet character creator.
- [ ] 3.2 Character creator: lichaamsvorm, gezicht, haar, kleuren, klasse.
- [ ] 3.3 Stats, XP en levels.
- [ ] 3.4 Inventaris, loot en uitrusting zichtbaar op het personage.
- [ ] 3.5 Opslaan en laden.

## Fase 4: verhaal (serieus en episch)

- [ ] 4.1 Lore en hoofdconflict uitwerken in DESIGN.md.
- [ ] 4.2 NPC's en dialoogsysteem.
- [ ] 4.3 Questsysteem met quest-log.
- [ ] 4.4 Hoofdquest van 3 tot 5 quests.

## Fase 5: kerkers (donker en grimmig)

- [ ] 5.1 Eerste kerker: gedempt licht, fakkels, vervallen steen.
- [ ] 5.2 Meer vijandtypes.
- [ ] 5.3 Eindbaas met fases.

## Fase 6: geluid en afwerking

- [ ] 6.1 Geluidseffecten en muziek (procedureel of CC0).
- [ ] 6.2 Hoofdmenu en instellingen (grafische kwaliteit, gevoeligheid).
- [ ] 6.3 Toegankelijkheid.

## Bekende verbeterpunten (uit zelfcontrole)

- Bomen en rotsen zijn losse meshes; naar MultiMesh zodra er meer van zijn.

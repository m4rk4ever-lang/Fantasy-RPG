# Roadmap

Blokken van ongeveer 60 minuten. De bouwagent pakt elke run het eerste niet-afgevinkte blok (feedback gaat voor).

**Werkwijze bij de start van elke run:** naast issues met label `feedback` ook alle bestanden in de map `feedback/` lezen (behalve README). Verwerkte bestanden gaan naar `feedback/verwerkt/` met een notitie wat er gedaan is. Deze map is op verzoek van de eigenaar toegevoegd (13-11-2026).

## Eerst volgende run (uit zelfcontrole)

- **Prestaties meten in de browser.** Eigenaar laten bevestigen of de haperingen bij treffers weg zijn. Zo niet: schaduwafstand en aantal schaduwcasters verlagen, grasdichtheid achter een kwaliteitsinstelling.

- **Pad naar de Veilspire.** De rots heeft nu richels, maar je kunt er nog niet op. Een pad of trap langs de richels omhoog.
- **Bergring overdag** is te vlak grijs-wit. Meer leisteenblauw in de flanken, scherpere sneeuwgrens.

## Koers (feedback eigenaar 13-11-2026)

**Eerst het eerste gebied en de grote stappen af, dan pas de wereld uitbouwen.** Geen nieuwe gebieden, chunk-streaming of extra landmarks tot de verticale slice hieronder klaar is. Zo verbranden we geen tijd aan wereld terwijl het concept nog niet vaststaat.

**Structuur (eigenaar 13-11-2026):** RPG met MMORPG-gevoel, open wereld, deels lineaire questlijn, dungeons en raids onderweg, levelen in WoW-stijl tot **level 60**. Zie "Spelstructuur" in `docs/DESIGN.md`. De verticale slice dekt levels 1 tot ongeveer 5 en eindigt met de eerste kleine dungeon (de Veilspire zelf).

## Verticale slice: Warden's Vale en Saltwick (nu)

Doel: één gebied waarin de hele kernloop speelbaar is: praten, quest aannemen, vechten met skills, belonen, sterker worden, opslaan.

- [x] V.1 Mobs met aggro-afstand en leash: ze volgen je niet eindeloos, lopen terug en genezen.
- [x] V.2 Looproutes afbakenen: niet de zee in, wel over steigers. Hekken en dorpsspullen hebben botsing, het hek heeft een poort.
- [x] V.2b Padvinding voor klik-om-te-lopen (raster met A*, 1,25 m, om huizen, hekken, rotsen en water heen).
- [x] V.2c Rennen aan/uit (RuneScape), ontwijken geschrapt (eigenaar 13-11-2026).
- [ ] V.3 Klassen en skilltree: keuze-issue over opzet (welke klassen, hoe de boom eruitziet, hoe skills op de balk komen). Dan eerste klasse uitwerken.
- [ ] V.4 Stats, XP en levels, loot van Hollowed, eenvoudige inventaris.
- [x] V.5 Dialoogsysteem, eerste quest "Ashes on the Shore" bij Brenna Gale in Saltwick, questlog (L) en tracker in beeld.
- [x] V.1b Level cap 60, XP-curve in WoW-stijl, monster-XP geschaald op levelverschil, monsterlevel in de doelwitbalk.
- [x] V.6 Eerste kleine dungeon: **Undercroft of the Veilspire** (deur aan de voet van de rots). Drie ruimtes en twee gangen, fakkels, 4 Hollowed (level 3) en eindbaas **Aldric, the Lightless Keeper** (level 5, poise, fase 2 met extra vijanden). Baken aansteken sluit hoofdstuk I af, waarna het licht boven de Veilspire weer brandt.
- [ ] V.6b Pad omhoog naar de Veilspire en het torenterras. Heiligdom met obelisken.
- [ ] V.13 Keuze-issue: raids solo met NPC-metgezellen, solo-geschaald of later echte multiplayer.
- [x] V.7 Opslaan en laden: automatisch elke 20 s en bij het sluiten van het tabblad, "Save game" en "New game" in het pauzemenu. Bewaart level, skills, trouw, rugzak, quests, actiebalk, rennen, auto retaliate en positie.
- [ ] V.8 Geluid: voetstappen, zwaard, treffers, golven, meeuwen, eenvoudige muziek.
- [ ] V.9 Modellen bijschaven: meer detail in held, Hollowed en huizen (RuneScape 3 is inmiddels gedetailleerd). Eventueel passende CC0-modellen zoeken.
- [ ] V.10 Prestaties en kwaliteitsinstelling (laag, midden, hoog).
- [ ] V.11 UI-afwerking volgens `docs/UI.md`: orbs voor health en resource, gebogen skillbalk met radiale cooldown, skilltree als echte boom, itemiconen, portretten.
- [ ] V.12 Keuze-issue: resource per klasse (Fury, Focus, Mana, Faith, Corruption of anders).

## Fase 1: speelbare kern (snel en vloeiend)

- [x] **1.1 Fundament.** Projectstructuur, CI naar GitHub Pages, testgebied met belichting en mist, third-person controller (lopen, sprinten, springen met coyote time, dash met i-frames), SpringArm-camera (muis en gamepad, FOV bij sprinten), procedureel personage met loopcyclus, minimale HUD, rooktests en screenshotscript.
- [x] **1.2 Gevecht: aanvallen.** Lichte combo van 3 slagen, zware aanval, luchtaanval, annuleren met ontwijken, stamina. Zwaard-trail.
- [x] **1.3 Vijand: Hollowed.** Eén vijandtype met state machine (idle, achtervolgen, aanloop, aanval, getroffen, dood), hitboxes en hurtboxes, schade en dood.
- [x] **1.4 Treffergevoel en lock-on.** Hitstop, impactdeeltjes, camera shake bij treffers, knockback, lock-on met doelwissel.
- [x] **1.5 HUD en pauzemenu.** Vijandbalk boven doelwit, pauzemenu (hervatten, besturing, gevoeligheid), muisvangst netjes regelen.
- [x] **1.6a Afwerking kern.** Stof bij sprintstappen, landen en ontwijken.
- [x] **1.7 RuneScape-besturing (feedback).** Camera draait niet zelf (middelste muisknop, pijltjes), zoomen met scrollwiel, klik op monster om te lopen en aan te vallen, klik op de grond om te lopen, skills 1-4 met cooldowns en skillbalk, auto retaliate (R).
- [x] **1.8 Prestaties gevecht (feedback).** Effecten in pools, materialen voorverwarmd, zachtere hitstop, bomen en dorp samengevoegd.
- [x] **1.9 Low-poly anatomie (feedback).** Held, dorpelingen en Hollowed als gefacetteerde lichamen met echte verhoudingen. Rijkere uitrusting.
- [ ] **1.6b Afwerking kern (later, eigenaar 13-11-2026).** Betere idle-pose, gamepad-test. Ontwijken is geschrapt.
- [ ] **1.10 Skills uitbreiden (later, eigenaar 13-11-2026).** Skill-effecten per skill (Whirlwind-spoor, Surge-streep, groene heal-gloed), adrenaline of resource zoals in RuneScape (eerst keuze-issue).

## Fase 2: open wereld (episch en helder)

- [ ] 2.1 Terrein in chunks met streaming en LOD, groter dan de testvallei. **Pas na de verticale slice.**
- [x] 2.2a Gras met wind (MultiMesh, 14.000 plukjes rond de arena, vervaagt op afstand).
- [ ] 2.2b Terreinshader verfijnen (paden, rotsrichels). Klif onder de toren is al vervangen door een gefacetteerde rots met grasrichels.
- [x] 2.3a Zee in de baai met golven, schuimranden en strand (diepte per vertex, geen depth texture).
- [ ] 2.3b Rivier met kapotte brug (Havenhythe-inspiratie), waterval vanaf de bergen.
- [x] 2.4 Hemel met wolken (eigen sky-shader), dag-nachtcyclus van 16 minuten met maan en sterren, mist en ambient per tijdstip.
- [x] 2.5a Vissersdorp Saltwick aan de baai: vakwerkhuizen, steigers, boten, rook, meeuwen, dorpelingen. Zwevende kroonscherf boven de vallei.
- [ ] 2.5b Pad omhoog naar de Veilspire, interieur van de toren. Heiligdom met obelisken (Ascendanten).
- [ ] 2.5c **Pas na de verticale slice.** Tweede gebied met monumentale architectuur en gloeiende runen (sfeerreferentie eigenaar 13-11-2026): bijvoorbeeld een smidsestad van the Ashen Host.
- [ ] 2.6 Snelle verplaatsing: glijden (glider) of klimmen.
- [x] 2.7a Leven rond de speler: stuifmeel overdag, vuurvliegjes 's nachts, vlinders.
- [ ] 2.7b Vallende bladeren bij bomen, vogels in het bos, dieren (herten, konijnen).

## Fase 3: RPG-systemen en character creator

- [ ] 3.0 Klassen en skilltree: zie V.3.
- [ ] 3.1 Keuze-issue: opzet character creator.
- [ ] 3.2 Character creator: lichaamsvorm, gezicht, haar, kleuren, klasse.
- [ ] 3.3 Stats, XP en levels.
- [ ] 3.4 Inventaris, loot en uitrusting zichtbaar op het personage.
- [ ] 3.5 Opslaan en laden.

## Fase 4: verhaal (serieus en episch)

- [x] 4.1 Lore en hoofdconflict uitwerken in DESIGN.md (Ascendanten, facties, the Unsung).
- [ ] 4.2 NPC's en dialoogsysteem.
- [ ] 4.3 Questsysteem met quest-log.
- [ ] 4.4 Hoofdquest van 3 tot 5 quests.

## Fase 5: kerkers (donker en grimmig)

- [ ] 5.1 Eerste kerker: gedempt licht, fakkels, vervallen steen.
- [ ] 5.2 Meer vijandtypes.
- [ ] 5.3 Eindbaas met fases. Sfeer: groots en dreigend, stormlucht, sierlijke stof met goudrand (referentie eigenaar 13-11-2026), eigen ontwerp.

## Fase 6: geluid en afwerking

- [ ] 6.1 Geluidseffecten en muziek (procedureel of CC0).
- [ ] 6.2 Hoofdmenu en instellingen (grafische kwaliteit, gevoeligheid).
- [ ] 6.3 Toegankelijkheid.

## Bekende verbeterpunten (uit zelfcontrole)

- Bomen en rotsen zijn losse meshes; naar MultiMesh zodra er meer van zijn.

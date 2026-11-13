# Changelog

## 13-11-2026 (tweede sessie, met de eigenaar live)

Feedback van de eigenaar verwerkt: besturing in RuneScape-stijl, haperingen bij gevechten, lore, een mooiere en levendigere wereld, betere personages en auto retaliate.

**Gebouwd**
- **Camera zoals RuneScape:** draait nooit zelf. Draaien met middelste muisknop (slepen), pijltjes of rechterstick. Zoomen met scrollwiel of + en -. Vrije muiscursor.
- **Klikgevecht met skills (hybride, gekozen door de eigenaar):** klik op een monster: lopen en automatisch aanvallen. Klik op de grond: lopen. Skills op 1 tot 4 met cooldowns en een skillbalk: Cleave, Surge Strike (dash naar doelwit, onkwetsbaar), Whirlwind (draait twee keer rond) en Second Wind (heal). WASD en ontwijken werken nog steeds. Q kiest het dichtstbijzijnde monster.
- **Auto retaliate:** standaard aan, R of de knop rechtsonder. Een stilstaande held vecht terug tegen een monster dat hem raakt.
- **Prestaties:** effecten zitten in pools en materialen worden bij de start voorverwarmd (geen shadercompilatie midden in een gevecht). Treffer-flits op vijanden alleen actief tijdens de flits. Hitstop vertraagt tot 20% in plaats van bijna te bevriezen. Bomen in 5 MultiMeshes, dorp in 2 draw calls.
- **Lore** herschreven: Aldmere gezongen door zeven Ascendanten, zes facties met elk een eigen gelijk, een gewiste zevende god, de speler als neutrale Wachter die moet kiezen.
- **Wereld:** de vallei loopt uit op een baai met zee, golven, schuimranden en strand. Vissersdorp Zoutwijk (Havenhythe als richting): vakwerkhuizen op stenen voeten, steigers met lantaarn, deinende boten, rook, vissenrekken, meeuwen, drie dorpelingen die rondlopen. Stuifmeel en vlinders overdag, vuurvliegjes 's nachts. Een zwevende scherf van de Kroon met runenringen boven de vallei.
- **Personages:** held, dorpelingen en Leeghulzen opnieuw opgebouwd als gefacetteerde low-poly lichamen met echte verhoudingen (naar de anatomie-referentie). Held met kuras met goudrand, gelaagde schouderstukken, tabard, cape met franje en een sierlijk zwaard met gloeiende steen. Leeghulzen mager en gebogen, met gescheurde gewaden en klauwen.

**Feedback verwerkt**
- `feedback/` (tekstbestand 1): framedrops, RuneScape-camera met zoom, klikgevecht met skills, lore met goden en facties, omgeving statisch en niet mooi, Havenhythe. Zie `feedback/verwerkt/2026-11-13-feedback.md`.
- `feedback/` (beelden): anatomie, sfeer, uitrusting. Zie `feedback/verwerkt/2026-11-13-beelden.md`.
- `feedback/` (tekstbestand 2): auto retaliate. Zie `feedback/verwerkt/2026-11-13-auto-retaliate.md`.

**Speel het:** https://m4rk4ever-lang.github.io/Fantasy-RPG/

**Screenshots**
![Overzicht](docs/screenshots/2026-11-13b/01_overzicht.png)
![Gevecht](docs/screenshots/2026-11-13b/02_gevecht.png)
![Landmark met kroonscherf](docs/screenshots/2026-11-13b/03_landmark.png)
![Held en Leeghuls](docs/screenshots/2026-11-13b/04_held.png)
![Avond in Zoutwijk](docs/screenshots/2026-11-13b/05_avond.png)
![Zoutwijk](docs/screenshots/2026-11-13b/06_dorp.png)

**Zelfcontrole**
- Diepte: ja, sterk in het dorpsbeeld (steiger, huizen, heuvels, bergen). | Landmark: Veilspire en de zwevende kroonscherf. | Palet: ja. Koningsblauwe daken, steenkleurige muren, hemelblauw water. Gras van dichtbij is nog wat fel. | Game of demo: game. Het dorp en de avond zien eruit als een spel. | Zwakste deel: het gras dichtbij (fel en egaal) en de bergring overdag.

**Prestaties:** hier niet te meten (software-rendering). De web-build start zonder fouten in headless Chromium. Draw calls flink omlaag door MultiMesh en samengevoegde meshes. **Graag testen op je laptop of de haperingen bij treffers weg zijn.**

**Voorstellen voor SMAAK.md**
- Onder **Gevecht** de nieuwe richting vastleggen: "Hybride RuneScape-stijl: klik op monsters om aan te vallen, skills op 1-4, auto retaliate. Ontwijken en WASD blijven mogelijk." Nu staat er alleen "snel en vloeiend, combo's".
- Onder **Grafische stijl**: "Personages als gefacetteerde low-poly lichamen met echte verhoudingen."
- Een regel voor de camera: "Camera draait niet zelf mee, de speler draait en zoomt (RuneScape)."
- Onder **Sfeer per gebied** eventueel de kust en Havenhythe als referentie toevoegen.

**Problemen en beslissingen**
- Gevecht in RuneScape-stijl botst met SMAAK.md ("combo's, veel beweging"). Gevraagd aan de eigenaar en gekozen voor hybride: klik en skills, met behoud van ontwijken en combo's.
- Het eerste beeld (Elden Ring-artwork) is later door de eigenaar vervangen. Alleen als sfeer gebruikt, niets nagemaakt. Let op: officiële artwork van andere games in een publieke repo kan auteursrechtelijk beschermd zijn.
- Land ligt nu 1,3 m hoger (`LAND_BASE`) zodat het strand alleen aan de kust ligt. Trappen en ruïnes staan nu op de terreinhoogte.
- Gedelegeerd: skillbalk (Sonnet, ging goed) en een samenvatting van de Havenhythe-wikipagina (web-fetch). Daarmee 3 subagents in deze run.
- Haperingen konden we hier niet meten. De oorzaak die het meest voor de hand lag (shaders compileren bij het eerste vonkje of de eerste flits in WebGL, plus de bijna-bevriezing van de hitstop) is aangepakt.

**Volgende run**
- Bevestiging van de eigenaar over de prestaties. Zo nodig: schaduwen en grasdichtheid achter een kwaliteitsinstelling.
- Pad naar de Veilspire, rivier met kapotte brug, heiligdom met obelisken.
- Skill-effecten per skill. Keuze-issue: adrenaline of een andere resource zoals in RuneScape.

## 13-11-2026

Eerste run. Repo opgezet en de speelbare kern van fase 1 gebouwd, plus twee blokken uit fase 2 (gras en hemel) omdat de tijd het toeliet.

**Gebouwd**
- Werktitel **Veilspire: The Sundered Crown**, met lore op hoofdlijnen in `docs/DESIGN.md`.
- `docs/SMAAK.md` aangemaakt met de inhoud van de eigenaar.
- Godot 4.7.2 (Compatibility-renderer), web-export single-threaded, GitHub Actions bouwt, test en publiceert naar GitHub Pages. Labels `feedback`, `keuze`, `gedaan` aangemaakt via een workflow.
- Third-person controller: lopen, sprinten, springen (coyote time, buffer, variabele hoogte), dash met i-frames en luchtdash. Momentum via acceleratie.
- Camera: SpringArm3D met botsing, muis en gamepad, FOV-kick bij sprinten en ontwijken, trauma-shake.
- Procedurele held in het palet (koningsblauw, leisteenblauw, staal) met loopcyclus, leunen en squash en stretch, alles in code.
- Gevecht: lichte combo van 3 slagen, zware slam met schokgolf, 2 luchtaanvallen, combo-buffer, zachte auto-aim, ontwijken annuleert altijd. Stamina blokkeert aanvallen nooit.
- Treffergevoel: hitstop, vonken met flits, zwaardspoor, camera shake, knockback, witte treffer-flits op vijanden.
- Eerste vijand: **Hollowed Warden** (Leeghuls) met state machine en duidelijke telegraph. Komt na 7 seconden terug.
- Lock-on met marker, doelwissel via muis- of stick-flick, vijandbalk bovenin de HUD.
- Pauzemenu (hervatten, besturing, gevoeligheid, herstarten) en schade-flits.
- Testvallei: terrein met kliffen en heuvels, Veilspire op een klif, ruïnes met boog, bergring met grote sneeuwtop, bomen met wind.
- Hemel-shader met wolken, zon, maan en sterren. Dag-nachtcyclus (16 minuten). Gras met wind (14.000 plukjes, MultiMesh). Stof bij sprinten, landen en ontwijken.
- Map `feedback/` met uitleg, op verzoek van de eigenaar.
- Na de eerste zelfcontrole: de ronde klif onder de Veilspire vervangen door een gefacetteerde rots met grasrichels en losse rotsblokken aan de voet. Mist iets lichter, zodat de bergring meer vorm houdt.

**Feedback verwerkt**
- Geen open feedback-issues.
- Verzoek van de eigenaar tijdens de run: map `feedback/` aangemaakt (met `README.md` en `verwerkt/`). Werkwijze vastgelegd in README en ROADMAP zodat volgende runs de map ook lezen.

**Speel het:** https://m4rk4ever-lang.github.io/Fantasy-RPG/

**Screenshots**
![Overzicht](docs/screenshots/2026-11-13/01_overzicht.png)
![Gevecht](docs/screenshots/2026-11-13/02_gevecht.png)
![Landmark](docs/screenshots/2026-11-13/03_landmark.png)
![Held en Leeghuls](docs/screenshots/2026-11-13/04_held.png)
![Avond](docs/screenshots/2026-11-13/05_avond.png)

**Zelfcontrole**
- Diepte: ja. Gras en held voor, ruïnes en bomen in het midden, klif, toren en bergring achter. | Landmark: ja, de Veilspire op de klif, ook van ver zichtbaar. | Palet: grotendeels. Held en toren volgen het palet. Overdag is het gras iets te licht mintgroen en de bergen te grijs-wit. | Game of demo: eerder game, vooral het avondbeeld en het gevechtsbeeld. Het daglicht oogt nog wat vlak. | Zwakste deel: eerst de klif onder de toren (een ronde kei). Die is in dezelfde run vervangen. Nu is de bergring overdag het zwakst: te grijs-wit en vlak. Staat bovenaan de roadmap.

**Prestaties:** niet betrouwbaar te meten hier (alleen software-rendering, 2 tot 3 fps). Headless physics draait op de 60 Hz-limiet (16,7 ms per frame). De web-build start zonder fouten in headless Chromium. Graag een meting op een echte laptop.

**Voorstellen voor SMAAK.md**
- Geen.

**Problemen en beslissingen**
- Godot 4.7.2 is de nieuwste stabiele versie in `godotengine/godot-builds`. Vastgelegd in DESIGN.md.
- De rooktests vonden een echte bug: hitstop kon blijven hangen (tijd op 3%) als de timer net te vroeg afging. Opgelost met een real-time check elke frame, plus een test.
- Labels kon ik niet direct aanmaken. Opgelost met de workflow `.github/workflows/labels.yml`.
- Roadmap licht aangepast: blok 2.2 en 2.4 naar voren gehaald, omdat chunk-streaming (2.1) pas zin heeft als de wereld groter wordt. 1.6 en 2.2 gesplitst.
- Vijanden botsen niet met de held, zodat je met een dash door ze heen kunt. Aggro-afstand 13 m zodat je bij de start even rust hebt.
- Gedelegeerd: pauzemenu en vijandbalk in de HUD aan een Sonnet-subagent. Ging goed. Code nagekeken, werkt met de echte vijand.
- Geen keuze-issue deze run. Het eerste grote keuzemoment is de opzet van de character creator (fase 3).
- Geen externe assets. Alles is procedureel.

**Volgende run**
- Bergring overdag meer leisteenblauw en vorm. Pad omhoog naar de Veilspire.
- Blok 1.6b: ontwijk-nabeeld, betere idle-pose, gezicht van de held.
- Daarna fase 2: terreinshader (2.2b), water (2.3).

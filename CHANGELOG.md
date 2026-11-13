# Changelog

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
- Diepte: ja. Gras en held voor, ruïnes en bomen in het midden, klif, toren en bergring achter. | Landmark: ja, de Veilspire op de klif, ook van ver zichtbaar. | Palet: grotendeels. Held en toren volgen het palet. Overdag is het gras iets te licht mintgroen en de bergen te grijs-wit. | Game of demo: eerder game, vooral het avondbeeld en het gevechtsbeeld. Het daglicht oogt nog wat vlak. | Zwakste deel: de klif onder de toren (een ronde kei) en de bergring overdag. Staat bovenaan de roadmap.

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
- Klif onder de toren tot echte rotswand maken, bergring overdag meer leisteenblauw.
- Blok 1.6b: ontwijk-nabeeld, betere idle-pose, gezicht van de held.
- Daarna fase 2: terreinshader (2.2b), water (2.3).

# Ontwerpdocument: Veilspire: The Sundered Crown

Werktitel: **Veilspire: The Sundered Crown**.
Episch third-person action-adventure RPG in een high-fantasy wereld. Godot 4, speelbaar in de browser.

`docs/SMAAK.md` is leidend. Dit document volgt het en werkt het uit.

## Pitch

Het rijk Aldmere hield duizend jaar stand onder de Kroon van Zeven Hemelen. Toen de kroon brak, scheurde de lucht. Uit de scheuren komt de Sluier: een stille mist die steen laat vergeten wat het was en mensen wat ze waren. Langs de randen van het rijk staan de Veilspires, oude wachttorens op kliffen, gebouwd om de Sluier tegen te houden. Hun lichten gaan één voor één uit.

De speler is een Wachter zonder naam, gewekt in een vallei onder de eerste toren. Doel: de scherven van de kroon terugvinden voordat de Sluier het hart van Aldmere bereikt.

## Lore op hoofdlijnen

- **De Gebroken Kroon.** Zeven scherven, elk gebonden aan een hemelstreek en een oude macht. Wie een scherf draagt krijgt een gave (later: glijden, klimmen, tijd vertragen).
- **De Sluier.** Geen leger maar een kracht. Ze maakt van levende wezens Leeghulzen (Hollowed): wezens die alleen nog de vorm van hun vroegere zelf herhalen. Eerste vijandtype.
- **De Wachters.** Een orde die de torens bemande. Uitgestorven, op de speler na.
- **Hoofdconflict.** De Sluier wordt gestuurd door de Vergeten Koning, die de kroon zelf brak om de dood te ontlopen. Uitwerking in fase 4.

Toon: serieus en episch, weinig humor.

## Art direction per gebied

| Gebied | Sfeer | Palet | Kenmerken |
|---|---|---|---|
| Wachtersvallei (start, open wereld) | episch en helder | hemelblauw #6EC3F0, leisteenblauw #5B6C9E, gras #4CB46A, steen #E6E1D3, koningsblauw #3D5BA9 | groene vallei, Veilspire op klif, besneeuwde bergring, ruïnes |
| Kerkers (fase 5) | donker en grimmig | nachtgrijs #353A42, aarde #4A483E, silhouet #1E2125, maanlicht #C9C6B8, vuur #D9552E | gedempt licht, fakkels, vervallen steen |

Algemene stijl: gestileerd, strakke vormen, duidelijke silhouetten, sfeer uit licht, mist en kleur. Liever weinig objecten die af ogen dan veel ruwe.

Het hoofdpersonage draagt koningsblauw (tunic), leisteenblauw (cape) en licht steen-kleurig plaatwerk. Dat bindt held en wereld aan hetzelfde palet.

## Besturing

| Actie | Toetsenbord en muis | Gamepad |
|---|---|---|
| Lopen | WASD / pijltjes | linkerstick |
| Camera | muis (klik om te vangen) | rechterstick |
| Sprinten | Shift | linkerstick indrukken |
| Springen | Spatie | A |
| Ontwijken (dash) | rechtermuis / Alt / C | B |
| Lichte aanval | linkermuis / J | X |
| Zware aanval | E / K | Y |
| Lock-on | Q / middelste muis | rechterstick indrukken |
| Pauze | Esc / P | Start |

## Kernloop

Verkennen → vechten → beloning (loot, XP, scherven) → nieuwe gaven openen nieuwe gebieden → verkennen.
Gevecht: snel en vloeiend, combo's, ontwijken kan altijd en annuleert aanvallen. Stamina is vergevingsgezind.

## Technische keuzes

- **Engine:** Godot **4.7.2-stable** (vast). Upgraden alleen bewust en met melding in de changelog.
- **Renderer:** Compatibility (WebGL 2). Geen SDFGI of volumetrische mist. Sfeer via eigen shaders, Environment-mist (afstand en hoogte), glow en kleurcorrectie.
- **Web-export:** preset `Web`, single-threaded (geen SharedArrayBuffer), naar `export/web/index.html`. GitHub Actions publiceert naar GitHub Pages.
- **Code:** getypte GDScript. Kleine scripts met één verantwoordelijkheid. Scènes worden grotendeels in code opgebouwd, zodat alles leesbaar diffbaar is.
- **Autoloads:** alleen `InputSetup` (alle invoeracties op één plek).
- **Physics-lagen:** 1 world, 2 player, 3 enemy, 4 hitbox.
- **Personage:** procedureel opgebouwd uit primitieve meshes (`HeroModel`), animatie volledig in code (loopcyclus, leunen, squash en stretch). Later eventueel CC0-modellen.
- **Wereld:** terrein uit een hoogtefunctie (`TestArena.height_at`), mesh plus `HeightMapShape3D`. Bergring buiten de speelzone is alleen visueel.
- **Tests:** `tools/run_tests.gd` (headless rooktests). Screenshots: `tools/screenshot.gd`.

## Bestandsoverzicht

- `scripts/autoload/input_setup.gd` invoeracties
- `scripts/player/player.gd` controller; `hero_model.gd` model en animatie
- `scripts/camera/camera_rig.gd` camera
- `scripts/world/test_arena.gd` testgebied
- `scripts/ui/hud.gd` HUD
- `shaders/terrain.gdshader`, `shaders/foliage.gdshader`

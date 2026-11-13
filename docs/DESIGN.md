# Ontwerpdocument: Veilspire: The Sundered Crown

Werktitel: **Veilspire: The Sundered Crown**.
Episch third-person action-adventure RPG in een high-fantasy wereld. Godot 4, speelbaar in de browser.

`docs/SMAAK.md` is leidend. Dit document volgt het en werkt het uit.

## Pitch

Aldmere werd niet gebouwd maar gezongen. Zeven hogere machten, de Ascendanten, zongen de wereld uit de Stilte. Daarna vochten ze om wie de laatste noot mocht zingen. Die oorlog, de Dissonant, verbrandde halve continenten. Hij eindigde met een pact: elke Ascendant legde een deel van zijn stem in een kroon, de Kroon van Zeven Hemelen, en zweeg. Sindsdien spreken de goden alleen nog via hun volgelingen.

Duizend jaar later is de kroon gebroken. De stemmen keren terug, de facties van de Ascendanten wapenen zich, en waar hun stemmen botsen kruipt de Stilte de wereld weer in: de Sluier, een mist die alles laat vergeten wat het was. De speler is de laatste Wachter, hoeder van een kroon die niet meer bestaat. Neutraal, voorlopig.

## Lore op hoofdlijnen

Richting (feedback eigenaar 13-11-2026): een wereld geschapen door goden en hogere machten, met volgelingen en facties. Raakvlakken met RuneScape, World of Warcraft en Elden Ring, maar met een eigen kern: **schepping door zang, vergeten als vijand, en een neutrale hoeder die moet kiezen.**

### De Ascendanten en hun facties

| Ascendant | Domein | Factie | Karakter van de factie |
|---|---|---|---|
| **Aurel, de Dageraadsmaker** | licht, orde, wet | **De Gouden Lantaarn** | paladijnen en rechters in witte steden. Willen de kroon herbouwen, onder hun wet. |
| **Morvaine, de Getijdenmoeder** | zee, verandering, handel | **De Zoutgebondenen** | kustclans, vissers, kapers. Vrijheid boven alles. Wantrouwen elke kroon. |
| **Vyrr, de Doornvader** | groei, verval, het wilde | **De Wortelgezworenen** | druïden en dierenvolk. Zien de Sluier als een noodzakelijke herfst. |
| **Kaeloth, de Sintelkoning** | oorlog, smidse, ambitie | **De Asheer** | legers en smeden. Willen de scherven als wapens. |
| **Isseth, de Gesluierde** | geheimen, dood, herinnering | **Het Bleke Archief** | geleerden en dodenbezweerders. Bewaren alles wat de Sluier wil wissen, tegen elke prijs. |
| **Orun, de Steenwachter** | bergen, volharding | **De Hoge Hold** | bergclans. Bouwden ooit de Veilspires met de Wachters. |
| **De Ongezongene** | onbekend | geen (nog) | de zevende stem is uit elke herinnering gewist. De Sluier klinkt als zijn zwijgen. |

### Kernconflict

- **Wie brak de kroon?** De Vergeten Koning, kampioen van de Ongezongene. Hij is uit de geschiedenis gewist, ook uit de herinnering van zijn eigen volk. Ontdekken wie hij was is de rode draad van het hoofdverhaal.
- **De scherven.** Zeven scherven, elk met een stem. Wie een scherf draagt krijgt een gave (later: glijden, klimmen, tijd vertragen) en hoort zijn Ascendant fluisteren.
- **De Sluier.** Wist herinnering. Levende wezens worden Leeghulzen (Hollowed): ze herhalen nog alleen de vorm van wat ze waren. De eerste vijanden zijn gevallen Wachters.
- **De Wachters.** Neutrale orde die de kroon bewaakte, bemand door volgelingen van alle zeven. Uitgestorven, op de speler na.
- **Keuze (fase 4 en later).** Elke factie wil de scherven. De speler kan ze teruggeven, de kroon herbouwen of de goden laten ontwaken. Reputatie per factie bepaalt welke quests, uitrusting en eindes openstaan.

### Wat het eigen maakt

- Goden zijn geen verre beelden maar stemmen die je hoort via scherven. Ze liegen soms.
- Vergeten is letterlijk: plekken, namen en NPC's kunnen uit de wereld verdwijnen als de Sluier wint. Het Archief kan ze terughalen.
- Geen goed-tegen-kwaad. Elke factie heeft gelijk vanuit haar eigen stem.

Toon: serieus en episch, weinig humor.

### Eerste gebied: Wachtersvallei en Zoutwijk

Een groene vallei die uitkomt op een baai. Aan de kust ligt **Zoutwijk**, een vissersdorp van de Zoutgebondenen: houten huizen op stenen voeten, steigers, bootjes, rook uit de schoorstenen. Boven de vallei de eerste Veilspire op een rots. Bij de ruïnes dwalen de Leeghulzen. Inspiratie voor sfeer en opbouw: de kustregio Havenhythe in RuneScape (alleen als richting, niets overgenomen).

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
| Lopen | WASD, of klik op de grond | linkerstick |
| Aanvallen | klik op een monster (lopen en auto-aanval) | X |
| Skills | 1, 2, 3, 4 (of klik op de balk) | Y, RB, LB, Back |
| Camera draaien | middelste muisknop slepen of pijltjes | rechterstick |
| Zoomen | scrollwiel of + en - | - |
| Sprinten | Shift | linkerstick indrukken |
| Springen | Spatie | A |
| Ontwijken (dash) | rechtermuis / Alt / C | B |
| Dichtstbijzijnde doelwit | Q | rechterstick indrukken |
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
- **Hemel en tijd:** eigen sky-shader (`shaders/sky.gdshader`) met wolken, zon, maan en sterren. `DayNight` stuurt zon, maan, mist, ambient en hemelkleuren via keyframes. Ambient is een vaste kleur per tijdstip (goedkoper dan sky-radiance bij een bewegende hemel). Nachten blijven leesbaar.
- **Gras:** één `MultiMeshInstance3D` met plukjes van 5 sprieten, windshader, vervaagt tussen 34 en 52 m.
- **Gevecht:** `PlayerCombat` met aanvallen als data (windup, active, recovery, pose van/naar). Treffers via een vergevingsgezinde boog voor de held, met zachte auto-aim. Ontwijken annuleert altijd. Hitstop via `Engine.time_scale`, elke frame in real time gecontroleerd zodat hij nooit kan blijven hangen.
- **Vijand:** `Hollow` (Leeghuls), state machine idle, chase, windup, attack, recover, stagger, dead. Elke treffer onderbreekt de vijand (vergevingsgezind). Duidelijke telegraph: ogen lichten op, arm gaat omhoog.
- **Doelwit en klikken:** `ClickController` kiest monsters onder de muis (vergevingsgezind, 0,9 m rond de muisstraal) of loopt naar een aangeklikt punt. `LockOn` toont marker, rode ring en HUD-balk; Q wisselt naar het dichtstbijzijnde monster. De camera draait nooit zelf (RuneScape-stijl).
- **Skills:** `PlayerCombat.SKILLS`: Cleave (1), Surge Strike (2, dash naar doelwit met onkwetsbaarheid), Whirlwind (3), Second Wind (4, heal). Cooldowns in de skillbalk (`SkillBar`).
- **Auto retaliate:** standaard aan (R of knop rechtsonder). Een stilstaande held zonder opdracht valt het monster aan dat hem raakt.
- **Personages:** `HeroModel` bouwt held en dorpelingen uit `MeshKit.loft`: elliptische ringen per lichaamsdeel, gefacetteerd (flat shading), kleding per ringband via vertex colors, harnas als aparte metalen schil. Per bewegend lichaamsdeel één stof- en één metaal-mesh. `armored` en `with_sword` schakelen harnas, cape en zwaard. De Leeghuls gebruikt dezelfde techniek met magere verhoudingen.
- **MeshKit:** samengevoegde meshes met vertex colors (box, gable, cylinder, loft, wedge). Het hele dorp is twee draw calls (hout/steen en gloeiende ramen).
- **Wereld:** `TestArena.height_at` heeft nu een kust: alles verder dan ~42 m richting de baai (`SEA_DIR`) zakt naar de zeebodem. Land ligt 1,3 m boven zeeniveau, zand alleen op het strand. `Village` bouwt Zoutwijk, `Villager` laat dorpelingen routes lopen, `SkyShard` is de zwevende kroonscherf, `Ambience` geeft stuifmeel, vuurvliegjes en vlinders rond de speler. Bomen staan in 5 MultiMeshes.
- **Water:** `shaders/water.gdshader`. Diepte per vertex uit het terrein (vertex color R) stuurt kleur en schuim, zonder depth texture. Ver weg een vlak met dezelfde shader.
- **Prestaties:** effecten zitten in pools en alle materialen worden in de eerste frames voorverwarmd, zodat WebGL tijdens gevechten geen shaders compileert. Hitstop vertraagt tot 20% in plaats van bijna te bevriezen.
- **Tests:** `tools/run_tests.gd` (headless rooktests). Screenshots: `tools/screenshot.gd`.

## Bestandsoverzicht

- `scripts/autoload/input_setup.gd` invoeracties
- `scripts/player/player.gd` controller; `hero_model.gd` model en animatie
- `scripts/camera/camera_rig.gd` camera
- `scripts/world/test_arena.gd` testgebied
- `scripts/player/player_combat.gd` aanvallen; `lock_on.gd` lock-on
- `scripts/enemies/hollow.gd` Leeghuls
- `scripts/fx/combat_fx.gd` hitstop, vonken, stof, slam-ring; `sword_trail.gd` zwaardspoor
- `scripts/world/day_night.gd` dag-nachtcyclus
- `scripts/world/mesh_kit.gd` samengevoegde low-poly meshes; `village.gd`, `villager.gd`, `sky_shard.gd`, `ambience.gd`
- `scripts/player/click_controller.gd` klikken op monsters en grond
- `scripts/ui/skill_bar.gd` skillbalk
- `scripts/ui/hud.gd` HUD; `pause_menu.gd` pauzemenu
- `shaders/terrain.gdshader`, `foliage.gdshader`, `grass.gdshader`, `sky.gdshader`, `water.gdshader`

## Lore: de Leeghulzen

Hollowed Wardens: de Wachters die de Sluier als eersten raakte. Ze dragen nog de gerafelde kappen van de orde en dwalen bij de ruïnes waar ze ooit wacht hielden. Bleke ogen, botten die door de rug steken, slierten Sluier die van hun lijf afdrijven. Ze vallen uiteen als je ze verslaat, maar de Sluier vormt ze opnieuw.

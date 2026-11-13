# Ontwerpdocument: Veilspire: The Sundered Crown

Werktitel: **Veilspire: The Sundered Crown**.
Episch third-person action-adventure RPG in een high-fantasy wereld. Godot 4, speelbaar in de browser.

`docs/SMAAK.md` is leidend. Dit document volgt het en werkt het uit. UI-ontwerp staat apart in [`docs/UI.md`](UI.md).

**Taal (eigenaar 13-11-2026):** het hele spel is Engels, ook alle namen van plaatsen, goden, facties en vijanden. De Engelse namen in dit document zijn de officiële. Documentatie blijft Nederlands.

## Pitch

Aldmere werd niet gebouwd maar gezongen. Zeven hogere machten, the Ascendants, zongen de wereld uit the Hush. Daarna vochten ze om wie de laatste noot mocht zingen. Die oorlog, the Dissonance, verbrandde halve continenten. Hij eindigde met een pact: elke Ascendant legde een deel van zijn stem in een kroon, de Crown of Seven Heavens, en zweeg. Sindsdien spreken de goden alleen nog via hun volgelingen.

Duizend jaar later is de kroon gebroken. De stemmen keren terug, de facties van the Ascendants wapenen zich, en waar hun stemmen botsen kruipt the Hush de wereld weer in: the Veil, een mist die alles laat vergeten wat het was. De speler is the last Warden, hoeder van een kroon die niet meer bestaat. Neutraal, voorlopig.

## Lore op hoofdlijnen

Richting (feedback eigenaar 13-11-2026): een wereld geschapen door goden en hogere machten, met volgelingen en facties. Raakvlakken met RuneScape, World of Warcraft en Elden Ring, maar met een eigen kern: **schepping door zang, vergeten als vijand, en een neutrale hoeder die moet kiezen.**

### De Ascendants en hun facties

| Ascendant | Domein | Factie | Karakter van de factie |
|---|---|---|---|
| **Aurel, the Dawnwright** | licht, orde, wet | **The Gilded Lantern** | paladijnen en rechters in witte steden. Willen de kroon herbouwen, onder hun wet. |
| **Morvaine, the Tidemother** | zee, verandering, handel | **The Saltbound** | kustclans, vissers, kapers. Vrijheid boven alles. Wantrouwen elke kroon. |
| **Vyrr, the Thornfather** | groei, verval, het wilde | **The Rootsworn** | druïden en dierenvolk. Zien the Veil als een noodzakelijke herfst. |
| **Kaeloth, the Ember King** | oorlog, smidse, ambitie | **The Ashen Host** | legers en smeden. Willen de scherven als wapens. |
| **Isseth, the Veiled** | geheimen, dood, herinnering | **The Pale Archive** | geleerden en dodenbezweerders. Bewaren alles wat the Veil wil wissen, tegen elke prijs. |
| **Orun, the Stonewarden** | bergen, volharding | **The High Hold** | bergclans. Bouwden ooit the Veilspires met de Wardens. |
| **The Unsung** | onbekend | geen (nog) | de zevende stem is uit elke herinnering gewist. The Veil klinkt als zijn zwijgen. |

### Kernconflict

- **Wie brak de kroon?** The Forgotten King, kampioen van the Unsung. Hij is uit de geschiedenis gewist, ook uit de herinnering van zijn eigen volk. Ontdekken wie hij was is de rode draad van het hoofdverhaal.
- **The shards.** Zeven scherven, elk met een stem. Wie een scherf draagt krijgt een gave (later: glijden, klimmen, tijd vertragen) en hoort zijn Ascendant fluisteren.
- **The Veil.** Wist herinnering. Levende wezens worden the Hollowed: ze herhalen nog alleen de vorm van wat ze waren. De eerste vijanden zijn fallen Wardens.
- **The Wardens.** Neutrale orde die de kroon bewaakte, bemand door volgelingen van alle zeven. Uitgestorven, op de speler na.
- **Keuze (fase 4 en later).** Elke factie wil de scherven. De speler kan ze teruggeven, de kroon herbouwen of de goden laten ontwaken. Reputatie per factie bepaalt welke quests, uitrusting en eindes openstaan.

### Wat het eigen maakt

- Goden zijn geen verre beelden maar stemmen die je hoort via scherven. Ze liegen soms.
- Vergeten is letterlijk: plekken, namen en NPC's kunnen uit de wereld verdwijnen als the Veil wint. The Pale Archive kan ze terughalen.
- Geen goed-tegen-kwaad. Elke factie heeft gelijk vanuit haar eigen stem.

Toon: serieus en episch, met af en toe een grap (feedback eigenaar 13-11-2026). Humor zit in de mensen, niet in de goden: dorpelingen en reizigers mogen droog zijn, de grote verhaallijn blijft ernstig.

### Eerste gebied: Warden's Vale en Saltwick

Een groene vallei die uitkomt op een baai. Aan de kust ligt **Saltwick**, een vissersdorp van the Saltbound: houten huizen op stenen voeten, steigers, bootjes, rook uit de schoorstenen. Boven de vallei de eerste Veilspire op een rots. Bij de ruïnes dwalen de Hollowed. Inspiratie voor sfeer en opbouw: de kustregio Havenhythe in RuneScape (alleen als richting, niets overgenomen).

## Art direction per gebied

| Gebied | Sfeer | Palet | Kenmerken |
|---|---|---|---|
| Warden's Vale (start, open wereld) | episch en helder | hemelblauw #6EC3F0, leisteenblauw #5B6C9E, gras #4CB46A, steen #E6E1D3, koningsblauw #3D5BA9 | groene vallei, Veilspire op klif, besneeuwde bergring, ruïnes |
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
| Rennen aan/uit | Shift of Spatie, of de knop Run | linkerstick of B |
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
- **Vijand:** `Hollow` (Hollowed), state machine idle, chase, windup, attack, recover, stagger, dead. Elke treffer onderbreekt de vijand (vergevingsgezind). Duidelijke telegraph: ogen lichten op, arm gaat omhoog.
- **Doelwit en klikken:** `ClickController` kiest monsters onder de muis (vergevingsgezind, 0,9 m rond de muisstraal) of loopt naar een aangeklikt punt. `LockOn` toont marker, rode ring en HUD-balk; Q wisselt naar het dichtstbijzijnde monster. De camera draait nooit zelf (RuneScape-stijl).
- **Skills:** `PlayerCombat.SKILLS`: Cleave (1), Surge Strike (2, dash naar doelwit met onkwetsbaarheid), Whirlwind (3), Second Wind (4, heal). Cooldowns in de skillbalk (`SkillBar`).
- **Geen springen** (feedback 13-11-2026): springen paste niet bij klik-om-te-lopen. De held stapt zelf over randen tot 0,5 m (`Player._try_step`). Spatie is nu ontwijken. Trappen en steigers zijn op lopen ontworpen.
- **Dorpelingen praten:** korte zinnen boven hun hoofd als de held dichtbij staat (`Villager.lines`), met droge humor.
- **Auto retaliate:** standaard aan (R of knop rechtsonder). Een stilstaande held zonder opdracht valt het monster aan dat hem raakt.
- **Personages:** `HeroModel` bouwt held en dorpelingen uit `MeshKit.loft`: elliptische ringen per lichaamsdeel, gefacetteerd (flat shading), kleding per ringband via vertex colors, harnas als aparte metalen schil. Per bewegend lichaamsdeel één stof- en één metaal-mesh. `armored` en `with_sword` schakelen harnas, cape en zwaard. De Hollowed gebruikt dezelfde techniek met magere verhoudingen.
- **MeshKit:** samengevoegde meshes met vertex colors (box, gable, cylinder, loft, wedge). Het hele dorp is twee draw calls (hout/steen en gloeiende ramen).
- **Wereld:** `TestArena.height_at` heeft nu een kust: alles verder dan ~42 m richting de baai (`SEA_DIR`) zakt naar de zeebodem. Land ligt 1,3 m boven zeeniveau, zand alleen op het strand. `Village` bouwt Saltwick, `Villager` laat dorpelingen routes lopen, `SkyShard` is de zwevende kroonscherf, `Ambience` geeft stuifmeel, vuurvliegjes en vlinders rond de speler. Bomen staan in 5 MultiMeshes.
- **Water:** `shaders/water.gdshader`. Diepte per vertex uit het terrein (vertex color R) stuurt kleur en schuim, zonder depth texture. Ver weg een vlak met dezelfde shader.
- **Prestaties:** effecten zitten in pools en alle materialen worden in de eerste frames voorverwarmd, zodat WebGL tijdens gevechten geen shaders compileert. Hitstop vertraagt tot 20% in plaats van bijna te bevriezen.
- **Tests:** `tools/run_tests.gd` (headless rooktests). Screenshots: `tools/screenshot.gd`.

## Bestandsoverzicht

- `scripts/autoload/input_setup.gd` invoeracties
- `scripts/player/player.gd` controller; `hero_model.gd` model en animatie
- `scripts/camera/camera_rig.gd` camera
- `scripts/world/test_arena.gd` testgebied
- `scripts/player/player_combat.gd` aanvallen; `lock_on.gd` lock-on
- `scripts/enemies/hollow.gd` Hollowed
- `scripts/fx/combat_fx.gd` hitstop, vonken, stof, slam-ring; `sword_trail.gd` zwaardspoor
- `scripts/world/day_night.gd` dag-nachtcyclus
- `scripts/world/mesh_kit.gd` samengevoegde low-poly meshes; `village.gd`, `villager.gd`, `sky_shard.gd`, `ambience.gd`
- `scripts/player/click_controller.gd` klikken op monsters en grond
- `scripts/ui/skill_bar.gd` skillbalk
- `scripts/ui/hud.gd` HUD; `pause_menu.gd` pauzemenu
- `shaders/terrain.gdshader`, `foliage.gdshader`, `grass.gdshader`, `sky.gdshader`, `water.gdshader`

## Lore: de Hollowed

Hollowed Wardens: de Wardens die the Veil als eersten raakte. Ze dragen nog de gerafelde kappen van de orde en dwalen bij de ruïnes waar ze ooit wacht hielden. Bleke ogen, botten die door de rug steken, slierten Veil die van hun lijf afdrijven. Ze vallen uiteen als je ze verslaat, maar the Veil vormt ze opnieuw.


## Namenlijst (in-game, Engels)

| Soort | Naam |
|---|---|
| Wereld | Aldmere |
| Leegte vóór de schepping | the Hush |
| Godenoorlog | the Dissonance |
| Kroon | the Crown of Seven Heavens (the Sundered Crown) |
| Mist die herinnering wist | the Veil |
| Vijanden | the Hollowed (Hollowed Warden) |
| Orde van de speler | the Wardens |
| Torens | the Veilspires |
| Startgebied | Warden's Vale |
| Vissersdorp | Saltwick |
| Schurk | the Forgotten King, champion of the Unsung |
| Klassen | Vanguard, Ranger, Arcanist, Priest, Warlock |
| Facties | the Gilded Lantern, the Saltbound, the Rootsworn, the Ashen Host, the Pale Archive, the High Hold |

## Klassen, skilltree en trouw (keuze #1, 13-11-2026)

- Vijf klassen: **Vanguard** (melee), **Ranger** (boog), **Arcanist** (magie), **Priest** (licht en heling), **Warlock** (duistere magie). Gevechtsdriehoek zoals in RuneScape, met Priest en Warlock als aanvulling.
- Per klasse een skilltree met 3 takken van 4 knopen (`scripts/rpg/class_data.gd`). Elke knoop vraagt de vorige in zijn tak. 1 skillpunt per level. Actieve knopen ontgrendelen skills op de balk, passieve knopen geven stats.
- Vanguard is speelbaar: Blade (Cleave, Keen Edge, Whirlwind, Executioner), Bulwark (Second Wind, Iron Skin, Unbroken, Last Stand), Momentum (Surge Strike, Fleet Foot, Battle Rhythm, Relentless). De andere vier tonen hun boom als "soon".
- **Trouw (allegiance)** aan een factie kies je los in het karaktervenster (K). Heeft geen invloed op je klasse. Later: reputatie, quests en uitrusting per factie.
- XP: 40 per Hollowed. Benodigde XP per level: 80 + 45 × (level − 1). `Progression` beheert level, XP, punten, rangen en trouw.

## Loot, rugzak en quests (13-11-2026)

- **Loot:** een verslagen Hollowed laat een buidel vallen (`LootDrop`): altijd coins en Veil Dust, soms een Hollow Claw (35%) of Warden's Sigil (12%). Erover lopen pakt alles op. Meldingen linksonder.
- **Rugzak:** `Inventory`, 28 vakjes zoals RuneScape, stapelbare items, coins apart. Venster met I of de knop. Klik op eten om het op te eten (Salted Fish: +20 health).
- **Dialoog:** `DialogueWindow` met spreker, tekst en tot 4 antwoorden (klik of 1-4). Klik op een NPC (goudkleurige naam) om erheen te lopen en te praten.
- **Quests:** `QuestLog` met staten none, active en done. Eerste quest: **Ashes on the Shore** van **Brenna Gale**, havenmeester van Saltwick: breng 5 Veil Dust. Beloning 150 XP, 50 coins en 3 Salted Fish. Daarna opent **The Dark Spire** (het licht van de Veilspire is uit), uit te werken in V.6. Questlog met L, tracker rechtsboven.

## Bewegen (13-11-2026)

- **Geen ontwijken** (eigenaar: "dat kan bij RuneScape/WoW combat ook niet"). Verdedigen doe je met skills (Second Wind, Unbroken) en positie. Surge Strike blijft een aanval met korte onkwetsbaarheid.
- **Rennen is een schakelaar** (Shift, Spatie, knop "Run" naast de health-orb). Rennen kost stamina (4 per seconde), lopen of stilstaan laadt die op. Bij 0 loop je tot er weer stamina is.
- **Padvinding:** `NavGrid` maakt bij de start een raster van 1,25 m (in ongeveer 0,1 s). Een vakje is geblokkeerd bij een collider op lichaamshoogte, water zonder steiger of een te steile helling. Klikopdrachten volgen het A*-pad, het laatste stuk gaat recht.

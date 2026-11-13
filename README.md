# Veilspire: The Sundered Crown

Een episch third-person action-adventure RPG in een high-fantasy wereld. Gemaakt in Godot 4, speelbaar in de browser.

De Kroon van Zeven Hemelen is gebroken. Uit de scheuren in de lucht kruipt de Sluier, een mist die alles laat vergeten wat het was. Als laatste Wachter trek je langs de oude torens op de kliffen om de scherven terug te vinden.

**Speel het:** https://m4rk4ever-lang.github.io/Fantasy-RPG/

## Besturing

| Actie | Toetsenbord en muis | Gamepad |
|---|---|---|
| Lopen | WASD | linkerstick |
| Camera | muis (klik in het spel om de muis te vangen) | rechterstick |
| Sprinten | Shift | linkerstick indrukken |
| Springen | Spatie | A |
| Ontwijken | rechtermuis / Alt / C | B |
| Lichte aanval | linkermuis / J | X |
| Zware aanval | E / K | Y |
| Lock-on | Q / middelste muis | rechterstick indrukken |
| Pauze | Esc / P | Start |

## Feedback geven

Open een issue met het label `feedback`, of zet een bestand in de map [`feedback/`](feedback/README.md). Elke vrijdag leest de bouwagent die issues, verwerkt ze vóór nieuw werk en reageert met wat er gedaan is. Ontwerpkeuzes met varianten staan in issues met het label `keuze`: reageer met je voorkeur.

Alleen issues en reacties van de eigenaar (`m4rk4ever-lang`) worden als opdracht gezien.

## Documenten

- [docs/SMAAK.md](docs/SMAAK.md): smaakprofiel van de eigenaar
- [docs/DESIGN.md](docs/DESIGN.md): ontwerp en techniek
- [docs/ROADMAP.md](docs/ROADMAP.md): planning
- [CHANGELOG.md](CHANGELOG.md): wat er per run gebouwd is
- [CREDITS.md](CREDITS.md): bronnen en licenties

## Lokaal draaien

Godot 4.7.2 (Compatibility-renderer). Open `project.godot` in de editor, of:

```
godot --headless --import
godot --headless -s tools/run_tests.gd
```

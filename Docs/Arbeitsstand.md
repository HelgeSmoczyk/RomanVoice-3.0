# RomanVoice 3.0 – gespeicherter Arbeitsstand

Stand: 30. September 2026. Aktueller Startplatz-Teststand, noch keine vollständige App-Abnahme.

## Aktueller Startplatz

- Sauberer Salon als gemeinsamer Hintergrund.
- Vier Startbuttons: Bibliothek, Lesen, Hören, Importieren.
- Hamburger-Menü, Einstellungen und Impressum bleiben erreichbar.
- Die vier Startbuttons führen aktuell in eigene Sackgassen mit BIBLIOTHEK, LESEN, HÖREN und IMPORTIEREN.
- Jede Sackgasse besitzt einen eindeutigen `Zurück`-Button.
- Navigation und UI-Test verwenden dieselben Bezeichnungen.

## Projektstruktur

Im App-Target liegen aktuell 24 Swift-Quelldateien plus Objective-C++-Brücke für das lokale Modell. `ConstructionView.swift` liegt einmal unter `RomanVoice/ConstructionView.swift`. Der Projekt-Verifier prüft doppelte Swift-Typen, Asset-Prüfsummen, Ressourcen, AppIcon, Startplatz/UI-Test-Vertrag und wesentliche Projektstruktur.

## Letzter korrigierter CI-Fehler

Der letzte GitHub-Lauf scheiterte bereits in `scripts/verify_project.py`, weil der Prüfer den AppIcon-Metadateinamen ausschließlich als exakt `Contents.json` akzeptierte. GitHub-Webuploads können bei reinen Groß-/Kleinschreibungsänderungen ältere Git-Einträge hinterlassen; auf dem case-insensitiven macOS-Runner kann deshalb `contents.json` sichtbar sein.

Der aktuelle Stand ist dagegen abgesichert:

- `prepare_dependencies.sh` normalisiert Asset-Metadateien vor der Prüfung auf `Contents.json`.
- `verify_project.py` findet die Metadatei unabhängig von der gespeicherten Schreibweise, verlangt aber weiterhin genau eine passende Datei und prüft ihren Inhalt vollständig.
- Der exakte Fehlerfall wurde mit absichtlich kleingeschriebenen Metadateien simuliert und erfolgreich geprüft.

## Prüfung

Der aktuelle Paketstand wird zweimal geprüft: einmal vor dem Packen und ein zweites Mal nach Neuverpackung durch erneutes Entpacken der finalen ZIP. Details stehen in `Docs/Pruefbericht.md`.

Ein echter Xcode-/Simulatorlauf kann in dieser Umgebung nicht ausgeführt werden und muss durch GitHub Actions bestätigt werden.

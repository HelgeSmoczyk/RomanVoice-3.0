# RomanVoice 3.0 – gespeicherter Arbeitsstand

Stand: 30. September 2026. **Aktueller Startplatz-Teststand, noch keine vollständige App-Abnahme.**

## Aktueller Master für den Startplatz

Gemeinsame räumliche Grundlage ist der neue saubere Salon in `RomanVoice/Assets.xcassets/Salon.imageset/salon_clean.jpeg`. Diese Grafik wurde bewusst gegenüber dem ursprünglichen Referenzasset geändert und ist deshalb im `Docs/Asset-Manifest.json` mit `unchanged: false` sowie ihrer aktuellen SHA-256-Prüfsumme geführt. Die sechs Referenzgrafiken bleiben unverändert.

## Aktueller Startplatz

- RomanVoice-Logo auf dem Salon.
- Vier funktionale Startbuttons: Bibliothek, Lesen, Hören, Importieren.
- Hamburger-Menü, Einstellungen und Impressum bleiben erreichbar.
- Die vier Startbuttons führen derzeit jeweils auf eine eigene Sackgasse mit dem Titel BIBLIOTHEK, LESEN, HÖREN bzw. IMPORTIEREN.
- Jede Sackgasse besitzt einen eindeutigen `Zurück`-Button zum Startplatz.
- Die UI-Tests verwenden genau diese Bezeichnungen.

## Projektstruktur

Im App-Target liegen aktuell 24 Swift-Quelldateien plus Objective-C++-Brücke für das lokale Modell. `ConstructionView.swift` liegt genau einmal unter `RomanVoice/ConstructionView.swift`. Der Projekt-Verifier prüft doppelte Swift-Typen, Asset-Prüfsummen, Ressourcen, AppIcon, Startplatz/UI-Test-Vertrag und wesentliche Projektstruktur.

## Build-Stand

- Ein vorausgehender Projektstand wurde in GitHub Actions als Build #53 erfolgreich gebaut/getestet.
- Build #54 stoppte bereits im Projekt-Verifier, weil der neue Salon absichtlich die alte Salon-Prüfsumme ungültig gemacht hatte. Das war kein Swift-Compilerfehler.
- Die Salon-Prüfsumme und der Verifier sind im aktuellen Paket korrigiert.
- Der AppIcon-Katalog wurde zusätzlich bereinigt (`Contents.json`, 1024×1024), um die zuvor sichtbare AppIcon-Warnung zu beseitigen.

## Prüfung des aktuellen Pakets

Das aktuelle Paket wird vor Ausgabe zweimal lokal geprüft: einmal im Arbeitsverzeichnis und ein zweites Mal nach Neuverpackung durch erneutes Entpacken der fertigen ZIP. Details stehen in `Docs/Pruefbericht.md`.

Ein echter Xcode-/Simulatorlauf des neu gepackten Standes kann lokal nicht ausgeführt werden und muss durch den nächsten GitHub-Actions-Lauf bestätigt werden.

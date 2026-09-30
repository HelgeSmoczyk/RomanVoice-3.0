# Prüfbericht – RomanVoice 3.0 Startplatz

Stand: 30. September 2026.

## Grundlage dieses Pakets

Dieses Paket basiert auf `RomanVoice-3.0-Startplatz-sauberer-Salon.zip`. Der bewusst ausgetauschte Salon (`Salon.imageset/salon_clean.jpeg`) ist im Asset-Manifest mit seiner aktuellen SHA-256-Prüfsumme hinterlegt. Die sechs Referenzgrafiken bleiben unverändert.

Der Startplatz enthält die vier aktuellen Routen **Bibliothek**, **Lesen**, **Hören** und **Importieren**. Jede Route führt derzeit in eine bewusst einfache Sackgasse mit passender Raumüberschrift und einem als `Zurück` gekennzeichneten Rückweg. Die bestehende RomanVoice-Architektur (`Navigation`, `Screen`, `RootView` und die übrigen App-Bausteine) bleibt erhalten.

## Korrigiert

- Neue Salon-Grafik und ihre Prüfsumme synchronisiert.
- `ConstructionView.swift` liegt genau einmal im App-Target unter `RomanVoice/ConstructionView.swift`.
- Doppelte Swift-Typdeklarationen werden durch `scripts/verify_project.py` abgefangen.
- UI-Test und Navigation verwenden dieselben vier Startplatz-Routen und Raumtitel.
- `Zurück` besitzt einen eindeutigen Accessibility-Identifier für den UI-Test.
- AppIcon-Katalog korrigiert: Apple-konformes `Contents.json` mit korrekter Groß-/Kleinschreibung und `AppIcon.png` exakt 1024 × 1024 Pixel. Dadurch wird die zuvor sichtbare Xcode-Warnung zum „unassigned child“ nicht mehr durch die fehlerhafte AppIcon-Metadatei verursacht.
- Veraltete Prüfdokumentation vom 16. September ersetzt.

- Plattformfehler im Verifier korrigiert: Die frühere Prüfung `not Path("contents.json").exists()` war auf dem Linux-Prüfsystem unauffällig, schlägt aber auf dem standardmäßig **nicht zwischen Groß-/Kleinschreibung unterscheidenden macOS-Dateisystem** auch dann an, wenn nur `Contents.json` existiert. Die Prüfung arbeitet jetzt plattformneutral über die exakten Verzeichnis-Einträge.

## Lokale Prüfung – Durchlauf 1

Auf dem entpackten Projekt wurden ausgeführt:

- `python3 scripts/verify_project.py`
- Swift-Syntaxprüfung jeder Swift-Datei mit `swiftc -frontend -parse`
- Prüfung auf doppelte Top-Level-Typen
- JSON-Prüfung aller `.json`-Dateien
- Property-List-Prüfung aller `.plist`-Dateien
- YAML-Prüfung von `project.yml` und GitHub-Workflow
- `bash -n scripts/prepare_dependencies.sh`
- Asset-Prüfsummen einschließlich des neuen Salons
- AppIcon-Metadaten und 1024×1024-PNG-Abmessungen

Alle lokalen Prüfungen bestanden.

Zusätzlich wurde der Verifier selbst auf plattformneutrale Groß-/Kleinschreibungsprüfung kontrolliert, damit die macOS-Abhängigkeitsstufe nicht erneut an `Contents.json`/`contents.json` scheitert.

## Lokale Prüfung – Durchlauf 2

Nach Erstellung der neuen ZIP wurde genau diese ZIP in ein frisches zweites Verzeichnis entpackt. Dort wurden die gleichen Prüfungen erneut ausgeführt. Zusätzlich wurde die ZIP-Integrität mit `unzip -t` geprüft.

Alle lokalen Prüfungen bestanden.

## Bereits durch GitHub/Xcode belegt

Ein unmittelbar vorausgehender Projektstand lief in GitHub Actions als Build **#53** erfolgreich durch. Der danach hochgeladene neue Salon führte bei Build #54 noch vor Xcode zu einem absichtlichen Stopp des Projekt-Verifiers, weil dessen alte Salon-Prüfsumme nicht mehr zum Bild passte. Diese Prüfsumme ist in diesem Paket aktualisiert.

## Noch nicht durch dieses lokale System nachweisbar

Dieses System ist kein macOS/Xcode-Rechner. Deshalb kann hier kein echter iOS-Link-, Simulator- oder IPA-Build des **neu gepackten** Standes ausgeführt werden. Die endgültige Bestätigung dieses Pakets muss der nächste GitHub-Actions-Lauf mit Xcode liefern.

Ein grüner Build ist weiterhin keine vollständige Produktabnahme; visuelle und funktionale Prüfung auf dem iPhone bleibt separat erforderlich.

# Prüfbericht – RomanVoice 3.0 Startplatz

Stand: 30. September 2026

## Anlass der letzten Korrektur

Der letzte GitHub-Actions-Lauf brach bereits in **Abhängigkeiten vorbereiten** ab. Ursache war nicht Swift oder Xcode, sondern `scripts/verify_project.py`: Der Prüfer verlangte beim AppIcon den Dateinamen `Contents.json` in exakt dieser Groß-/Kleinschreibung. Nach GitHub-Webuploads kann jedoch ein älterer, nur in der Schreibweise abweichender Eintrag wie `contents.json` im Repository verbleiben. Auf dem standardmäßig case-insensitiven macOS-Arbeitsdateisystem des GitHub-Runners kann dadurch beim Checkout genau diese Schreibweise sichtbar werden.

## Korrigiert

- `scripts/verify_project.py` löst die Asset-Metadatei jetzt für alle `.imageset`- und `.appiconset`-Ordner case-insensitiv auf und verlangt weiterhin exakt eine passende Metadatei.
- `scripts/prepare_dependencies.sh` normalisiert vor dem Verifier und vor Xcode/actool alle Asset-Metadateien mit einer zweistufigen Umbenennung auf den kanonischen Namen `Contents.json`. Die zweistufige Umbenennung funktioniert auch auf einem case-insensitiven macOS-Dateisystem.
- Die eigentlichen Asset-Prüfungen bleiben unverändert streng: referenzierte Bilddateien, unzugewiesene Dateien, AppIcon-PNG, AppIcon-Abmessungen und Asset-SHA-256 werden weiterhin geprüft.
- Der aktuelle AppIcon-Inhalt verweist auf genau `AppIcon.png`; die PNG-Datei ist 1024 × 1024 Pixel groß.
- Die bestehende Startplatz-Navigation, `ConstructionView.swift`, der Zurück-Identifier und der UI-Test-Vertrag bleiben erhalten.

## Prüfung – Durchlauf 1

Auf dem Arbeitsstand wurden ausgeführt:

- `python3 scripts/verify_project.py` → **PASS**
- Swift-Syntaxprüfung mit `swiftc -frontend -parse` für alle **24 Swift-Dateien** → **PASS**
- JSON-Prüfung aller **15 JSON-Dateien** → **PASS**
- Property-List-Prüfung → **PASS**
- YAML-Prüfung von `project.yml` und `.github/workflows/main.yml` → **PASS**
- `bash -n scripts/prepare_dependencies.sh` → **PASS**
- Prüfung auf case-insensitive Pfadkollisionen im Paket → **0 Kollisionen**

Der Projekt-Verifier meldete:

`PASS: 24 Swift source files; 7 manifest assets; font; plist; audio privacy; bridge; IPA structure; AppIcon; source placement; duplicate-type check; Startplatz/UI-test contract.`

## Exakter Fehlerfall zusätzlich simuliert

In einer separaten Kopie wurden **alle 14 Asset-Metadateien** absichtlich von `Contents.json` nach `contents.json` umbenannt.

- Der neue Verifier lief bereits auf dieser Schreibweise vollständig durch → **PASS**.
- Anschließend wurde `scripts/prepare_dependencies.sh` mit vorhandener Dummy-Framework-Struktur ausgeführt, damit kein Download nötig war.
- Das Skript normalisierte danach **alle 14 Kataloge** wieder auf exakt `Contents.json`.
- Der Projekt-Verifier lief danach erneut vollständig durch → **PASS**.

Damit wurde genau der Fehlerzustand aus dem letzten GitHub-Log reproduziert und lokal abgefangen.

## Prüfung – Durchlauf 2

Nach dem Packen der finalen ZIP wird genau diese ZIP in ein frisches Verzeichnis entpackt. Dort werden Projekt-Verifier, Swift-Parser, JSON/Plist/YAML-Prüfung, Shell-Syntaxprüfung und ZIP-Integrität erneut ausgeführt. Das Ergebnis dieses zweiten Durchlaufs wird erst nach erfolgreichem Abschluss als finaler Paketstand ausgegeben.

## Grenze der lokalen Prüfung

Diese Umgebung ist kein macOS/Xcode-Rechner. Ein echter iOS-Simulatorlauf, `xcodebuild` und die IPA-Erzeugung des finalen Pakets können hier nicht ausgeführt werden. Diese letzte Bestätigung liefert ausschließlich der nächste GitHub-Actions-Lauf.

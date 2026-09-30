# RomanVoice 3.0 – Prüfbericht

Stand: 30.09.2026

## Grundlage

Dieser Stand wurde **neu aus dem vom Benutzer gelieferten Repository-ZIP des bekannten grünen Commits `0df3375c8e5c7def4585247a93e8669ff1639d66`** aufgebaut. Der Swift-Code dieses grünen Stands wurde nicht durch eine ältere Modellfassung ersetzt.

Geändert wurden nur die für den aktuellen Startplatz nötigen Punkte:

- freigegebener sauberer Salon als `Salon.imageset/salon_clean.jpeg`
- `Salon.imageset/Contents.json` auf dieses Bild umgestellt
- Salon-SHA im `Docs/Asset-Manifest.json` aktualisiert
- doppelte Groß-/Kleinschreibungsvariante `AppIcon.appiconset/contents.json` aus dem ZIP entfernt; nur `Contents.json` bleibt
- `prepare_dependencies.sh` bereinigt vor dem Verifier alte, durch GitHub-Web-Uploads stehengebliebene Asset-Dateien und normalisiert `Contents.json`
- `verify_project.py` prüft Asset-Zuordnung, Case-Kollisionen, Hashes, Swift-Struktur und Startplatz/UI-Test-Vertrag

## Lokale Prüfungen

1. Verifier auf dem sauberen Projektstand: PASS
2. Swift-Parser über alle Swift-Dateien: PASS
3. JSON/Plist/YAML/Shell-Syntax: PASS
4. Keine case-insensitiven Dateikollisionen im ZIP: PASS
5. Simulation eines GitHub-Web-Uploads über den alten grünen Stand (alte Dateien bleiben liegen): Bereinigung + Verifier PASS
6. Simulation einer falsch geschriebenen `contents.json`: Normalisierung + Verifier PASS
7. Fertige ZIP erstellt, ZIP-Integrität geprüft, frisch entpackt und Prüfungen erneut ausgeführt: PASS

## Grenze der lokalen Prüfung

Ein echter Apple-Xcode-/iOS-Simulatorlauf ist in dieser Linux-Umgebung nicht möglich. Der abschließende `xcodebuild` wird deshalb weiterhin durch GitHub Actions auf macOS bestätigt.

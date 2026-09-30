# RomanVoice 3.0 – gespeicherter Arbeitsstand

Stand: 16. September 2026. **Zwischenstand, keine abgenommene App.**

## Verbindliche Grundlage

`Verbindliche-Masterliste.txt` enthält die vollständige übergebene Masterliste. Bei Konflikten gilt die jüngste Festlegung aus dem Gespräch. Die sieben Originalgrafiken liegen unverändert im Assetkatalog; ihre Prüfsummen stehen in `Asset-Manifest.json`. Der Programmcode ist neu erstellt.

## Vorhanden

23 Swift-Dateien sowie eine Objective-C++-Anbindung für das lokale Qwen-Modell: Import, Textstruktur, Analyse, Stimmen, Audiogenerierung, verschlüsselter Audiospeicher, Reader, Player, Bibliothek, Salon, Einstellungen und Animationen. Dazu kommen Unit-Tests, UI-Tests und ein GitHub-Actions-Workflow zum Simulator-Test und zur Erstellung einer unsignierten IPA.

Diese Aufzählung beschreibt vorhandenen Code, keine nachgewiesene Funktionsfähigkeit.

## Zuletzt korrigiert

- Fehlende Projektdefinition für das bereits im Testplan verwendete UI-Testziel ergänzt.
- Reader-Blättertasten werden zusammen mit den übrigen Steuerelementen ausgeblendet.

## Offene Arbeiten, in Reihenfolge

1. Statische Prüfung erweitern: alle Build-/Testziele, Quellverzeichnisse, Swift-Syntax, unveränderte Assets und ZIP-Inhalt.
2. Kapiteländerungen und Positionszuordnung prüfen; PDF-Seiten ohne Verzerrung darstellen.
3. Alle 50 Punkte der Masterliste mit konkreten Codebelegen und offenen Abnahmeschritten abgleichen. Vorhandener Code allein erfüllt die Abnahme nicht.
4. Vollständige Typprüfung und Tests mit Xcode durchführen. Auf diesem Windows-Rechner stehen Xcode und iOS-Simulator nicht zur Verfügung. Der GitHub-Workflow ist vorbereitet, noch nicht gelaufen.
5. Auf einem iPhone insbesondere Salon-Ausschnitt und Hotspots, Animationen, Zoom/Blättern, Positionswechsel, lange Analyse, Unterbrechung/Wiederaufnahme, Modell-Download und Hintergrundaudio prüfen.
6. Erst nach Fehlerkorrekturen und klar ausgewiesenen Testergebnissen das finale Projekt-ZIP erstellen.

## Wiederaufnahme nach Kontingentabbruch

Zuerst diese Datei und `Docs/Pruefbericht.md` lesen. Das neue Projekt liegt vollständig in diesem Ordner. Nicht neu beginnen und keine alten RomanVoice-App-Dateien übernehmen. Gespeicherte Zwischenstände sind keine fertigen Releases. Das vollständige Gespräch und die Eingabedateien bleiben zusätzlich im Arbeitsverzeichnis außerhalb des ZIP gesichert.

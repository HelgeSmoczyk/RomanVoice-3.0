# RomanVoice 3.0

**Neues iOS-Projekt – Entwicklungszwischenstand, noch nicht abgenommen.**

Die App wird unabhängig vom alten RomanVoice-Code entwickelt. Die neue Kennung `de.romanvoice.private.v3` ermöglicht eine getrennte Installation. Bitte die alte Installation mit ihren Daten aufbewahren.

## Projekt bauen

1. Den gesamten ZIP-Inhalt einschließlich des versteckten Ordners `.github` in ein eigenes GitHub-Repository übernehmen. `project.yml` muss direkt im Stammverzeichnis liegen.
2. Unter **Actions → RomanVoice iOS Build → Run workflow** den Build starten.
3. Der Workflow lädt die festgelegte llama-Abhängigkeit, erzeugt das Xcode-Projekt, führt Simulator-Tests aus und baut anschließend die iPhone-App.
4. Bei Erfolg das Artefakt **RomanVoice-3.0-unsigned** herunterladen und entpacken. Die darin enthaltene IPA ist für das Signieren mit Sideloadly vorgesehen.
5. Bei einem Fehler enthalten die Workflow-Ausgabe und das Artefakt **RomanVoice-Pruefberichte** die Details. Ein erster erfolgreicher Build ist noch nicht nachgewiesen.

Auf einem Mac: `bash scripts/prepare_dependencies.sh`, anschließend `xcodegen generate`, dann `RomanVoice.xcodeproj` mit Xcode öffnen. XcodeGen muss zuvor installiert sein. Mindestziel ist iOS 18.

Die große Modell-Datei gehört nicht ins ZIP. Die App lädt sie bei Bedarf und prüft ihre Prüfsumme. Für die erstmalige Vorbereitung werden Internetzugang und ausreichend freier Speicher benötigt. Die spätere Textanalyse und Sprachsynthese sind lokal vorgesehen.

## Fortschritt und Prüfung

- `Docs/Arbeitsstand.md`: erledigte und offene Arbeit, Wiederaufnahme nach Unterbrechungen.
- `Docs/Verbindliche-Masterliste.txt`: vollständige verbindliche Vorgaben.
- `Docs/Pruefbericht.md`: tatsächlich durchgeführte Prüfungen und Grenzen.
- `Docs/Asset-Manifest.json`: Prüfsummen der sieben Originalgrafiken.

Das ZIP enthält Quellcode, echte Grafikassets, Schrift, Lizenzen und Build-Konfiguration. Es enthält weder eine fertig gebaute IPA noch das KI-Modell oder die heruntergeladene llama-Binärbibliothek.

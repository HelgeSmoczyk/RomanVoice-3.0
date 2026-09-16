import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject var library: Library
    @EnvironmentObject var model: ModelManager
    @EnvironmentObject var navigation: Navigation
    @EnvironmentObject var work: WorkCoordinator
    @State private var policy: NetworkPolicy = .wifi
    @State private var information: String?
    @State private var deleteModel = false
    var body: some View {
        VStack {
            PageHeader(title: "Einstellungen", subtitle: "Ganz nach deinem Stil.") { navigation.go(.home, room: .salon) }
            ScrollView {
                RomanPanel {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Lesen").font(.title3)
                        Picker("Seitennavigation", selection: Binding(get: { library.preferences.readingMode }, set: { library.preferences.readingMode = $0; library.savePreferences() })) { ForEach(ReadingMode.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                        Text("EB Garamond · feste A5-Buchseite · 34 Zeilen. Hell/Dunkel folgt deinem iPhone. Zoom ersetzt die Änderung des Satzspiegels.").font(.caption)
                        Picker("Spoilerschutz", selection: Binding(get: { library.preferences.spoilers }, set: { library.preferences.spoilers = $0; library.savePreferences() })) { ForEach(SpoilerPolicy.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                        Divider()
                        Text("Kostenlose lokale KI").font(.title3)
                        Text(model.message)
                        if model.busy { ProgressView(value: model.progress); Button("Download pausieren") { model.cancel() }.disabled(model.progress == 0) }
                        else {
                            Picker("Downloadverbindung", selection: $policy) { ForEach(NetworkPolicy.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                            Button(model.ready ? "Modell erneut prüfen" : "Kostenlose KI herunterladen / fortsetzen") { if model.ready { Task { await model.verify() } } else { model.download(policy: policy) } }.buttonStyle(RomanButton())
                            if model.ready { Button("KI-Modell entfernen", role: .destructive) { deleteModel = true }.disabled(work.activeID != nil) }
                        }
                        Text("Qwen3 1.7B · Q4_K_M · 1,28 GB. Nach der Einrichtung funktionieren Analyse und Wiedergabe offline. Das Modell bleibt bei normalen Updates erhalten.").font(.caption)
                        Divider()
                        Toggle("Benachrichtigungen", isOn: Binding(get: { library.preferences.notifications }, set: enableNotifications))
                        Text("Nur bei Hörbereitschaft, erforderlicher Entscheidung oder vollständiger Erstellung.").font(.caption)
                        MenuRow(title: "Speicher & Daten", subtitle: ByteCountFormatter.string(fromByteCount: AppFiles.size(AppFiles.root), countStyle: .file), icon: "internaldrive") { navigation.go(.library(.library), room: .library) }
                        Text("Audiodaten bleiben verschlüsselt im privaten App-Speicher. Sie werden nicht exportiert oder geteilt.").font(.caption)
                        TextField("Lokaler Profilname (optional)", text: Binding(get: { library.preferences.profileName }, set: { library.preferences.profileName = $0; library.savePreferences() }))
                        Text("Kein Konto, keine Anmeldung. Sprache: Deutsch.").font(.caption)
                        ForEach(["Datenschutz", "Nutzungsbedingungen", "Impressum", "Hilfe & Support", "Lizenzen"], id: \.self) { title in
                            Button(title) { information = title }
                        }
                        Text("RomanVoice 3.0 · Privater Teststand").font(.caption)
                    }
                }.padding(18)
            }
        }
        .confirmationDialog("Lokales KI-Modell entfernen?", isPresented: $deleteModel) { Button("Entfernen", role: .destructive) { do { try model.remove() } catch { library.error = error.localizedDescription } } }
        .onAppear { policy = model.suggestedPolicy }
        .sheet(isPresented: Binding(get: { information != nil }, set: { if !$0 { information = nil } })) {
            NavigationStack { ScrollView { Text(legal(information ?? "")).frame(maxWidth: .infinity, alignment: .leading).padding(24) }.navigationTitle(information ?? "").toolbar { Button("Fertig") { information = nil } } }
        }
    }
    private func enableNotifications(_ enabled: Bool) {
        if !enabled { library.preferences.notifications = false; library.savePreferences(); return }
        Task {
            let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
            library.preferences.notifications = granted; library.savePreferences()
        }
    }
    private func legal(_ title: String) -> String {
        switch title {
        case "Datenschutz": return "RomanVoice verarbeitet importierte Texte und erzeugte Sprache lokal auf diesem iPhone. Die App verwendet keine Analysewerbung, Telemetrie oder Benutzerkonten. Beim ausdrücklich gestarteten KI-Download wird eine Verbindung zu Hugging Face und dessen Download-Infrastruktur hergestellt; dabei werden übliche Verbindungsdaten übertragen. Romantexte werden dabei nicht hochgeladen.\n\nTexte, Analyse und Audio werden im privaten App-Speicher abgelegt. Audio ist verschlüsselt; der Schlüssel bleibt in der Schlüsselbundverwaltung dieses Geräts. Unter Speicherverwaltung kannst du Daten löschen. Beim Löschen der App entfernt iOS den App-Datenbestand.\n\nDies ist die Funktionsbeschreibung des privaten Teststands. Vor öffentlicher Veröffentlichung müssen Betreiberangaben und eine passende Datenschutzerklärung ergänzt und geprüft werden."
        case "Nutzungsbedingungen": return "Privater Teststand. Importiere nur Inhalte, zu deren Verarbeitung und privater Nutzung du berechtigt bist. RomanVoice verkauft und verteilt keine Bücher und bietet keinen Audioexport, keine Tauschbibliothek und keinen Upload fertiger Hörbücher an.\n\nAutomatische Sprecherzuordnungen können falsch sein. Prüfe die Vorschläge vor der Erzeugung. Erstelle eigene Sicherungen deiner Originaldateien. Die App bietet keinen Export erzeugter Audiodaten.\n\nDiese Hinweise ersetzen keine rechtliche Prüfung vor einer Veröffentlichung."
        case "Impressum": return "RomanVoice 3.0 wird hier als privater, nicht veröffentlichter Teststand bereitgestellt. Es wurden keine Anbieteranschrift oder Kontaktangaben erfunden. Vor einer öffentlichen Veröffentlichung müssen die tatsächlichen Betreiberangaben ergänzt und rechtlich geprüft werden."
        case "Lizenzen": return license("EBGaramond-OFL") + "\n\n" + license("llama-LICENSE") + "\n\nQwen3: Apache License 2.0. Modell: ggml-org/Qwen3-1.7B-GGUF, Basis Qwen/Qwen3-1.7B.\n\nZIPFoundation: MIT. Die Lizenztexte liegen zusätzlich im Projektordner Lizenzen.\n\nDie Originalgrafiken wurden vom Nutzer bereitgestellt. Separate Animationsgrafik wurde mit dem integrierten Imagegen-Werkzeug erzeugt."
        default: return "1. Unter Einstellungen die kostenlose KI herunterladen.\n2. Am Schreibtisch eine PDF mit echtem Text, DOCX oder TXT importieren.\n3. Analyse starten, offene Sprecherstellen und Stimmen prüfen.\n4. Stimmen bestätigen und Hörbuch erstellen.\n5. Sobald die ersten Abschnitte vorliegen, kannst du hören.\n\nNeue deutsche Systemstimmen lassen sich in den iPhone-Einstellungen für gesprochene Inhalte installieren. RomanVoice zeigt nur tatsächlich verfügbare Stimmen an.\n\nDie Verarbeitung pausiert, wenn iOS die App im Hintergrund anhält. Beim nächsten Öffnen wird vom Checkpoint fortgesetzt. Ein ausdrücklich abgebrochener Auftrag startet nicht automatisch. Audio läuft auch bei gesperrtem Bildschirm weiter.\n\nDie bestehende alte App nicht löschen. Diese neue Version verwendet einen eigenen Datenbereich. Für Fehlermeldungen bitte Arbeitsschritt, Dateityp und Meldung notieren."
        }
    }
    private func license(_ name: String) -> String { guard let url = Bundle.main.url(forResource: name, withExtension: "txt") else { return name }; return (try? String(contentsOf: url, encoding: .utf8)) ?? name }
}

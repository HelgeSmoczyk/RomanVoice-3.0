import SwiftUI

struct LibraryView: View {
    let intent: Intent
    var importAction: () -> Void
    @EnvironmentObject var library: Library
    @EnvironmentObject var navigation: Navigation
    @EnvironmentObject var player: AudioPlayer
    @State private var query = ""
    @State private var filter = "Alle"
    @State private var sort = "Zuletzt geöffnet"
    private var books: [Novel] {
        let selected = library.books.filter { book in
            (query.isEmpty || (book.title + " " + book.author).localizedCaseInsensitiveContains(query)) &&
            (filter != "Favoriten" || book.favorite) && (filter != "Gelesen" || book.reading.completed) &&
            (filter != "Hörbücher" || book.hasAudio)
        }
        return selected.sorted { a, b in sort == "Titel" ? a.title < b.title : sort == "Autor" ? a.author < b.author : a.modified > b.modified }
    }
    private var title: String { switch intent { case .library: return "Bibliothek"; case .read: return "Lesen"; case .listen: return "Hörbücher"; case .analyze: return "Neuer Roman" } }
    var body: some View {
        VStack(spacing: 14) {
            PageHeader(title: title, subtitle: intent == .read ? "Manche Geschichten möchte man selbst erleben." : "Deine Bücher. Immer dabei.") { navigation.go(.home, room: .salon) }
            if intent != .library {
                Spacer(minLength: 30)
                RomanPanel {
                    VStack {
                        if intent == .analyze { MenuRow(title: "Datei importieren", subtitle: "PDF, DOCX oder TXT", icon: "square.and.arrow.down", action: importAction) }
                        if let book = books.first {
                            MenuRow(title: intent == .listen ? "Zuletzt gehört" : intent == .read ? "Zuletzt gelesen" : "Projekt fortsetzen", subtitle: book.title, icon: "clock.arrow.circlepath") { open(book) }
                        }
                        MenuRow(title: "Buch auswählen", subtitle: "Aus deiner Bibliothek", icon: "books.vertical") { filter = intent == .listen ? "Hörbücher" : "Alle" }
                    }
                }.padding(.horizontal, 18)
            }
            RomanPanel {
                VStack(spacing: 10) {
                    TextField("Titel oder Autor suchen", text: $query).textFieldStyle(.plain).padding(8).background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 6))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack { ForEach(["Alle", "Romane", "Hörbücher", "Gelesen", "Favoriten"], id: \.self) { value in Button(value) { filter = value }.font(.caption).padding(8).background(filter == value ? RomanStyle.gold : .clear, in: Capsule()).foregroundStyle(filter == value ? .black : RomanStyle.cream) } }
                    }
                    HStack { Text("\(books.count) Bücher").font(.caption); Spacer(); Picker("Sortierung", selection: $sort) { ForEach(["Zuletzt geöffnet", "Titel", "Autor"], id: \.self) { Text($0) } }.pickerStyle(.menu) }
                    ScrollView {
                        if books.isEmpty { Text("Deine Bibliothek wartet auf die erste Geschichte.").multilineTextAlignment(.center).padding() }
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 18) {
                            ForEach(books) { book in
                                Button { open(book) } label: {
                                    VStack(spacing: 7) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 4).fill(LinearGradient(colors: [RomanStyle.lightGreen, .black], startPoint: .topLeading, endPoint: .bottomTrailing))
                                            RoundedRectangle(cornerRadius: 2).stroke(RomanStyle.gold.opacity(0.8), lineWidth: 1).padding(9)
                                            VStack(spacing: 9) { Image(systemName: book.hasAudio ? "headphones" : "book.closed"); Text(book.title).font(.custom("EBGaramond-Regular", size: 21)).lineLimit(4); Text(book.author).font(.caption).lineLimit(2) }.padding(14)
                                            if let file = book.coverFile, let directory = try? AppFiles.book(book.id), let cover = UIImage(contentsOfFile: directory.appendingPathComponent(file).path) {
                                                Image(uiImage: cover).resizable().scaledToFit().padding(5)
                                            }
                                        }.frame(height: 174).shadow(radius: 6, x: 3, y: 4)
                                        Text(book.status).font(.caption2)
                                        Text(book.title).font(.caption).lineLimit(2)
                                    }
                                }.buttonStyle(.plain).contextMenu { Button(book.favorite ? "Favorit entfernen" : "Als Favorit markieren") { library.update(book.id) { $0.favorite.toggle() } } }
                            }
                        }
                    }
                    Button { importAction() } label: { Label("Neues Buch importieren", systemImage: "plus") }.buttonStyle(RomanButton())
                }
            }.padding(.horizontal, 18).padding(.bottom, 12)
        }
    }
    private func open(_ book: Novel) {
        library.update(book.id) { $0.modified = Date() }
        switch intent {
        case .library: navigation.go(.detail(book.id), room: .library)
        case .read: navigation.go(.reader(book.id, nil, false), room: .reading)
        case .listen: player.open(book.id); navigation.go(.player(book.id), room: .audio)
        case .analyze: navigation.go(.analyze(book.id), room: .desk)
        }
    }
}

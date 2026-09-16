import Foundation
import Combine
import CryptoKit
import Security

enum AppFiles {
    static var root: URL { FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("RomanVoice3", isDirectory: true) }
    static func prepare() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var url = root
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try url.setResourceValues(values)
    }
    static func directory(_ name: String) throws -> URL {
        try prepare()
        let result = root.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: result, withIntermediateDirectories: true)
        return result
    }
    static func book(_ id: UUID) throws -> URL { try directory("Books/" + id.uuidString) }
    static func write(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
    static func size(_ url: URL) -> Int64 {
        guard let files = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        return files.compactMap { $0 as? URL }.reduce(0) { $0 + Int64((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
    }
}

@MainActor final class Library: ObservableObject {
    @Published var books: [Novel] = []
    @Published var preferences = AppPreferences()
    @Published var error: String?
    init() {
        do {
            let temporary = FileManager.default.temporaryDirectory
            for file in (try? FileManager.default.contentsOfDirectory(at: temporary, includingPropertiesForKeys: nil)) ?? [] where file.lastPathComponent.hasPrefix("RomanVoice-audio-") {
                try? FileManager.default.removeItem(at: file)
            }
            try AppFiles.prepare()
            let pref = AppFiles.root.appendingPathComponent("preferences.json")
            if FileManager.default.fileExists(atPath: pref.path) { preferences = try JSONDecoder().decode(AppPreferences.self, from: Data(contentsOf: pref)) }
            let dir = try AppFiles.directory("Books")
            for folder in try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
                let file = folder.appendingPathComponent("book.json")
                guard FileManager.default.fileExists(atPath: file.path) else { continue }
                do { books.append(try JSONDecoder().decode(Novel.self, from: Data(contentsOf: file))) }
                catch { self.error = "Ein gespeichertes Buch konnte nicht gelesen werden. Seine Dateien bleiben erhalten: \(folder.lastPathComponent)" }
            }
        } catch { self.error = error.localizedDescription }
    }
    func book(_ id: UUID) -> Novel? { books.first { $0.id == id } }
    func save(_ book: Novel) throws {
        let data = try JSONEncoder().encode(book)
        try AppFiles.write(data, to: AppFiles.book(book.id).appendingPathComponent("book.json"))
        if let i = books.firstIndex(where: { $0.id == book.id }) { books[i] = book } else { books.append(book) }
    }
    func update(_ id: UUID, _ change: (inout Novel) -> Void) {
        guard var book = book(id) else { return }
        change(&book)
        do { try save(book) } catch { self.error = error.localizedDescription }
    }
    func savePreferences() { do { try AppFiles.write(JSONEncoder().encode(preferences), to: AppFiles.root.appendingPathComponent("preferences.json")) } catch { self.error = error.localizedDescription } }
    func delete(_ id: UUID) throws {
        try FileManager.default.removeItem(at: AppFiles.book(id))
        books.removeAll { $0.id == id }
    }
    func removeOriginal(_ id: UUID) throws {
        guard var book = book(id), let source = book.sourceFile else { return }
        let file = try AppFiles.book(id).appendingPathComponent(source)
        if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
        book.sourceFile = nil; try save(book)
    }
    func removeAudio(_ id: UUID) throws {
        guard var book = book(id) else { return }
        for index in book.segments.indices {
            if let file = book.segments[index].audioFile {
                let path = try AppFiles.book(id).appendingPathComponent(file)
                if FileManager.default.fileExists(atPath: path.path) { try FileManager.default.removeItem(at: path) }
            }
            book.segments[index].audioFile = nil; book.segments[index].duration = 0
        }
        book.listening = Position(); book.phase = .review; book.voicesConfirmed = false
        try save(book)
    }
}

enum AudioVault {
    static func key() throws -> SymmetricKey {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "RomanVoice3.Audio", kSecAttrAccount as String: "device"]
        var read = query; read[kSecReturnData as String] = true
        var result: CFTypeRef?
        let status = SecItemCopyMatching(read as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data { return SymmetricKey(data: data) }
        guard status == errSecItemNotFound else { throw RomanError.message("Audioschlüssel momentan nicht zugänglich.") }
        let key = SymmetricKey(size: .bits256)
        var item = query
        item[kSecValueData as String] = key.withUnsafeBytes { Data($0) }
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw RomanError.message("Audioschlüssel konnte nicht gespeichert werden.") }
        return key
    }
    static func store(_ data: Data, at url: URL) throws {
        guard let sealed = try AES.GCM.seal(data, using: key()).combined else { throw RomanError.message("Audioverschlüsselung fehlgeschlagen.") }
        try AppFiles.write(sealed, to: url)
    }
    static func read(_ url: URL) throws -> Data { try AES.GCM.open(AES.GCM.SealedBox(combined: Data(contentsOf: url)), using: key()) }
}

import Foundation
import PDFKit
import ZIPFoundation

struct ImportedDocument {
    var title: String
    var author: String
    var text: String
    var original: Data
    var filename: String
    var cover: Data?
    var chapters: [Chapter]
}
enum DocumentImporter {
    static func read(_ url: URL) throws -> ImportedDocument {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard data.count < 150_000_000 else { throw RomanError.message("Diese Datei ist zu groß (maximal 150 MB).") }
        var title = url.deletingPathExtension().lastPathComponent
        var author = ""
        var cover: Data?
        var headings: [Chapter] = []
        let text: String
        switch url.pathExtension.lowercased() {
        case "txt":
            guard let decoded = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) ?? String(data: data, encoding: .windowsCP1252) else { throw RomanError.message("Die Textkodierung konnte nicht gelesen werden.") }
            text = decoded
        case "pdf":
            guard let pdf = PDFDocument(data: data), !pdf.isLocked else { throw RomanError.message("Die PDF ist beschädigt oder kennwortgeschützt.") }
            title = (pdf.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? title
            author = (pdf.documentAttributes?[PDFDocumentAttribute.authorAttribute] as? String) ?? ""
            text = (0..<pdf.pageCount).compactMap { pdf.page(at: $0)?.string }.joined(separator: "\n\n")
            if let first = pdf.page(at: 0) { cover = first.thumbnail(of: CGSize(width: 300, height: 450), for: .mediaBox).pngData() }
        case "docx":
            let archive = try Archive(data: data, accessMode: .read)
            guard let entry = archive["word/document.xml"], entry.uncompressedSize < 25_000_000 else { throw RomanError.message("Kein lesbares Word-Dokument.") }
            var xml = Data()
            _ = try archive.extract(entry) { xml.append($0) }
            let reader = WordTextParser()
            let parser = XMLParser(data: xml); parser.delegate = reader
            parser.shouldResolveExternalEntities = false
            guard parser.parse() else { throw RomanError.message("Das Word-Dokument enthält ungültiges XML.") }
            text = reader.text
            headings = reader.headings
            if let properties = archive["docProps/core.xml"], properties.uncompressedSize < 1_000_000 {
                var data = Data(); _ = try archive.extract(properties) { data.append($0) }
                let metadata = WordMetadataParser(); let parser = XMLParser(data: data)
                parser.delegate = metadata; parser.shouldResolveExternalEntities = false
                if parser.parse() {
                    if !metadata.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { title = metadata.title }
                    author = metadata.author
                }
            }
            if let image = archive.first(where: { $0.path.hasPrefix("word/media/") && ["png", "jpg", "jpeg"].contains(($0.path as NSString).pathExtension.lowercased()) && $0.uncompressedSize < 8_000_000 }) {
                var bytes = Data(); _ = try archive.extract(image) { bytes.append($0) }; cover = bytes
            }
        default: throw RomanError.message("Bitte eine PDF-, DOCX- oder TXT-Datei auswählen. Scans und Bilddateien werden nicht unterstützt.")
        }
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        guard normalized.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 else { throw RomanError.message("Kein auslesbarer Text gefunden. RomanVoice verarbeitet keine gescannten Buchseiten.") }
        let detected = TextStructure.chapters(normalized)
        headings += detected.filter { chapter in !headings.contains(where: { $0.offset == chapter.offset }) }
        return ImportedDocument(title: title, author: author, text: normalized, original: data, filename: url.lastPathComponent, cover: cover, chapters: headings.sorted { $0.offset < $1.offset })
    }
}
private final class WordTextParser: NSObject, XMLParserDelegate {
    var text = ""
    var headings: [Chapter] = []
    private var paragraphStart = 0
    private var heading = false
    private var inText = false
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        if elementName == "w:t" { inText = true }
        if elementName == "w:p" { paragraphStart = (text as NSString).length; heading = false }
        if elementName == "w:pStyle", let style = attributeDict["w:val"]?.lowercased(), style.contains("heading") || style.contains("berschrift") { heading = true }
        if elementName == "w:outlineLvl", attributeDict["w:val"] == "0" { heading = true }
        if elementName == "w:tab" { text += "\t" }
        if elementName == "w:br" { text += "\n" }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) { if inText { text += string } }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "w:t" { inText = false }
        if elementName == "w:p" {
            if heading {
                let title = (text as NSString).substring(from: paragraphStart).trimmingCharacters(in: .whitespacesAndNewlines)
                if !title.isEmpty { headings.append(Chapter(title: title, offset: paragraphStart)) }
            }
            text += "\n"
        }
    }
}
private final class WordMetadataParser: NSObject, XMLParserDelegate {
    var title = "", author = "", element = ""
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) { element = elementName }
    func parser(_ parser: XMLParser, foundCharacters string: String) { if element == "dc:title" { title += string }; if element == "dc:creator" { author += string } }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) { element = "" }
}

import UIKit
import CoreText
import PDFKit

struct PrintedLine { let text: String; let offset: Int }
struct PrintedPage { var lines: [PrintedLine]; var offset: Int; var pdfPage: PDFPage? }
final class BookLayout {
    let size = CGSize(width: 420, height: 595)
    var pages: [PrintedPage] = []
    init(book: Novel) {
        if let source = book.sourceFile, source.lowercased().hasSuffix(".pdf"), let folder = try? AppFiles.book(book.id), let pdf = PDFDocument(url: folder.appendingPathComponent(source)) {
            var offset = 0
            for i in 0..<pdf.pageCount {
                guard let page = pdf.page(at: i) else { continue }
                pages.append(PrintedPage(lines: [], offset: offset, pdfPage: page))
                offset += ((page.string ?? "") as NSString).length + 2
            }
            if !pages.isEmpty { return }
        }
        let font = UIFont(name: "EBGaramond-Regular", size: 14) ?? UIFont(name: "EBGaramond", size: 14) ?? UIFont.systemFont(ofSize: 14)
        let attributed = NSAttributedString(string: book.text, attributes: [.font: font])
        let typesetter = CTTypesetterCreateWithAttributedString(attributed)
        let ns = book.text as NSString
        var offset = 0, lines: [PrintedLine] = []
        let breaks = Set(book.chapters.map(\.offset))
        func flush() { if !lines.isEmpty { pages.append(PrintedPage(lines: lines, offset: lines[0].offset, pdfPage: nil)); lines = [] } }
        while offset < ns.length {
            if breaks.contains(offset) { flush() }
            var count = max(1, CTTypesetterSuggestLineBreak(typesetter, offset, 336))
            if let boundary = breaks.filter({ $0 > offset && $0 < offset + count }).min() { count = boundary - offset }
            count = min(count, ns.length - offset)
            lines.append(PrintedLine(text: ns.substring(with: NSRange(location: offset, length: count)).trimmingCharacters(in: .newlines), offset: offset))
            offset += count
            if lines.count == 34 { flush() }
        }
        flush()
        if pages.isEmpty { pages = [PrintedPage(lines: [], offset: 0, pdfPage: nil)] }
    }
    func page(at offset: Int) -> Int { pages.lastIndex { $0.offset <= offset } ?? 0 }
}

final class PrintedPageView: UIView {
    var page: PrintedPage?
    var dark = false
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(), let page else { return }
        (dark ? UIColor(white: 0.09, alpha: 1) : UIColor(red: 0.97, green: 0.94, blue: 0.87, alpha: 1)).setFill()
        context.fill(bounds)
        if let pdf = page.pdfPage {
            let box = pdf.bounds(for: .mediaBox)
            context.saveGState()
            context.translateBy(x: 0, y: bounds.height)
            context.scaleBy(x: bounds.width / box.width, y: -bounds.height / box.height)
            pdf.draw(with: .mediaBox, to: context)
            context.restoreGState()
            if dark { context.setBlendMode(.difference); UIColor.white.setFill(); context.fill(bounds) }
            return
        }
        let font = UIFont(name: "EBGaramond-Regular", size: 14) ?? UIFont(name: "EBGaramond", size: 14) ?? UIFont.systemFont(ofSize: 14)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: dark ? UIColor(white: 0.85, alpha: 1) : UIColor(white: 0.12, alpha: 1)]
        for (i, line) in page.lines.enumerated() { (line.text as NSString).draw(at: CGPoint(x: 42, y: 48 + CGFloat(i) * 14.5), withAttributes: attributes) }
    }
}

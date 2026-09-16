import SwiftUI
import UIKit
import PDFKit

struct PageViewport: UIViewRepresentable {
    let layout: BookLayout
    @Binding var page: Int
    @Binding var zoom: Double
    let mode: ReadingMode
    let dark: Bool
    var activity: () -> Void
    var tap: () -> Void
    var visibleOffset: (Int) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.delegate = context.coordinator; scroll.minimumZoomScale = 1; scroll.maximumZoomScale = 3
        scroll.showsVerticalScrollIndicator = false; scroll.showsHorizontalScrollIndicator = false
        scroll.bouncesZoom = false; scroll.alwaysBounceHorizontal = true
        scroll.backgroundColor = .clear
        let content = UIView(); content.tag = 99; scroll.addSubview(content)
        context.coordinator.scroll = scroll; context.coordinator.content = content
        scroll.panGestureRecognizer.addTarget(context.coordinator, action: #selector(Coordinator.pan(_:)))
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped))
        scroll.addGestureRecognizer(tap)
        return scroll
    }
    func updateUIView(_ scroll: UIScrollView, context: Context) {
        context.coordinator.parent = self
        DispatchQueue.main.async { context.coordinator.update() }
    }
    final class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: PageViewport
        weak var scroll: UIScrollView?
        var content: UIView!
        var lastPage = -1
        var lastSize = CGSize.zero
        var lastMode: ReadingMode?
        var lastDark: Bool?
        var leftAtStart = false, rightAtStart = false
        var updating = false
        var pageChangedByScrolling = false
        init(_ parent: PageViewport) { self.parent = parent }
        func update() {
            guard let scroll, scroll.bounds.width > 0, scroll.bounds.height > 0, !updating else { return }
            let needs = lastPage != parent.page || lastSize != scroll.bounds.size || lastMode != parent.mode || lastDark != parent.dark
            guard needs else { return }
            if parent.mode == .vertical && pageChangedByScrolling && lastSize == scroll.bounds.size && lastMode == parent.mode && lastDark == parent.dark {
                pageChangedByScrolling = false
                content.subviews.forEach { $0.removeFromSuperview() }
                let scale = min(scroll.bounds.width / 420, scroll.bounds.height / 595)
                for index in max(0, parent.page - 2)...min(parent.layout.pages.count - 1, parent.page + 3) {
                    let view = PrintedPageView(frame: CGRect(x: 0, y: 0, width: 420, height: 595))
                    view.page = parent.layout.pages[index]; view.dark = parent.dark
                    view.transform = CGAffineTransform(scaleX: scale, y: scale)
                    view.frame.origin = CGPoint(x: 0, y: CGFloat(index) * 595 * scale)
                    content.addSubview(view)
                }
                lastPage = parent.page
                return
            }
            updating = true; defer { updating = false }
            let continuous = parent.mode == .vertical
            let scale = min(scroll.bounds.width / 420, scroll.bounds.height / 595)
            let pageSize = CGSize(width: 420 * scale, height: 595 * scale)
            scroll.setZoomScale(1, animated: false)
            content.subviews.forEach { $0.removeFromSuperview() }
            let count = continuous ? parent.layout.pages.count : 1
            content.frame = CGRect(origin: .zero, size: CGSize(width: pageSize.width, height: pageSize.height * CGFloat(count)))
            // Draw only the nearby pages in continuous mode to bound memory for long novels.
            let range = continuous ? max(0, parent.page - 2)...min(parent.layout.pages.count - 1, parent.page + 3) : parent.page...parent.page
            for index in range {
                let view = PrintedPageView(frame: CGRect(x: 0, y: 0, width: 420, height: 595))
                view.page = parent.layout.pages[index]; view.dark = parent.dark
                view.transform = CGAffineTransform(scaleX: scale, y: scale)
                view.frame.origin = CGPoint(x: 0, y: continuous ? CGFloat(index) * pageSize.height : 0)
                content.addSubview(view)
            }
            scroll.contentSize = content.bounds.size
            scroll.setZoomScale(CGFloat(parent.zoom), animated: false)
            scroll.contentOffset = CGPoint(x: 0, y: continuous ? CGFloat(parent.page) * pageSize.height * CGFloat(parent.zoom) : 0)
            lastPage = parent.page; lastSize = scroll.bounds.size; lastMode = parent.mode; lastDark = parent.dark
        }
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { content }
        func scrollViewDidZoom(_ scrollView: UIScrollView) { guard !updating else { return }; parent.zoom = Double(scrollView.zoomScale); parent.activity() }
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) { parent.activity() }
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !updating && (scrollView.isDragging || scrollView.isDecelerating) { updateVerticalPage(); parent.activity() }
        }
        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { updateVerticalPage(); reportVisibleOffset() }
        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) { if !decelerate { updateVerticalPage(); reportVisibleOffset() } }
        func reportVisibleOffset() {
            guard let scroll, parent.layout.pages.indices.contains(parent.page) else { return }
            let scale = min(scroll.bounds.width / 420, scroll.bounds.height / 595) * scroll.zoomScale
            let top = max(0, scroll.contentOffset.y / max(0.01, scale) - (parent.mode == .vertical ? CGFloat(parent.page) * 595 : 0))
            let printed = parent.layout.pages[parent.page]
            if !printed.lines.isEmpty {
                let line = min(printed.lines.count - 1, max(0, Int((top - 48) / 14.5)))
                parent.visibleOffset(printed.lines[line].offset)
            } else if let pdf = printed.pdfPage {
                let box = pdf.bounds(for: .mediaBox)
                let point = CGPoint(x: box.minX + 25, y: box.maxY - min(1, top / 595) * box.height)
                if let line = pdf.selectionForLine(at: point)?.string, let text = pdf.string {
                    let range = (text as NSString).range(of: line)
                    parent.visibleOffset(printed.offset + (range.location == NSNotFound ? 0 : range.location))
                } else { parent.visibleOffset(printed.offset) }
            } else { parent.visibleOffset(printed.offset) }
        }
        func updateVerticalPage() {
            guard parent.mode == .vertical, let scroll else { return }
            let height = min(scroll.bounds.width / 420, scroll.bounds.height / 595) * 595 * scroll.zoomScale
            let index = min(parent.layout.pages.count - 1, max(0, Int((scroll.contentOffset.y + 10) / max(1, height))))
            if parent.page != index { pageChangedByScrolling = true; parent.page = index }
        }
        @objc func tapped() { parent.activity(); parent.tap() }
        @objc func pan(_ gesture: UIPanGestureRecognizer) {
            guard let scroll, parent.mode == .horizontal else { return }
            if gesture.state == .began {
                leftAtStart = scroll.contentOffset.x <= 2
                rightAtStart = scroll.contentOffset.x >= scroll.contentSize.width - scroll.bounds.width - 2
                parent.activity()
            }
            if gesture.state == .ended {
                let move = gesture.translation(in: scroll)
                guard abs(move.x) > 70, abs(move.x) > abs(move.y) else { return }
                if move.x < 0 && rightAtStart { parent.page = min(parent.layout.pages.count - 1, parent.page + 1) }
                if move.x > 0 && leftAtStart { parent.page = max(0, parent.page - 1) }
            }
        }
    }
}

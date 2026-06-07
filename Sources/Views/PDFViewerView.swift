import SwiftUI
import PDFKit
import AppKit

// MARK: - PDFViewerView
struct PDFViewerView: NSViewRepresentable {
    @EnvironmentObject var viewModel: PDFEditorViewModel

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = true
        pdfView.pageShadowsEnabled = true
        pdfView.backgroundColor = NSColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1)
        pdfView.pageBreakMargins = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)

        viewModel.pdfView = pdfView

        NotificationCenter.default.addObserver(
            context.coordinator, selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged, object: pdfView)
        NotificationCenter.default.addObserver(
            context.coordinator, selector: #selector(Coordinator.scaleChanged(_:)),
            name: .PDFViewScaleChanged, object: pdfView)
        NotificationCenter.default.addObserver(
            context.coordinator, selector: #selector(Coordinator.selectionChanged(_:)),
            name: .PDFViewSelectionChanged, object: pdfView)

        // Click gesture — tool placement and annotation selection
        let clickGesture = NSClickGestureRecognizer(
            target: context.coordinator, action: #selector(Coordinator.handleClick(_:)))
        clickGesture.isEnabled = false
        pdfView.addGestureRecognizer(clickGesture)
        context.coordinator.clickGesture = clickGesture

        // Pan gesture — drag to move annotations in Select mode
        let panGesture = NSPanGestureRecognizer(
            target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        panGesture.delegate = context.coordinator
        pdfView.addGestureRecognizer(panGesture)
        context.coordinator.panGesture = panGesture

        // Shape pan gesture — drag to draw rectangle / oval (Shift = square / circle)
        let shapePanGesture = NSPanGestureRecognizer(
            target: context.coordinator, action: #selector(Coordinator.handleShapePan(_:)))
        shapePanGesture.delegate = context.coordinator
        pdfView.addGestureRecognizer(shapePanGesture)
        context.coordinator.shapePanGesture = shapePanGesture

        pdfView.registerForDraggedTypes([.fileURL, NSPasteboard.PasteboardType("com.adobe.pdf")])
        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        if pdfView.document !== viewModel.currentDocument {
            pdfView.document = viewModel.currentDocument
        }
        if abs(pdfView.scaleFactor - viewModel.scaleFactor) > 0.01 &&
           viewModel.scaleFactor != pdfView.scaleFactor {
            pdfView.scaleFactor = viewModel.scaleFactor
        }

        let tool = viewModel.selectedTool
        // Click gesture: off for hand (PDFKit native) and editExistingText (overlay).
        // Select mode needs it on so annotation clicks set selectedAnnotation → resize handles appear.
        context.coordinator.clickGesture?.isEnabled =
            tool != .hand && tool != .editExistingText

        // Pan gesture: drag-to-move only in select mode
        context.coordinator.panGesture?.isEnabled = tool == .select

        // Shape pan: active for rectangle and oval tools
        context.coordinator.shapePanGesture?.isEnabled = tool == .rectangle || tool == .oval

        // Defer so we don't publish @Published changes inside SwiftUI's update cycle
        if tool == .editExistingText {
            Task { @MainActor in viewModel.activateTextEditTool() }
        }

        updateCursor(for: pdfView)
    }

    private func updateCursor(for pdfView: PDFView) {
        switch viewModel.selectedTool {
        case .select:                       NSCursor.arrow.set()
        case .hand:                         NSCursor.openHand.set()
        case .stickyNote:                   NSCursor.crosshair.set()
        case .highlight, .underline,
             .strikethrough:               NSCursor.iBeam.set()
        case .ink:                          NSCursor.crosshair.set()
        case .rectangle, .oval, .line:      NSCursor.crosshair.set()
        case .typewriter:                   NSCursor.iBeam.set()
        case .editExistingText:             NSCursor.pointingHand.set()
        case .insertImage:                  NSCursor.crosshair.set()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(viewModel: viewModel) }

    // MARK: - Coordinator
    // @MainActor matches AppKit's guarantee that gesture/notification callbacks
    // are always delivered on the main thread.
    @MainActor
    final class Coordinator: NSObject, NSGestureRecognizerDelegate {
        let viewModel: PDFEditorViewModel
        weak var clickGesture: NSClickGestureRecognizer?
        weak var panGesture: NSPanGestureRecognizer?
        weak var shapePanGesture: NSPanGestureRecognizer?

        // Drag state (move annotations)
        private var dragAnnotation: PDFAnnotation?
        private var dragPage: PDFPage?
        private var dragOffset: CGPoint = .zero

        // Line-draw state
        private var lineStart: CGPoint?
        private var linePage: PDFPage?

        // Shape-draw state (rectangle / oval drag)
        private var shapeStartPoint: CGPoint?
        private var shapeDrawPage: PDFPage?
        private var shapePreviewAnnotation: PDFAnnotation?

        init(viewModel: PDFEditorViewModel) { self.viewModel = viewModel }

        // MARK: NSGestureRecognizerDelegate
        // AppKit always calls this on the main thread, so @MainActor isolation is safe.
        func gestureRecognizerShouldBegin(_ gr: NSGestureRecognizer) -> Bool {
            if gr === shapePanGesture {
                return viewModel.selectedTool == .rectangle || viewModel.selectedTool == .oval
            }

            guard gr === panGesture, viewModel.selectedTool == .select,
                  let pdfView = gr.view as? PDFView else { return false }
            let pt  = gr.location(in: pdfView)
            guard let page = pdfView.page(for: pt, nearest: true) else { return false }
            let pgPt    = pdfView.convert(pt, to: page)
            let hitRect = CGRect(x: pgPt.x - 6, y: pgPt.y - 6, width: 12, height: 12)
            let ann = page.annotation(at: pgPt)
                ?? page.annotations.first(where: { $0.bounds.intersects(hitRect) })
            guard let ann else { return false }
            dragAnnotation = ann
            dragPage       = page
            dragOffset     = CGPoint(x: pgPt.x - ann.bounds.minX, y: pgPt.y - ann.bounds.minY)
            viewModel.selectedAnnotation = ann
            viewModel.syncShapeProperties(from: ann)
            return true
        }

        // MARK: Notifications
        // PDFKit fires these synchronously, sometimes during SwiftUI's update cycle.
        // Wrapping in Task defers the @Published mutations to the next run-loop turn,
        // preventing the "Publishing changes from within view updates" warning.

        @objc func pageChanged(_ n: Notification) {
            Task { @MainActor [weak self] in
                self?.viewModel.syncCurrentPage()
                self?.viewModel.refreshTextBlocksIfNeeded()
            }
        }
        @objc func scaleChanged(_ n: Notification) {
            Task { @MainActor [weak self] in self?.viewModel.syncScaleFactor() }
        }
        @objc func selectionChanged(_ n: Notification) {
            guard let pdfView = n.object as? PDFView else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let sel = pdfView.currentSelection, !(sel.string?.isEmpty ?? true) {
                    self.viewModel.lastTextSelection = sel
                }
            }
        }

        // MARK: Pan — move annotation

        @objc func handlePan(_ recognizer: NSPanGestureRecognizer) {
            guard let pdfView = recognizer.view as? PDFView,
                  let ann = dragAnnotation, let page = dragPage else { return }
            let pgPt = pdfView.convert(recognizer.location(in: pdfView), to: page)
            let pageBounds = page.bounds(for: .mediaBox)

            switch recognizer.state {
            case .changed:
                var nb = ann.bounds
                nb.origin.x = max(pageBounds.minX,
                    min(pgPt.x - dragOffset.x, pageBounds.maxX - nb.width))
                nb.origin.y = max(pageBounds.minY,
                    min(pgPt.y - dragOffset.y, pageBounds.maxY - nb.height))
                ann.bounds = nb
            case .ended:
                viewModel.isModified = true
                dragAnnotation = nil; dragPage = nil
            case .cancelled, .failed:
                dragAnnotation = nil; dragPage = nil
            default: break
            }
        }

        // MARK: Shape draw — rectangle / oval drag (Shift = square / circle)

        @objc func handleShapePan(_ recognizer: NSPanGestureRecognizer) {
            guard let pdfView = recognizer.view as? PDFView else { return }
            let viewPt = recognizer.location(in: pdfView)
            guard let page = pdfView.page(for: viewPt, nearest: true) else { return }
            let pgPt  = pdfView.convert(viewPt, to: page)
            let shift = NSEvent.modifierFlags.contains(.shift)
            let tool  = viewModel.selectedTool

            switch recognizer.state {
            case .began:
                shapeStartPoint = pgPt
                shapeDrawPage   = page
                // Create a tiny live-preview annotation
                let type: PDFAnnotationSubtype = tool == .rectangle ? .square : .circle
                let ann = PDFAnnotation(
                    bounds: CGRect(x: pgPt.x, y: pgPt.y, width: 2, height: 2),
                    forType: type, withProperties: nil)
                ann.color = NSColor(viewModel.annotationColor).withAlphaComponent(0.3)
                let border = PDFBorder(); border.lineWidth = 2
                ann.border = border
                page.addAnnotation(ann)
                shapePreviewAnnotation = ann

            case .changed:
                guard let start = shapeStartPoint,
                      let ann   = shapePreviewAnnotation else { return }
                ann.bounds = constrainedRect(from: start, to: pgPt, constrain: shift)

            case .ended:
                guard let start = shapeStartPoint,
                      let ann   = shapePreviewAnnotation,
                      let pg    = shapeDrawPage else { return }
                let finalRect = constrainedRect(from: start, to: pgPt, constrain: shift)
                // Discard sub-pixel drags (treat as a click — click handler places default shape)
                if finalRect.width < 4 && finalRect.height < 4 {
                    pg.removeAnnotation(ann)
                } else {
                    ann.bounds = finalRect
                    viewModel.isModified = true
                }
                shapeStartPoint = nil; shapeDrawPage = nil; shapePreviewAnnotation = nil

            case .cancelled, .failed:
                if let ann = shapePreviewAnnotation, let pg = shapeDrawPage {
                    pg.removeAnnotation(ann)
                }
                shapeStartPoint = nil; shapeDrawPage = nil; shapePreviewAnnotation = nil

            default: break
            }
        }

        /// Builds a CGRect from two page-space points.
        /// When `constrain` is true the shorter dimension is expanded to match the longer,
        /// keeping the origin corner anchored at `start`.
        private func constrainedRect(from start: CGPoint, to end: CGPoint, constrain: Bool) -> CGRect {
            var w = abs(end.x - start.x)
            var h = abs(end.y - start.y)
            if constrain { w = max(w, h); h = w }
            let x = end.x >= start.x ? start.x : start.x - w
            let y = end.y >= start.y ? start.y : start.y - h
            return CGRect(x: x, y: y, width: max(w, 2), height: max(h, 2))
        }

        // MARK: Click — tool action

        @objc func handleClick(_ recognizer: NSClickGestureRecognizer) {
            guard let pdfView = recognizer.view as? PDFView else { return }
            let viewPt = recognizer.location(in: pdfView)
            guard let page = pdfView.page(for: viewPt, nearest: true) else { return }
            let pgPt      = pdfView.convert(viewPt, to: page)
            let shiftHeld = NSEvent.modifierFlags.contains(.shift)
            dispatch(at: pgPt, on: page, in: pdfView, shiftHeld: shiftHeld)
        }

        @MainActor private func dispatch(at point: CGPoint, on page: PDFPage, in pdfView: PDFView,
                              shiftHeld: Bool = false) {
            switch viewModel.selectedTool {

            case .select:
                // Expand hit area for thin shapes (lines, borders)
                let hitRect = CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12)
                let ann = page.annotation(at: point)
                    ?? page.annotations.first(where: { $0.bounds.intersects(hitRect) })
                if let ann {
                    viewModel.selectedAnnotation = ann
                    viewModel.syncShapeProperties(from: ann)
                    viewModel.showStatus("Selected — drag to move · ⌫ to delete · change properties in toolbar")
                } else {
                    viewModel.selectedAnnotation = nil
                }

            case .hand:
                break // PDFKit native scroll

            case .stickyNote:
                viewModel.addStickyNote(at: point, on: page)

            case .highlight:
                if let sel = pdfView.currentSelection, !sel.string.isNilOrEmpty {
                    viewModel.addHighlight(selection: sel); pdfView.clearSelection()
                }
            case .underline:
                if let sel = pdfView.currentSelection, !sel.string.isNilOrEmpty {
                    viewModel.addUnderline(selection: sel); pdfView.clearSelection()
                }
            case .strikethrough:
                if let sel = pdfView.currentSelection, !sel.string.isNilOrEmpty {
                    viewModel.addStrikethrough(selection: sel); pdfView.clearSelection()
                }

            case .rectangle:
                // Shift = square (equal sides); default = landscape rectangle
                let rw: CGFloat = shiftHeld ? 100 : 120
                let rh: CGFloat = shiftHeld ? 100 : 80
                viewModel.addRectangleAnnotation(
                    at: CGRect(x: point.x - rw / 2, y: point.y - rh / 2, width: rw, height: rh),
                    on: page)

            case .oval:
                // Shift = circle (equal axes); default = ellipse
                let ow: CGFloat = shiftHeld ? 100 : 100
                let oh: CGFloat = shiftHeld ? 100 : 70
                viewModel.addOvalAnnotation(
                    at: CGRect(x: point.x - ow / 2, y: point.y - oh / 2, width: ow, height: oh),
                    on: page)

            case .line:
                // First click = start, second click = end
                if let start = lineStart, let lp = linePage, lp === page {
                    viewModel.addLineAnnotation(from: start, to: point, on: page)
                    lineStart = nil; linePage = nil
                    viewModel.showStatus("")
                } else {
                    lineStart = point; linePage = page
                    viewModel.showStatus("Click a second point to finish the line")
                }

            case .typewriter:
                if page.annotation(at: point) != nil { return }
                viewModel.pendingTextPage     = page
                viewModel.pendingTextLocation = point
                viewModel.showAddTextSheet    = true

            case .editExistingText:
                break // handled by TextBlockHighlightOverlay

            case .insertImage:
                viewModel.promptInsertImage(on: page)

            case .ink:
                break // drag-based
            }
        }
    }
}

// MARK: - Helpers
private extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool { self == nil || self!.isEmpty }
}

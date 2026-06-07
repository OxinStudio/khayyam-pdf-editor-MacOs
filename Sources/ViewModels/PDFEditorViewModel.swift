import SwiftUI
import PDFKit
import UniformTypeIdentifiers
import AppKit

// MARK: - Annotation Tool Enum
enum AnnotationTool: String, CaseIterable, Identifiable {
    // Navigate
    case select            = "select"
    case hand              = "hand"
    // Comment
    case stickyNote        = "stickyNote"
    case highlight         = "highlight"
    case underline         = "underline"
    case strikethrough     = "strikethrough"
    // Drawing
    case ink               = "ink"
    case rectangle         = "rectangle"
    case oval              = "oval"
    case line              = "line"
    // Text
    case typewriter        = "typewriter"
    case editExistingText  = "editExistingText"
    // Insert
    case insertImage       = "insertImage"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .select:           return "Select"
        case .hand:             return "Hand"
        case .stickyNote:       return "Note"
        case .highlight:        return "Highlight"
        case .underline:        return "Underline"
        case .strikethrough:    return "Strikethrough"
        case .ink:              return "Draw"
        case .rectangle:        return "Rectangle"
        case .oval:             return "Oval"
        case .line:             return "Line"
        case .typewriter:       return "Typewriter"
        case .editExistingText: return "Edit Text"
        case .insertImage:      return "Image"
        }
    }

    var sfSymbol: String {
        switch self {
        case .select:           return "cursorarrow"
        case .hand:             return "hand.raised"
        case .stickyNote:       return "note.text"
        case .highlight:        return "highlighter"
        case .underline:        return "underline"
        case .strikethrough:    return "strikethrough"
        case .ink:              return "pencil.tip"
        case .rectangle:        return "rectangle"
        case .oval:             return "oval"
        case .line:             return "line.diagonal"
        case .typewriter:       return "text.cursor"
        case .editExistingText: return "pencil.and.outline"
        case .insertImage:      return "photo"
        }
    }

    /// True for tools that apply to a text selection rather than a click position
    var isMarkup: Bool {
        self == .highlight || self == .underline || self == .strikethrough
    }
}

// MARK: - View Model
@MainActor
final class PDFEditorViewModel: ObservableObject {

    // MARK: - Document State
    @Published var currentDocument: PDFDocument?
    @Published var currentDocumentURL: URL?
    @Published var documentTitle: String = "Khayyam PDF Editor"
    @Published var isModified: Bool = false

    // MARK: - Navigation
    @Published var currentPageIndex: Int = 0
    @Published var totalPages: Int = 0
    @Published var goToPageInput: String = ""

    // MARK: - Zoom
    @Published var scaleFactor: CGFloat = 1.0

    // MARK: - Annotation State
    @Published var selectedTool: AnnotationTool = .select
    @Published var annotationColor: Color = .black      // default stroke for drawing tools
    @Published var highlightColor: Color = .yellow
    @Published var underlineColor: Color = .blue
    @Published var strikethroughColor: Color = .red
    @Published var annotationFontSize: CGFloat = 14
    @Published var selectedAnnotation: PDFAnnotation?

    // MARK: - Shape Properties (synced from/to selected annotation)
    @Published var shapeStrokeColor: Color = .black
    @Published var shapeStrokeWidth: CGFloat = 2
    @Published var shapeFillColor: Color = Color(nsColor: .clear)
    @Published var shapeHasFill: Bool = false

    // MARK: - Sidebar
    @Published var sidebarMode: SidebarMode = .thumbnails
    @Published var isSidebarVisible: Bool = true

    // MARK: - Sheets
    @Published var showMergeSheet: Bool = false
    @Published var showSplitSheet: Bool = false
    @Published var showTextInsertSheet: Bool = false
    @Published var showImageInsertSheet: Bool = false
    @Published var showGoToPageSheet: Bool = false

    // MARK: - Markup
    /// Last non-empty text selection — survives toolbar button focus changes
    var lastTextSelection: PDFSelection?

    // MARK: - Search
    @Published var searchQuery: String = ""
    @Published var searchResults: [PDFSelection] = []
    @Published var currentSearchIndex: Int = 0

    // MARK: - Status
    @Published var statusMessage: String = ""

    // MARK: - MuPDF text editing
    @Published var textEditEngine = PDFTextEditEngine()
    @Published var selectedTextBlock: TextBlock? = nil   // triggers popover

    // MARK: - Add Text sheet
    @Published var showAddTextSheet: Bool = false
    var pendingTextLocation: CGPoint = .zero
    weak var pendingTextPage: PDFPage? = nil

    // MARK: - PDFView reference (set by PDFViewerView)
    weak var pdfView: PDFView?

    enum SidebarMode: String, CaseIterable {
        case thumbnails = "Thumbnails"
        case outline    = "Outline"
    }

    // MARK: - Open PDF
    func openPDF() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose a PDF to open"
        panel.prompt = "Open"

        panel.begin { [weak self] response in
            guard let self, response == .OK, let url = panel.url else { return }
            self.loadPDF(from: url)
        }
    }

    func loadPDF(from url: URL) {
        guard let doc = PDFDocument(url: url) else {
            showStatus("Failed to open PDF.")
            return
        }
        currentDocument = doc
        currentDocumentURL = url
        documentTitle = url.deletingPathExtension().lastPathComponent
        totalPages = doc.pageCount
        currentPageIndex = 0
        isModified = false
        scaleFactor = 1.0
        searchResults = []
        // Load into MuPDF engine for text editing
        textEditEngine.load(url: url)
        showStatus("Opened \(url.lastPathComponent)")
    }

    // MARK: - Save
    func savePDF() {
        guard let doc = currentDocument else { return }
        if let url = currentDocumentURL {
            doc.write(to: url)
            isModified = false
            showStatus("Saved.")
        } else {
            saveAsPDF()
        }
    }

    func saveAsPDF() {
        guard let doc = currentDocument else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.pdf]
        panel.nameFieldStringValue = (documentTitle.isEmpty ? "document" : documentTitle) + ".pdf"
        panel.message = "Save PDF"
        panel.prompt = "Save"

        panel.begin { [weak self] response in
            guard let self, response == .OK, let url = panel.url else { return }
            doc.write(to: url)
            self.currentDocumentURL = url
            self.documentTitle = url.deletingPathExtension().lastPathComponent
            self.isModified = false
            self.showStatus("Saved as \(url.lastPathComponent)")
        }
    }

    func exportAsPDF() {
        saveAsPDF()
    }

    // MARK: - Navigation
    func goToFirstPage() {
        guard let doc = currentDocument, let page = doc.page(at: 0) else { return }
        pdfView?.go(to: page)
        currentPageIndex = 0
    }

    func goToLastPage() {
        guard let doc = currentDocument else { return }
        let last = doc.pageCount - 1
        guard let page = doc.page(at: last) else { return }
        pdfView?.go(to: page)
        currentPageIndex = last
    }

    func goToPreviousPage() {
        guard currentPageIndex > 0 else { return }
        currentPageIndex -= 1
        guard let page = currentDocument?.page(at: currentPageIndex) else { return }
        pdfView?.go(to: page)
    }

    func goToNextPage() {
        guard let doc = currentDocument, currentPageIndex < doc.pageCount - 1 else { return }
        currentPageIndex += 1
        guard let page = doc.page(at: currentPageIndex) else { return }
        pdfView?.go(to: page)
    }

    func goToPage(_ index: Int) {
        guard let doc = currentDocument,
              index >= 0, index < doc.pageCount,
              let page = doc.page(at: index) else { return }
        pdfView?.go(to: page)
        currentPageIndex = index
    }

    func syncCurrentPage() {
        guard let page = pdfView?.currentPage,
              let doc = currentDocument else { return }
        let idx = doc.index(for: page)
        if idx != NSNotFound {
            currentPageIndex = idx
        }
    }

    // MARK: - Zoom
    func zoomIn() {
        pdfView?.zoomIn(nil)
        syncScaleFactor()
    }

    func zoomOut() {
        pdfView?.zoomOut(nil)
        syncScaleFactor()
    }

    func zoomToActualSize() {
        pdfView?.scaleFactor = 1.0
        scaleFactor = 1.0
    }

    func zoomToFit() {
        pdfView?.autoScales = true
        syncScaleFactor()
    }

    func syncScaleFactor() {
        scaleFactor = pdfView?.scaleFactor ?? 1.0
    }

    // MARK: - Markup apply (called directly from toolbar buttons)
    func applyMarkup(_ tool: AnnotationTool) {
        // Prefer freshly-stored selection; fall back to pdfView's current selection
        guard let sel = lastTextSelection ?? pdfView?.currentSelection,
              !(sel.string?.isEmpty ?? true) else {
            showStatus("Select some text first, then click \(tool.displayName)")
            return
        }
        switch tool {
        case .highlight:     addHighlight(selection: sel)
        case .underline:     addUnderline(selection: sel)
        case .strikethrough: addStrikethrough(selection: sel)
        default: break
        }
        pdfView?.clearSelection()
        lastTextSelection = nil
    }

    // MARK: - Annotations
    func addHighlight(selection: PDFSelection) {
        selection.pages.forEach { page in
            let bounds = selection.bounds(for: page)
            let annotation = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
            annotation.color = NSColor(highlightColor).withAlphaComponent(0.45)
            page.addAnnotation(annotation)
        }
        markModified()
    }

    func addUnderline(selection: PDFSelection) {
        selection.pages.forEach { page in
            let bounds = selection.bounds(for: page)
            let annotation = PDFAnnotation(bounds: bounds, forType: .underline, withProperties: nil)
            annotation.color = NSColor(underlineColor)
            page.addAnnotation(annotation)
        }
        markModified()
    }

    func addStrikethrough(selection: PDFSelection) {
        selection.pages.forEach { page in
            let bounds = selection.bounds(for: page)
            let annotation = PDFAnnotation(bounds: bounds, forType: .strikeOut, withProperties: nil)
            annotation.color = NSColor(strikethroughColor)
            page.addAnnotation(annotation)
        }
        markModified()
    }

    func addFreeTextAnnotation(
        at bounds: CGRect,
        on page: PDFPage,
        text: String,
        font: NSFont? = nil,
        textColor: NSColor? = nil,
        bgColor: NSColor? = nil,
        alignment: NSTextAlignment = .left
    ) {
        let annotation = PDFAnnotation(bounds: bounds, forType: .freeText, withProperties: nil)
        annotation.contents = text
        annotation.font = font ?? NSFont.systemFont(ofSize: annotationFontSize)
        annotation.fontColor = textColor ?? NSColor(annotationColor)
        annotation.color = bgColor ?? NSColor.clear
        annotation.alignment = alignment
        annotation.isReadOnly = false
        page.addAnnotation(annotation)
        markModified()
    }

    func addStickyNote(at point: CGPoint, on page: PDFPage) {
        // PDFKit's .text annotation = the classic sticky note icon (like Acrobat)
        // Double-clicking it opens an inline editor — PDFKit handles this natively.
        let bounds = CGRect(x: point.x, y: point.y, width: 30, height: 30)
        let annotation = PDFAnnotation(bounds: bounds, forType: .text, withProperties: nil)
        annotation.contents = ""
        annotation.color = NSColor.yellow
        annotation.isReadOnly = false
        page.addAnnotation(annotation)
        markModified()
        // Switch to select so user can immediately double-click to edit
        selectedTool = .select
    }

    func addRectangleAnnotation(at bounds: CGRect, on page: PDFPage) {
        let annotation = PDFAnnotation(bounds: bounds, forType: .square, withProperties: nil)
        annotation.color = NSColor(annotationColor).withAlphaComponent(0.3)
        annotation.border = PDFBorder()
        annotation.border?.lineWidth = 2
        page.addAnnotation(annotation)
        markModified()
    }

    func addOvalAnnotation(at bounds: CGRect, on page: PDFPage) {
        let annotation = PDFAnnotation(bounds: bounds, forType: .circle, withProperties: nil)
        annotation.color = NSColor(annotationColor).withAlphaComponent(0.3)
        annotation.border = PDFBorder()
        annotation.border?.lineWidth = 2
        page.addAnnotation(annotation)
        markModified()
    }

    func addLineAnnotation(from start: CGPoint, to end: CGPoint, on page: PDFPage) {
        let minX = min(start.x, end.x), minY = min(start.y, end.y)
        let maxX = max(start.x, end.x), maxY = max(start.y, end.y)
        let bounds = CGRect(x: minX, y: minY,
                            width: max(maxX - minX, 1),
                            height: max(maxY - minY, 1))
        let annotation = PDFAnnotation(bounds: bounds, forType: .line, withProperties: nil)
        annotation.color = NSColor(annotationColor)
        annotation.startPoint = CGPoint(x: start.x - minX, y: start.y - minY)
        annotation.endPoint   = CGPoint(x: end.x   - minX, y: end.y   - minY)
        annotation.border = PDFBorder()
        annotation.border?.lineWidth = 2
        page.addAnnotation(annotation)
        markModified()
    }

    func addImageAnnotation(image: NSImage, at bounds: CGRect, on page: PDFPage) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        let stampAnnotation = PDFAnnotation(bounds: bounds, forType: .stamp, withProperties: nil)
        let rep = NSBitmapImageRep(cgImage: cgImage)
        rep.size = bounds.size
        let pdfData = NSMutableData()
        guard let pdfConsumer = CGDataConsumer(data: pdfData as CFMutableData) else { return }
        var mediaBox = CGRect(origin: .zero, size: bounds.size)
        guard let context = CGContext(consumer: pdfConsumer, mediaBox: &mediaBox, nil) else { return }
        context.beginPDFPage(nil)
        context.draw(cgImage, in: mediaBox)
        context.endPDFPage()
        context.closePDF()
        stampAnnotation.setValue(pdfData, forAnnotationKey: PDFAnnotationKey(rawValue: "/AP"))
        page.addAnnotation(stampAnnotation)
        markModified()
    }

    func deleteSelectedAnnotation() {
        guard let annotation = selectedAnnotation,
              let page = annotation.page else { return }
        page.removeAnnotation(annotation)
        selectedAnnotation = nil
        markModified()
    }

    /// Called whenever an annotation is clicked — reads its current properties
    /// into the shape properties panel so the user can edit them.
    func syncShapeProperties(from annotation: PDFAnnotation) {
        // annotation.color is non-optional in this PDFKit version
        shapeStrokeColor = Color(annotation.color)
        // Stroke width
        shapeStrokeWidth = annotation.border?.lineWidth ?? 2
        // Fill (interiorColor is optional)
        if let fill = annotation.interiorColor,
           fill.alphaComponent > 0 {
            shapeHasFill = true
            shapeFillColor = Color(fill)
        } else {
            shapeHasFill = false
        }
    }

    /// Writes the current shape properties back to the selected annotation.
    func applyShapeProperties() {
        guard let annotation = selectedAnnotation else { return }
        annotation.color = NSColor(shapeStrokeColor)
        let border = annotation.border ?? PDFBorder()
        border.lineWidth = shapeStrokeWidth
        annotation.border = border
        annotation.interiorColor = shapeHasFill ? NSColor(shapeFillColor) : .clear
        markModified()
    }

    /// True when the selected annotation is a shape type (editable properties).
    var selectedAnnotationIsShape: Bool {
        guard let t = selectedAnnotation?.type else { return false }
        return ["Square", "Circle", "Line", "Ink", "PolyLine", "Polygon"].contains(t)
    }

    // MARK: - Page Rotation
    func rotateCurrentPage(by degrees: Int) {
        guard let doc = currentDocument,
              let page = doc.page(at: currentPageIndex) else { return }
        page.rotation = (page.rotation + degrees + 360) % 360
        markModified()
    }

    // MARK: - Search
    func search() {
        guard let doc = currentDocument, !searchQuery.isEmpty else {
            searchResults = []
            return
        }
        searchResults = doc.findString(searchQuery, withOptions: .caseInsensitive)
        currentSearchIndex = 0
        highlightSearchResult()
    }

    func nextSearchResult() {
        guard !searchResults.isEmpty else { return }
        currentSearchIndex = (currentSearchIndex + 1) % searchResults.count
        highlightSearchResult()
    }

    func previousSearchResult() {
        guard !searchResults.isEmpty else { return }
        currentSearchIndex = (currentSearchIndex - 1 + searchResults.count) % searchResults.count
        highlightSearchResult()
    }

    private func highlightSearchResult() {
        guard !searchResults.isEmpty else { return }
        let selection = searchResults[currentSearchIndex]
        pdfView?.setCurrentSelection(selection, animate: true)
        pdfView?.scrollSelectionToVisible(nil)
    }

    // MARK: - MuPDF Text Edit

    /// Called when the user switches to the Edit Text tool — loads text blocks for the current page.
    func activateTextEditTool() {
        guard textEditEngine.isAvailable else {
            showStatus("MuPDF not available — rebuild with MuPDF installed.")
            return
        }
        textEditEngine.loadTextBlocks(forPage: currentPageIndex)
    }

    /// Called when tool or page changes while in text-edit mode.
    func refreshTextBlocksIfNeeded() {
        guard selectedTool == .editExistingText else { return }
        activateTextEditTool()
    }

    func isSelectOrHandTool() -> Bool {
        selectedTool == .select || selectedTool == .hand
    }

    /// Applies a text replacement: redacts via MuPDF, reloads PDFKit document.
    func applyTextEdit(block: TextBlock, newText: String) async -> Bool {
        guard let doc = currentDocument else { return false }
        // replaceText adds annotations directly to the existing PDFDocument
        // (no reload needed — PDFKit updates the view automatically)
        guard textEditEngine.replaceText(
            block: block,
            withText: newText,
            in: doc,
            documentURL: currentDocumentURL
        ) != nil else { return false }
        isModified = true
        // Refresh block detection for this page
        textEditEngine.loadTextBlocks(forPage: block.pageIndex)
        showStatus("Text updated.")
        return true
    }

    // MARK: - Insert Image from File
    func promptInsertImage(on page: PDFPage) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.image, UTType.png, UTType.jpeg, UTType.tiff]
        panel.allowsMultipleSelection = false
        panel.message = "Choose an image to insert"
        panel.prompt = "Insert"

        panel.begin { [weak self] response in
            guard let self, response == .OK, let url = panel.url,
                  let image = NSImage(contentsOf: url) else { return }
            let pageSize = page.bounds(for: .mediaBox)
            let imageSize = CGSize(width: min(200, pageSize.width * 0.4),
                                   height: min(200, pageSize.height * 0.4))
            let origin = CGPoint(x: (pageSize.width - imageSize.width) / 2,
                                 y: (pageSize.height - imageSize.height) / 2)
            let bounds = CGRect(origin: origin, size: imageSize)
            self.addImageAnnotation(image: image, at: bounds, on: page)
        }
    }

    // MARK: - Helpers
    private func markModified() {
        isModified = true
    }

    func showStatus(_ message: String) {
        statusMessage = message
        Task {
            try? await Task.sleep(for: .seconds(3))
            if statusMessage == message {
                statusMessage = ""
            }
        }
    }
}

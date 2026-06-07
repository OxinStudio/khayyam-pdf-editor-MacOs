import Foundation
import PDFKit
import AppKit

// MARK: - Swift-friendly models

struct TextBlock: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let bounds: CGRect          // PDF page coordinates (bottom-left origin, y-up)
    let pageIndex: Int
    let fontSize: CGFloat
    let lines: [TextLine]

    static func == (lhs: TextBlock, rhs: TextBlock) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct TextLine: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let bounds: CGRect

    static func == (lhs: TextLine, rhs: TextLine) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - PDFTextEditEngine

/// High-level Swift API for MuPDF-powered text editing.
/// Keeps a MuPDF document open alongside the PDFKit document.
/// Call `load(url:)` whenever a new PDF is opened.
@MainActor
final class PDFTextEditEngine: ObservableObject {

    // MARK: - State
    @Published var isAvailable: Bool = false
    @Published var textBlocks: [TextBlock] = []
    @Published var isLoading: Bool = false

    private var bridge: PDFMuPDFBridge?
    private var loadedURL: URL?

    // MARK: - Load

    func load(url: URL) {
        // Swift imports Obj-C nullable+NSError** inits as `throws`
        do {
            bridge = try PDFMuPDFBridge(url: url)
            loadedURL = url
            isAvailable = true
        } catch {
            bridge = nil
            loadedURL = nil
            isAvailable = false
            print("[PDFTextEditEngine] Failed to load: \(error.localizedDescription)")
        }
    }

    func unload() {
        bridge = nil
        loadedURL = nil
        isAvailable = false
        textBlocks = []
    }

    // MARK: - Text block extraction

    /// Fetch text blocks for a given page and cache them.
    func loadTextBlocks(forPage pageIndex: Int) {
        guard let bridge else { textBlocks = []; return }
        isLoading = true

        // MuPDF's fz_context is NOT thread-safe — calling it from a detached task
        // (a different thread) would crash. Run synchronously on the main actor instead.
        // Text block extraction is fast enough (< 50 ms for typical pages) that
        // blocking the main thread is acceptable here.
        let raw = bridge.textBlocks(onPage: Int32(pageIndex))
        textBlocks = raw.map { b in
            let lines = b.lines.map { l in TextLine(text: l.text, bounds: l.bounds) }
            return TextBlock(
                text: b.text,
                bounds: b.bounds,
                pageIndex: Int(b.pageIndex),
                fontSize: CGFloat(b.dominantFontSize),
                lines: lines
            )
        }
        isLoading = false
    }

    /// Returns the text block that contains the given point (PDF page coordinates).
    func block(at point: CGPoint) -> TextBlock? {
        textBlocks.first { $0.bounds.contains(point) }
    }

    // MARK: - Edit

    /// Replaces a text block's content using a PDFKit overlay:
    /// 1. White-filled rectangle annotation covers the original text visually.
    /// 2. FreeText annotation renders the new text at the same position & size.
    ///
    /// MuPDF is used for accurate text-block detection; PDFKit handles the
    /// replacement so it works on all PDFs regardless of embedded fonts.
    func replaceText(
        block: TextBlock,
        withText newText: String,
        in pdfKitDocument: PDFDocument,
        documentURL: URL?
    ) -> PDFDocument? {

        guard let page = pdfKitDocument.page(at: block.pageIndex) else { return nil }

        // ── 1. White rectangle covers the original text ──────────────────────
        let cover = PDFAnnotation(bounds: block.bounds,
                                  forType: .square,
                                  withProperties: nil)
        cover.interiorColor = .white
        cover.color = .white          // border same as fill → invisible border
        cover.border = PDFBorder()
        cover.border?.lineWidth = 0
        page.addAnnotation(cover)

        // ── 2. FreeText annotation renders the replacement text ───────────────
        let textAnnot = PDFAnnotation(bounds: block.bounds,
                                      forType: .freeText,
                                      withProperties: nil)
        textAnnot.contents = newText
        textAnnot.font = NSFont.systemFont(ofSize: block.fontSize)
        textAnnot.fontColor = .black
        textAnnot.color = .clear      // transparent annotation border
        textAnnot.isReadOnly = false
        page.addAnnotation(textAnnot)

        return pdfKitDocument
    }
}

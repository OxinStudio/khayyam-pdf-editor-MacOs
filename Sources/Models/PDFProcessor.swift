import Foundation
import PDFKit
import AppKit

/// Static utilities for PDF manipulation (merge, split, rotate, metadata).
enum PDFProcessor {

    // MARK: - Merge

    /// Merges an ordered list of PDF documents into a single document.
    static func merge(documents: [PDFDocument]) -> PDFDocument? {
        guard !documents.isEmpty else { return nil }
        let merged = PDFDocument()

        for doc in documents {
            for pageIndex in 0..<doc.pageCount {
                guard let page = doc.page(at: pageIndex),
                      let copied = page.copy() as? PDFPage else { continue }
                merged.insert(copied, at: merged.pageCount)
            }
        }
        return merged.pageCount > 0 ? merged : nil
    }

    /// Merge PDFs from file URLs.
    static func merge(urls: [URL]) -> PDFDocument? {
        let docs = urls.compactMap { PDFDocument(url: $0) }
        return merge(documents: docs)
    }

    // MARK: - Split

    /// Splits a PDF document into chunks of a given page count.
    static func split(document: PDFDocument, into chunkSize: Int) -> [PDFDocument] {
        guard chunkSize > 0 else { return [] }
        var result: [PDFDocument] = []
        var start = 0

        while start < document.pageCount {
            let end = min(start + chunkSize, document.pageCount)
            if let chunk = extractPages(from: document, range: start..<end) {
                result.append(chunk)
            }
            start = end
        }
        return result
    }

    /// Extracts a specific range of pages into a new document.
    static func extractPages(from document: PDFDocument, range: Range<Int>) -> PDFDocument? {
        let newDoc = PDFDocument()
        var insertIndex = 0

        for i in range {
            guard i < document.pageCount,
                  let page = document.page(at: i),
                  let copied = page.copy() as? PDFPage else { continue }
            newDoc.insert(copied, at: insertIndex)
            insertIndex += 1
        }
        return newDoc.pageCount > 0 ? newDoc : nil
    }

    /// Splits at specific page indices (each index starts a new document).
    static func split(document: PDFDocument, atPages splitPoints: [Int]) -> [PDFDocument] {
        var results: [PDFDocument] = []
        let points = ([0] + splitPoints.sorted() + [document.pageCount]).uniqued()

        for i in 0..<(points.count - 1) {
            let start = points[i]
            let end = points[i + 1]
            if start < end, let doc = extractPages(from: document, range: start..<end) {
                results.append(doc)
            }
        }
        return results
    }

    // MARK: - Delete Pages

    /// Returns a new document with the specified pages removed.
    static func deletePages(from document: PDFDocument, at indices: Set<Int>) -> PDFDocument? {
        let newDoc = PDFDocument()
        var insertIndex = 0

        for i in 0..<document.pageCount {
            guard !indices.contains(i),
                  let page = document.page(at: i),
                  let copied = page.copy() as? PDFPage else { continue }
            newDoc.insert(copied, at: insertIndex)
            insertIndex += 1
        }
        return newDoc.pageCount > 0 ? newDoc : nil
    }

    // MARK: - Reorder Pages

    /// Returns a new document with pages reordered per the given index array.
    static func reorderPages(in document: PDFDocument, order: [Int]) -> PDFDocument? {
        let newDoc = PDFDocument()
        for (newIndex, oldIndex) in order.enumerated() {
            guard let page = document.page(at: oldIndex),
                  let copied = page.copy() as? PDFPage else { continue }
            newDoc.insert(copied, at: newIndex)
        }
        return newDoc.pageCount > 0 ? newDoc : nil
    }

    // MARK: - Save Helper

    /// Writes a PDFDocument to a user-chosen save location.
    @MainActor
    static func saveWithPanel(document: PDFDocument, suggestedName: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = suggestedName.hasSuffix(".pdf") ? suggestedName : suggestedName + ".pdf"
        panel.message = "Save PDF"
        panel.prompt = "Save"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            document.write(to: url)
        }
    }

    // MARK: - Metadata

    struct PDFMetadata {
        var title: String
        var author: String
        var subject: String
        var keywords: String
        var creator: String
        var pageCount: Int
        var fileSizeBytes: Int
        var isEncrypted: Bool
    }

    static func metadata(for document: PDFDocument, url: URL? = nil) -> PDFMetadata {
        var size = 0
        if let url, let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) {
            size = (attrs[.size] as? Int) ?? 0
        }
        return PDFMetadata(
            title:      document.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String ?? "",
            author:     document.documentAttributes?[PDFDocumentAttribute.authorAttribute] as? String ?? "",
            subject:    document.documentAttributes?[PDFDocumentAttribute.subjectAttribute] as? String ?? "",
            keywords:   document.documentAttributes?[PDFDocumentAttribute.keywordsAttribute] as? String ?? "",
            creator:    document.documentAttributes?[PDFDocumentAttribute.creatorAttribute] as? String ?? "",
            pageCount:  document.pageCount,
            fileSizeBytes: size,
            isEncrypted: document.isEncrypted
        )
    }
}

// MARK: - Array uniqued helper
private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

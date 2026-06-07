import SwiftUI
import PDFKit
import UniformTypeIdentifiers

// MARK: - Merge View
struct MergeView: View {
    @EnvironmentObject var viewModel: PDFEditorViewModel
    @Environment(\.dismiss) var dismiss

    @State private var urls: [URL] = []
    @State private var isTargeted = false
    @State private var isMerging = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Merge PDFs")
                        .font(.headline)
                    Text("Combine multiple PDF files into one document")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // File list
            if urls.isEmpty {
                DropZone(isTargeted: $isTargeted, onDrop: handleDrop)
                    .padding()
            } else {
                List {
                    ForEach(urls, id: \.self) { url in
                        HStack {
                            Image(systemName: "doc.fill")
                                .foregroundColor(Color.accentColor)
                            Text(url.lastPathComponent)
                                .lineLimit(1)
                            Spacer()
                            Button {
                                urls.removeAll { $0 == url }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(Color.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .onMove { from, to in
                        urls.move(fromOffsets: from, toOffset: to)
                    }
                }
                .listStyle(.plain)
                .frame(minHeight: 200)
                .onDrop(of: [.pdf, .fileURL], isTargeted: $isTargeted) { providers in
                    handleDrop(providers: providers)
                }
            }

            Divider()

            // Footer
            HStack {
                Button("Add PDFs…", action: addPDFs)
                    .buttonStyle(.bordered)

                if !urls.isEmpty {
                    Text("\(urls.count) file\(urls.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(Color.red)
                }

                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)

                Button {
                    mergeAndSave()
                } label: {
                    if isMerging {
                        ProgressView().scaleEffect(0.7)
                    } else {
                        Text("Merge & Save…")
                    }
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(urls.count < 2 || isMerging)
            }
            .padding()
        }
        .frame(width: 500, height: 420)
    }

    private func addPDFs() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.pdf]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.message = "Choose PDFs to merge"

        panel.begin { response in
            guard response == .OK else { return }
            let newURLs = panel.urls.filter { !self.urls.contains($0) }
            self.urls.append(contentsOf: newURLs)
        }
    }

    @discardableResult
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url, url.pathExtension.lowercased() == "pdf" else { return }
                Task { @MainActor in
                    if !self.urls.contains(url) {
                        self.urls.append(url)
                    }
                }
            }
        }
        return true
    }

    private func mergeAndSave() {
        isMerging = true
        errorMessage = nil

        Task {
            let docs = urls.compactMap { PDFDocument(url: $0) }
            guard let merged = PDFProcessor.merge(documents: docs) else {
                await MainActor.run {
                    errorMessage = "Failed to merge documents."
                    isMerging = false
                }
                return
            }

            await MainActor.run {
                isMerging = false
                PDFProcessor.saveWithPanel(document: merged, suggestedName: "Merged Document.pdf")
                dismiss()
            }
        }
    }
}

// MARK: - Split View
struct SplitView: View {
    @EnvironmentObject var viewModel: PDFEditorViewModel
    @Environment(\.dismiss) var dismiss

    enum SplitMode: String, CaseIterable {
        case byPageCount = "Every N Pages"
        case atPages     = "At Specific Pages"
        case extractRange = "Extract Range"
    }

    @State private var mode: SplitMode = .byPageCount
    @State private var chunkSize: Int = 1
    @State private var splitPointsText: String = ""
    @State private var rangeStart: Int = 1
    @State private var rangeEnd: Int = 1
    @State private var isSplitting = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var totalPages: Int { viewModel.currentDocument?.pageCount ?? 1 }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Split PDF")
                        .font(.headline)
                    if let doc = viewModel.currentDocument {
                        Text("\(doc.pageCount) pages total")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Mode picker
            Picker("Split Mode", selection: $mode) {
                ForEach(SplitMode.allCases, id: \.self) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            // Options
            VStack(alignment: .leading, spacing: 16) {
                switch mode {
                case .byPageCount:
                    VStack(alignment: .leading) {
                        Text("Split every \(chunkSize) page\(chunkSize == 1 ? "" : "s")")
                            .font(.subheadline)
                        Stepper(value: $chunkSize, in: 1...max(1, totalPages)) {
                            Text("Pages per part: \(chunkSize)")
                        }
                        Text("This will create approximately \(Int(ceil(Double(totalPages) / Double(chunkSize)))) files.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                case .atPages:
                    VStack(alignment: .leading) {
                        Text("Split at page numbers (comma-separated)")
                            .font(.subheadline)
                        TextField("e.g. 3, 7, 12", text: $splitPointsText)
                            .textFieldStyle(.roundedBorder)
                        Text("Each number starts a new document. Enter page numbers from 2 to \(totalPages - 1).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                case .extractRange:
                    VStack(alignment: .leading) {
                        Text("Extract a page range into a new file")
                            .font(.subheadline)
                        HStack {
                            Text("From page:")
                            TextField("", value: $rangeStart, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                            Text("to page:")
                            TextField("", value: $rangeEnd, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                            Text("of \(totalPages)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            Divider()

            // Footer
            HStack {
                if let error = errorMessage {
                    Text(error).font(.caption).foregroundColor(Color.red)
                } else if let success = successMessage {
                    Text(success).font(.caption).foregroundColor(Color.green)
                }
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.escape)
                Button {
                    performSplit()
                } label: {
                    if isSplitting {
                        ProgressView().scaleEffect(0.7)
                    } else {
                        Text("Split & Save…")
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
                .disabled(isSplitting || viewModel.currentDocument == nil)
            }
            .padding()
        }
        .frame(width: 480, height: 360)
        .onAppear {
            rangeEnd = totalPages
        }
    }

    private func performSplit() {
        guard let doc = viewModel.currentDocument else { return }
        isSplitting = true
        errorMessage = nil

        Task {
            var parts: [PDFDocument] = []

            switch mode {
            case .byPageCount:
                parts = PDFProcessor.split(document: doc, into: chunkSize)

            case .atPages:
                let points = splitPointsText
                    .split(separator: ",")
                    .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
                    .filter { $0 > 0 && $0 < doc.pageCount }
                parts = PDFProcessor.split(document: doc, atPages: points)

            case .extractRange:
                let start = max(1, rangeStart) - 1
                let end   = min(totalPages, rangeEnd)
                if start < end, let extracted = PDFProcessor.extractPages(from: doc, range: start..<end) {
                    parts = [extracted]
                }
            }

            guard !parts.isEmpty else {
                await MainActor.run {
                    errorMessage = "No pages to split."
                    isSplitting = false
                }
                return
            }

            let panel = NSSavePanel()
            panel.canCreateDirectories = true
            panel.message = "Choose a folder to save the split PDFs"
            panel.prompt = "Choose Folder"
            panel.nameFieldStringValue = ""

            // Use directory picker
            let dirPanel = NSOpenPanel()
            dirPanel.canChooseFiles = false
            dirPanel.canChooseDirectories = true
            dirPanel.canCreateDirectories = true
            dirPanel.message = "Choose a folder to save \(parts.count) split PDF\(parts.count == 1 ? "" : "s")"
            dirPanel.prompt = "Save Here"

            await MainActor.run {
                dirPanel.begin { [parts] response in
                    guard response == .OK, let folder = dirPanel.url else {
                        self.isSplitting = false
                        return
                    }
                    let baseName = viewModel.documentTitle.isEmpty ? "Document" : viewModel.documentTitle
                    var saved = 0
                    for (i, part) in parts.enumerated() {
                        let name = "\(baseName) – Part \(i + 1).pdf"
                        let dest = folder.appendingPathComponent(name)
                        if part.write(to: dest) { saved += 1 }
                    }
                    self.isSplitting = false
                    self.successMessage = "Saved \(saved) file\(saved == 1 ? "" : "s") to \(folder.lastPathComponent)/"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.dismiss() }
                }
            }
        }
    }
}

// MARK: - Drop Zone
struct DropZone: View {
    @Binding var isTargeted: Bool
    let onDrop: ([NSItemProvider]) -> Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(
                isTargeted ? Color.accentColor : Color.secondary.opacity(0.4),
                style: StrokeStyle(lineWidth: 2, dash: [8])
            )
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isTargeted ? Color.accentColor.opacity(0.05) : Color.clear)
            )
            .overlay {
                VStack(spacing: 12) {
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.largeTitle)
                        .foregroundColor(isTargeted ? Color.accentColor : Color.secondary)
                    Text("Drop PDFs here or")
                        .foregroundStyle(.secondary)
                    Text("click Add PDFs… below")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .onDrop(of: [.pdf, .fileURL], isTargeted: $isTargeted, perform: onDrop)
            .frame(height: 200)
            .animation(.easeInOut(duration: 0.15), value: isTargeted)
    }
}

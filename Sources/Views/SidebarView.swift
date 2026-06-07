import SwiftUI
@preconcurrency import PDFKit

// MARK: - SidebarView
struct SidebarView: View {
    @EnvironmentObject var viewModel: PDFEditorViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Mode picker
            Picker("Sidebar Mode", selection: $viewModel.sidebarMode) {
                ForEach(PDFEditorViewModel.SidebarMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(8)

            Divider()

            // Search bar (thumbnail mode)
            if viewModel.sidebarMode == .thumbnails {
                SearchBar()
                Divider()
            }

            // Content
            switch viewModel.sidebarMode {
            case .thumbnails:
                ThumbnailList()
            case .outline:
                OutlineView()
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

// MARK: - Search Bar
struct SearchBar: View {
    @EnvironmentObject var viewModel: PDFEditorViewModel

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.caption)
            TextField("Search in PDF…", text: $viewModel.searchQuery)
                .font(.caption)
                .textFieldStyle(.plain)
                .onSubmit { viewModel.search() }
                // macOS 13: single-value onChange
                .onChange(of: viewModel.searchQuery) { newValue in
                    if newValue.isEmpty { viewModel.searchResults = [] }
                }
            if !viewModel.searchQuery.isEmpty {
                Button(action: { viewModel.searchQuery = ""; viewModel.searchResults = [] }) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .font(.caption)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)

        if !viewModel.searchResults.isEmpty {
            HStack {
                Text("\(viewModel.searchResults.count) results")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: viewModel.previousSearchResult) {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.plain)
                .font(.caption2)

                Button(action: viewModel.nextSearchResult) {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.plain)
                .font(.caption2)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 4)
        }
    }
}

// MARK: - Thumbnail List
struct ThumbnailList: View {
    @EnvironmentObject var viewModel: PDFEditorViewModel

    var body: some View {
        if let document = viewModel.currentDocument {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(0..<document.pageCount, id: \.self) { index in
                            ThumbnailCell(
                                document: document,
                                pageIndex: index,
                                isSelected: viewModel.currentPageIndex == index
                            )
                            .id(index)
                            .onTapGesture {
                                viewModel.goToPage(index)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 6)
                }
                // macOS 13: single-value onChange
                .onChange(of: viewModel.currentPageIndex) { newIndex in
                    withAnimation {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
        } else {
            EmptyStateView(
                title: "No Document",
                systemImage: "doc.text",
                description: "Open a PDF to see page thumbnails"
            )
        }
    }
}

// MARK: - Thumbnail Cell
struct ThumbnailCell: View {
    let document: PDFDocument
    let pageIndex: Int
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            PDFThumbnailImage(document: document, pageIndex: pageIndex)
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3),
                                lineWidth: isSelected ? 2 : 0.5)
                )
                .shadow(color: .black.opacity(0.15), radius: 3, y: 2)

            Text("\(pageIndex + 1)")
                .font(.system(size: 10))
                .foregroundColor(isSelected ? Color.accentColor : Color.secondary)
                .fontWeight(isSelected ? .semibold : .regular)
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - PDF Thumbnail Image
struct PDFThumbnailImage: View {
    let document: PDFDocument
    let pageIndex: Int

    @State private var thumbnail: NSImage?

    var body: some View {
        Group {
            if let thumb = thumbnail {
                Image(nsImage: thumb)
                    .resizable()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .overlay(ProgressView().scaleEffect(0.5))
            }
        }
        .task(id: pageIndex) {
            await generateThumbnail()
        }
    }

    // Run on cooperative thread — avoids NSImage Sendable warning
    private func generateThumbnail() async {
        guard let page = document.page(at: pageIndex) else { return }
        let size = CGSize(width: 150, height: 200)
        // PDFPage is not Sendable — capture via nonisolated(unsafe) to suppress warning
        nonisolated(unsafe) let safePage = page
        let image: NSImage = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let thumb = safePage.thumbnail(of: size, for: .mediaBox)
                continuation.resume(returning: thumb)
            }
        }
        await MainActor.run { thumbnail = image }
    }
}

// MARK: - Outline View
struct OutlineView: View {
    @EnvironmentObject var viewModel: PDFEditorViewModel

    var body: some View {
        if let document = viewModel.currentDocument,
           let outline = document.outlineRoot {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    OutlineItems(outline: outline, level: 0)
                }
                .padding(8)
            }
        } else if viewModel.currentDocument != nil {
            EmptyStateView(
                title: "No Outline",
                systemImage: "list.bullet.indent",
                description: "This PDF has no table of contents"
            )
        } else {
            EmptyStateView(
                title: "No Document",
                systemImage: "doc.text",
                description: "Open a PDF to see its outline"
            )
        }
    }
}

// MARK: - Outline Items
struct OutlineItems: View {
    @EnvironmentObject var viewModel: PDFEditorViewModel
    let outline: PDFOutline
    let level: Int

    var body: some View {
        ForEach(0..<outline.numberOfChildren, id: \.self) { i in
            if let child = outline.child(at: i) {
                OutlineRow(item: child, level: level)
                if child.numberOfChildren > 0 {
                    OutlineItems(outline: child, level: level + 1)
                }
            }
        }
    }
}

struct OutlineRow: View {
    @EnvironmentObject var viewModel: PDFEditorViewModel
    let item: PDFOutline
    let level: Int

    @State private var isHovered = false

    var body: some View {
        Button {
            if let dest = item.destination,
               let page = dest.page,
               let doc = viewModel.currentDocument {
                // index(for:) returns Int, not Int? — compare against NSNotFound
                let idx = doc.index(for: page)
                if idx != NSNotFound {
                    viewModel.goToPage(idx)
                }
            }
        } label: {
            HStack {
                if item.numberOfChildren > 0 {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Spacer().frame(width: 12)
                }
                Text(item.label ?? "—")
                    .font(.caption)
                    .lineLimit(2)
                Spacer()
            }
            .padding(.leading, CGFloat(level) * 12)
            .padding(.vertical, 3)
            .padding(.horizontal, 4)
            .background(isHovered ? Color.accentColor.opacity(0.1) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Empty State (replaces macOS 14-only ContentUnavailableView)
struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let description: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

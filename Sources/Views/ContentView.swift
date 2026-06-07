import SwiftUI
import PDFKit

struct ContentView: View {
    @EnvironmentObject var viewModel: PDFEditorViewModel

    var body: some View {
        NavigationSplitView(columnVisibility: sidebarVisibilityBinding) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 140, ideal: 180, max: 240)
        } detail: {
            ZStack {
                if viewModel.currentDocument != nil {
                    VStack(spacing: 0) {
                        AnnotationToolsView()
                        Divider()
                        // PDFViewer + overlays stacked together
                        ZStack {
                            PDFViewerView()
                            SelectionOverlayView()
                            TextBlockHighlightOverlay()
                        }
                    }
                } else {
                    WelcomeView()
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button(action: { viewModel.isSidebarVisible.toggle() }) {
                    Label("Toggle Sidebar", systemImage: "sidebar.left")
                }
            }

            ToolbarItemGroup(placement: .principal) {
                if viewModel.currentDocument != nil {
                    PageNavigationControls()
                }
            }

            ToolbarItemGroup(placement: .primaryAction) {
                if viewModel.currentDocument != nil {
                    ZoomControls()
                    Divider()
                    Button(action: viewModel.savePDF) {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                    .help("Save PDF")
                }
                Button(action: viewModel.openPDF) {
                    Label("Open", systemImage: "folder")
                }
                .help("Open PDF")
            }
        }
        .navigationTitle(viewModel.documentTitle + (viewModel.isModified ? " •" : ""))
        .sheet(isPresented: $viewModel.showMergeSheet) {
            MergeView()
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $viewModel.showSplitSheet) {
            SplitView()
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $viewModel.showGoToPageSheet) {
            GoToPageView()
                .environmentObject(viewModel)
        }
        .sheet(item: $viewModel.selectedTextBlock) { block in
            TextEditPopoverView(block: block)
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $viewModel.showAddTextSheet) {
            AddTextSheet()
                .environmentObject(viewModel)
        }
        .overlay(alignment: .bottom) {
            if !viewModel.statusMessage.isEmpty {
                StatusBar(message: viewModel.statusMessage)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut, value: viewModel.statusMessage)
                    .padding(.bottom, 4)
            }
        }
        .onOpenURL { url in
            if url.pathExtension.lowercased() == "pdf" {
                viewModel.loadPDF(from: url)
            }
        }
    }

    private var sidebarVisibilityBinding: Binding<NavigationSplitViewVisibility> {
        Binding(
            get: { viewModel.isSidebarVisible ? .all : .detailOnly },
            set: { viewModel.isSidebarVisible = ($0 != .detailOnly) }
        )
    }
}

// MARK: - Page Navigation Controls
struct PageNavigationControls: View {
    @EnvironmentObject var viewModel: PDFEditorViewModel

    var body: some View {
        HStack(spacing: 4) {
            Button(action: viewModel.goToPreviousPage) {
                Image(systemName: "chevron.left")
            }
            .disabled(viewModel.currentPageIndex <= 0)
            .buttonStyle(.borderless)

            Button {
                viewModel.showGoToPageSheet = true
            } label: {
                Text("\(viewModel.currentPageIndex + 1) / \(viewModel.totalPages)")
                    .font(.system(.body, design: .monospaced))
                    .frame(minWidth: 70)
            }
            .buttonStyle(.borderless)
            .help("Go to page…")

            Button(action: viewModel.goToNextPage) {
                Image(systemName: "chevron.right")
            }
            .disabled(viewModel.currentPageIndex >= viewModel.totalPages - 1)
            .buttonStyle(.borderless)
        }
    }
}

// MARK: - Zoom Controls
struct ZoomControls: View {
    @EnvironmentObject var viewModel: PDFEditorViewModel

    var body: some View {
        HStack(spacing: 2) {
            Button(action: viewModel.zoomOut) {
                Image(systemName: "minus.magnifyingglass")
            }
            .buttonStyle(.borderless)
            .help("Zoom Out")

            Text("\(Int(viewModel.scaleFactor * 100))%")
                .font(.system(.caption, design: .monospaced))
                .frame(minWidth: 44)

            Button(action: viewModel.zoomIn) {
                Image(systemName: "plus.magnifyingglass")
            }
            .buttonStyle(.borderless)
            .help("Zoom In")

            Button(action: viewModel.zoomToFit) {
                Image(systemName: "arrow.up.left.and.down.right.magnifyingglass")
            }
            .buttonStyle(.borderless)
            .help("Fit Page")
        }
    }
}

// MARK: - Status Bar
struct StatusBar: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.regularMaterial, in: Capsule())
            .shadow(radius: 4)
    }
}

// MARK: - Go To Page Sheet
struct GoToPageView: View {
    @EnvironmentObject var viewModel: PDFEditorViewModel
    @Environment(\.dismiss) var dismiss
    @State private var pageText = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 20) {
            Text("Go to Page")
                .font(.headline)

            HStack {
                TextField("Page number", text: $pageText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                    .focused($focused)
                    .onSubmit(go)

                Text("of \(viewModel.totalPages)")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
                Button("Go", action: go)
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 280)
        .onAppear {
            pageText = "\(viewModel.currentPageIndex + 1)"
            focused = true
        }
    }

    private func go() {
        if let num = Int(pageText), num >= 1, num <= viewModel.totalPages {
            viewModel.goToPage(num - 1)
        }
        dismiss()
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject var viewModel: PDFEditorViewModel

    var body: some View {
        Form {
            Section("Annotations") {
                Picker("Default Color", selection: $viewModel.annotationColor) {
                    ForEach([Color.yellow, .green, .blue, .pink, .orange], id: \.self) { color in
                        Label {
                            Text(color.description.capitalized)
                        } icon: {
                            Circle().fill(color).frame(width: 12, height: 12)
                        }
                        .tag(color)
                    }
                }
                Slider(value: $viewModel.annotationFontSize, in: 8...48, step: 1) {
                    Text("Font Size: \(Int(viewModel.annotationFontSize))pt")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 360)
        .padding()
    }
}

import SwiftUI
import PDFKit

// MARK: - TextEditPopoverView
/// Sheet that pops up when the user clicks a text block in "Edit Text" mode.
struct TextEditPopoverView: View {
    @EnvironmentObject var viewModel: PDFEditorViewModel
    @Environment(\.dismiss) var dismiss

    let block: TextBlock

    @State private var editedText: String
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @FocusState private var editorFocused: Bool

    init(block: TextBlock) {
        self.block = block
        _editedText = State(initialValue: block.text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "pencil.and.outline")
                    .foregroundColor(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Edit Text")
                        .font(.headline)
                    Text("Page \(block.pageIndex + 1) · \(String(format: "%.0f", block.fontSize))pt")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Original text (read-only reference)
            VStack(alignment: .leading, spacing: 4) {
                Text("Original")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(block.text)
                    .font(.system(size: min(block.fontSize, 13)))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .foregroundColor(.secondary)
            }

            // Editable text
            VStack(alignment: .leading, spacing: 4) {
                Text("New Text")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextEditor(text: $editedText)
                    .font(.system(size: min(block.fontSize, 13)))
                    .frame(minHeight: 80, maxHeight: 200)
                    .padding(4)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
                    )
                    .focused($editorFocused)
            }

            // Error
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(Color.red)
            }

            // Footer
            HStack {
                Button("Revert") { editedText = block.text }
                    .buttonStyle(.bordered)
                    .disabled(editedText == block.text)

                Spacer()

                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)

                Button {
                    applyEdit()
                } label: {
                    if isProcessing {
                        HStack(spacing: 6) {
                            ProgressView().scaleEffect(0.7)
                            Text("Applying…")
                        }
                    } else {
                        Text("Apply")
                    }
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.borderedProminent)
                .disabled(editedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                          || editedText == block.text
                          || isProcessing)
            }
        }
        .padding(20)
        .frame(width: 440)
        .onAppear { editorFocused = true }
    }

    private func applyEdit() {
        isProcessing = true
        errorMessage = nil

        Task {
            let result = await viewModel.applyTextEdit(block: block, newText: editedText)
            await MainActor.run {
                isProcessing = false
                if result {
                    dismiss()
                } else {
                    errorMessage = "Could not apply edit. The text may use an embedded font that prevents modification."
                }
            }
        }
    }
}

// MARK: - TextBlockHighlightOverlay
/// Transparent SwiftUI overlay drawn on top of PDFViewerView.
/// Shows blue outlines around detected text blocks in "Edit Text" mode.
struct TextBlockHighlightOverlay: View {
    @EnvironmentObject var viewModel: PDFEditorViewModel

    /// Converts a PDF-space rect to the PDFView's coordinate space.
    /// Call from the view's geometry context.
    var body: some View {
        GeometryReader { geo in
            ZStack {
                if viewModel.selectedTool == .editExistingText,
                   let pdfView = viewModel.pdfView,
                   let page = pdfView.currentPage {
                    ForEach(viewModel.textEditEngine.textBlocks) { block in
                        let viewRect = pdfView.convert(block.bounds, from: page)

                        // Flip Y: PDFView's NSView origin is bottom-left,
                        // SwiftUI overlay origin is top-left.
                        let flippedY = geo.size.height - viewRect.maxY
                        let swiftRect = CGRect(x: viewRect.minX,
                                               y: flippedY,
                                               width: viewRect.width,
                                               height: viewRect.height)

                        Rectangle()
                            .stroke(Color.blue.opacity(0.6), lineWidth: 1.5)
                            .background(Color.blue.opacity(0.04))
                            .frame(width: swiftRect.width, height: swiftRect.height)
                            .position(x: swiftRect.midX, y: swiftRect.midY)
                            .onTapGesture {
                                viewModel.selectedTextBlock = block
                            }
                    }
                }
            }
        }
        .allowsHitTesting(viewModel.selectedTool == .editExistingText)
    }
}

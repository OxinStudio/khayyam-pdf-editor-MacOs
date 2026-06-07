import SwiftUI
import PDFKit

// MARK: - Annotation Tools Toolbar
struct AnnotationToolsView: View {
    @EnvironmentObject var viewModel: PDFEditorViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {

                // ── Group 1: Navigate ──────────────────────────────────────
                ToolGroupLabel("Navigate")
                ToolBtn(.select)
                ToolBtn(.hand)

                GroupDivider()

                // ── Group 2: Comment ───────────────────────────────────────
                ToolGroupLabel("Comment")
                ToolBtn(.stickyNote)
                MarkupToolButton(tool: .highlight,     color: $viewModel.highlightColor)
                MarkupToolButton(tool: .underline,     color: $viewModel.underlineColor)
                MarkupToolButton(tool: .strikethrough, color: $viewModel.strikethroughColor)

                GroupDivider()

                // ── Group 3: Drawing ───────────────────────────────────────
                ToolGroupLabel("Draw")
                ToolBtn(.ink)
                DrawToolBtn(.rectangle)
                DrawToolBtn(.oval)
                DrawToolBtn(.line)

                GroupDivider()

                // ── Group 4: Text ──────────────────────────────────────────
                ToolGroupLabel("Text")
                ToolBtn(.typewriter)
                ToolBtn(.editExistingText)

                GroupDivider()

                // ── Group 5: Insert ────────────────────────────────────────
                ToolGroupLabel("Insert")
                ToolBtn(.insertImage)

                // ── Draw color (for drawing tools, no annotation selected) ──
                if [AnnotationTool.ink, .rectangle, .oval, .line].contains(viewModel.selectedTool),
                   viewModel.selectedAnnotation == nil {
                    Divider().frame(height: 28)
                    HStack(spacing: 4) {
                        Text("Stroke:").font(.caption).foregroundColor(.secondary)
                        ColorPicker("", selection: $viewModel.annotationColor)
                            .labelsHidden().frame(width: 28, height: 28)
                    }
                    .padding(.horizontal, 6)
                }

                Spacer()

                // ── Shape properties (shown when a shape is selected) ───────
                if viewModel.selectedAnnotation != nil {
                    Divider().frame(height: 28)
                    ShapePropertiesPanel()
                }

                // ── Page count ─────────────────────────────────────────────
                if let doc = viewModel.currentDocument {
                    Divider().frame(height: 28)
                    Text("\(doc.pageCount) page\(doc.pageCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.trailing, 8)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

// MARK: - Supporting Layout Views

private struct ToolGroupLabel: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 8, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.leading, 4)
    }
}

private struct GroupDivider: View {
    var body: some View {
        Divider().frame(height: 32).padding(.horizontal, 4)
    }
}

// MARK: - Standard Tool Button
struct ToolBtn: View {
    @EnvironmentObject var viewModel: PDFEditorViewModel
    let tool: AnnotationTool

    init(_ tool: AnnotationTool) { self.tool = tool }

    var isSelected: Bool { viewModel.selectedTool == tool }

    var body: some View {
        Button {
            viewModel.selectedTool = isSelected ? .select : tool
        } label: {
            VStack(spacing: 2) {
                Image(systemName: tool.sfSymbol)
                    .font(.system(size: 15))
                    .frame(width: 22, height: 22)
                Text(tool.displayName)
                    .font(.system(size: 8.5))
                    .lineLimit(1)
            }
            .frame(width: 50)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .help(toolTip(for: tool))
    }

    private func toolTip(for tool: AnnotationTool) -> String {
        switch tool {
        case .select:           return "Select & Move annotations"
        case .hand:             return "Pan / scroll the document"
        case .stickyNote:       return "Add a sticky note — click to place, double-click to edit"
        case .typewriter:       return "Typewriter — click to add text directly on the page"
        case .editExistingText: return "Edit existing PDF text (MuPDF)"
        case .ink:              return "Freehand drawing"
        case .rectangle:        return "Rectangle shape"
        case .oval:             return "Oval / circle shape"
        case .line:             return "Draw a line (click start, click end)"
        case .insertImage:      return "Insert an image from file"
        default:                return tool.displayName
        }
    }
}

// MARK: - Drawing Tool Button (with color swatch)
struct DrawToolBtn: View {
    @EnvironmentObject var viewModel: PDFEditorViewModel
    let tool: AnnotationTool

    init(_ tool: AnnotationTool) { self.tool = tool }

    var isSelected: Bool { viewModel.selectedTool == tool }

    var body: some View {
        Button {
            viewModel.selectedTool = isSelected ? .select : tool
        } label: {
            VStack(spacing: 2) {
                Image(systemName: tool.sfSymbol)
                    .font(.system(size: 15))
                    .frame(width: 22, height: 22)
                Text(tool.displayName)
                    .font(.system(size: 8.5))
                    .lineLimit(1)
                // Color swatch strip
                RoundedRectangle(cornerRadius: 2)
                    .fill(viewModel.annotationColor)
                    .frame(width: 22, height: 3)
            }
            .frame(width: 50)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .help(tool.displayName)
    }
}

// MARK: - Markup Tool Button (highlight/underline/strikethrough)
struct MarkupToolButton: View {
    @EnvironmentObject var viewModel: PDFEditorViewModel
    let tool: AnnotationTool
    @Binding var color: Color
    @State private var showColorPicker = false

    var body: some View {
        HStack(spacing: 0) {
            // Apply button
            Button { viewModel.applyMarkup(tool) } label: {
                VStack(spacing: 2) {
                    Image(systemName: tool.sfSymbol)
                        .font(.system(size: 15))
                        .frame(width: 22, height: 22)
                    Text(tool.displayName)
                        .font(.system(size: 8.5))
                        .lineLimit(1)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: 22, height: 3)
                }
                .padding(.vertical, 4)
                .padding(.leading, 6)
            }
            .buttonStyle(.plain)
            .help("\(tool.displayName) — select text then click · or select text and drag, then click")

            // Color picker chevron
            Button { showColorPicker.toggle() } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 12, height: 34)
            }
            .buttonStyle(.plain)
            .help("Change \(tool.displayName) color")
            .popover(isPresented: $showColorPicker, arrowEdge: .bottom) {
                MarkupColorPicker(tool: tool, color: $color)
                    .environmentObject(viewModel)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
        )
        .padding(.horizontal, 1)
    }
}

// MARK: - Markup Color Picker Popover
struct MarkupColorPicker: View {
    @EnvironmentObject var viewModel: PDFEditorViewModel
    let tool: AnnotationTool
    @Binding var color: Color
    @Environment(\.dismiss) var dismiss

    private let presets: [(String, Color)] = [
        ("Yellow", .yellow), ("Green", .green),  ("Blue",   .blue),
        ("Pink",   .pink),   ("Orange", .orange), ("Purple", .purple),
        ("Red",    .red),    ("Cyan",   .cyan),   ("White",  .white)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(tool.displayName) Color")
                .font(.caption.bold())
                .foregroundColor(.secondary)

            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(32), spacing: 6), count: 5),
                spacing: 6
            ) {
                ForEach(presets, id: \.0) { name, preset in
                    Circle()
                        .fill(preset)
                        .frame(width: 28, height: 28)
                        .overlay(Circle().stroke(Color.primary.opacity(0.15), lineWidth: 0.5))
                        .overlay(Circle().stroke(Color.primary, lineWidth: 2).opacity(color == preset ? 1 : 0))
                        .onTapGesture { color = preset; dismiss() }
                        .help(name)
                }
            }

            Divider()

            HStack {
                Text("Custom:").font(.caption).foregroundColor(.secondary)
                ColorPicker("", selection: $color).labelsHidden()
            }
        }
        .padding(14)
        .frame(width: 210)
    }
}

// MARK: - ToolTipOverlay (used by PDFViewerView)
struct ToolTipOverlay: View {
    let tool: AnnotationTool

    var tip: String? {
        switch tool {
        case .select:           return nil
        case .hand:             return "Click and drag to scroll"
        case .stickyNote:       return "Click to place a sticky note · double-click to edit"
        case .highlight:        return "Select text, then click Highlight in toolbar"
        case .underline:        return "Select text, then click Underline in toolbar"
        case .strikethrough:    return "Select text, then click Strikethrough in toolbar"
        case .ink:              return "Click and drag to draw"
        case .rectangle:        return "Click to place a rectangle"
        case .oval:             return "Click to place an oval"
        case .line:             return "Click start point, then click end point"
        case .typewriter:       return "Click anywhere to type text"
        case .editExistingText: return "Click any text block to edit it"
        case .insertImage:      return "Click to insert an image"
        }
    }

    var body: some View {
        if let tip {
            Text(tip)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.bottom, 12)
        }
    }
}

// MARK: - Shape Properties Panel
/// Appears in the toolbar whenever an annotation is selected.
/// Lets the user change stroke color, stroke width, fill, and delete.
struct ShapePropertiesPanel: View {
    @EnvironmentObject var viewModel: PDFEditorViewModel

    var body: some View {
        HStack(spacing: 8) {

            Text("Selection:")
                .font(.caption)
                .foregroundColor(.secondary)

            // ── Stroke color ──────────────────────────────────────────────
            HStack(spacing: 3) {
                Text("Stroke").font(.system(size: 9)).foregroundColor(.secondary)
                ColorPicker("", selection: $viewModel.shapeStrokeColor)
                    .labelsHidden()
                    .frame(width: 28, height: 28)
                    .onChange(of: viewModel.shapeStrokeColor) { _ in viewModel.applyShapeProperties() }
            }

            // ── Stroke width ──────────────────────────────────────────────
            HStack(spacing: 3) {
                Text("Width").font(.system(size: 9)).foregroundColor(.secondary)
                Button { viewModel.shapeStrokeWidth = max(0.5, viewModel.shapeStrokeWidth - 0.5)
                    viewModel.applyShapeProperties() } label: {
                    Image(systemName: "minus").font(.system(size: 9))
                }
                .buttonStyle(.borderless)

                Text(String(format: "%.1f", viewModel.shapeStrokeWidth))
                    .font(.system(size: 10, design: .monospaced))
                    .frame(minWidth: 28)

                Button { viewModel.shapeStrokeWidth = min(20, viewModel.shapeStrokeWidth + 0.5)
                    viewModel.applyShapeProperties() } label: {
                    Image(systemName: "plus").font(.system(size: 9))
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 5))

            // ── Fill ──────────────────────────────────────────────────────
            if viewModel.selectedAnnotationIsShape {
                HStack(spacing: 3) {
                    Toggle("Fill", isOn: $viewModel.shapeHasFill)
                        .toggleStyle(.checkbox)
                        .font(.system(size: 9))
                        .onChange(of: viewModel.shapeHasFill) { _ in viewModel.applyShapeProperties() }
                    if viewModel.shapeHasFill {
                        ColorPicker("", selection: $viewModel.shapeFillColor)
                            .labelsHidden()
                            .frame(width: 28, height: 28)
                            .onChange(of: viewModel.shapeFillColor) { _ in viewModel.applyShapeProperties() }
                    }
                }
            }

            Divider().frame(height: 24)

            // ── Delete ────────────────────────────────────────────────────
            Button(action: viewModel.deleteSelectedAnnotation) {
                Label("Delete", systemImage: "trash")
                    .font(.system(size: 11))
                    .foregroundColor(Color.red)
            }
            .buttonStyle(.borderless)
            .help("Delete selected annotation (⌫)")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor.opacity(0.07))
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor.opacity(0.2), lineWidth: 1))
        )
    }
}

import SwiftUI
import PDFKit
import AppKit

// MARK: - AddTextSheet
struct AddTextSheet: View {
    @EnvironmentObject var viewModel: PDFEditorViewModel
    @Environment(\.dismiss) var dismiss

    // MARK: - Text content
    @State private var text: String = ""
    @FocusState private var textFocused: Bool

    // MARK: - Font options
    @State private var fontFamily: String = "Helvetica"
    @State private var fontSize: CGFloat = 14
    @State private var isBold: Bool = false
    @State private var isItalic: Bool = false
    @State private var textColor: Color = .black
    @State private var bgColor: Color = Color.clear
    @State private var useBg: Bool = false
    @State private var alignment: NSTextAlignment = .left

    // MARK: - Common font families (curated)
    private let fontFamilies: [String] = [
        "Helvetica", "Helvetica Neue", "Arial",
        "Times New Roman", "Georgia", "Garamond",
        "Courier New", "Courier",
        "Futura", "Optima", "Palatino",
        "Gill Sans", "Trebuchet MS", "Verdana",
        "System Font"
    ]

    private var previewFont: Font {
        var f = Font.custom(fontFamily == "System Font" ? ".AppleSystemUIFont" : fontFamily,
                            size: min(fontSize, 18))
        if isBold   { f = f.bold() }
        if isItalic { f = f.italic() }
        return f
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Header ──────────────────────────────────────────────────────
            HStack {
                Image(systemName: "text.cursor")
                    .foregroundColor(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add Text")
                        .font(.headline)
                    Text("Type your text and choose formatting below")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // ── Text input ───────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Text Content")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextEditor(text: $text)
                            .font(previewFont)
                            .foregroundColor(textColor)
                            .frame(minHeight: 90, maxHeight: 160)
                            .padding(8)
                            .background(useBg ? bgColor.opacity(0.2) : Color(nsColor: .textBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.accentColor.opacity(0.5), lineWidth: 1))
                            .focused($textFocused)
                    }

                    // ── Font family ──────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Font")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("Font", selection: $fontFamily) {
                            ForEach(fontFamilies, id: \.self) { family in
                                Text(family)
                                    .font(.custom(family == "System Font" ? ".AppleSystemUIFont" : family, size: 13))
                                    .tag(family)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // ── Size & style ─────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Size & Style")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack(spacing: 12) {
                            // Size stepper
                            HStack(spacing: 4) {
                                Button { fontSize = max(6, fontSize - 1) } label: {
                                    Image(systemName: "minus").frame(width: 20)
                                }
                                .buttonStyle(.bordered)

                                Text("\(Int(fontSize))pt")
                                    .font(.system(.body, design: .monospaced))
                                    .frame(minWidth: 44)
                                    .multilineTextAlignment(.center)

                                Button { fontSize = min(144, fontSize + 1) } label: {
                                    Image(systemName: "plus").frame(width: 20)
                                }
                                .buttonStyle(.bordered)
                            }

                            Divider().frame(height: 24)

                            // Bold / Italic toggles
                            Button {
                                isBold.toggle()
                            } label: {
                                Image(systemName: "bold")
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(ToggleButtonStyle(isOn: isBold))
                            .help("Bold")

                            Button {
                                isItalic.toggle()
                            } label: {
                                Image(systemName: "italic")
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(ToggleButtonStyle(isOn: isItalic))
                            .help("Italic")

                            Spacer()

                            // Quick size presets
                            ForEach([10, 12, 14, 18, 24, 36], id: \.self) { size in
                                Button("\(size)") {
                                    fontSize = CGFloat(size)
                                }
                                .buttonStyle(SizePresetStyle(isSelected: Int(fontSize) == size))
                            }
                        }

                        // Slider
                        HStack {
                            Text("6").font(.caption2).foregroundColor(.secondary)
                            Slider(value: $fontSize, in: 6...144, step: 1)
                            Text("144").font(.caption2).foregroundColor(.secondary)
                        }
                    }

                    // ── Color & alignment ────────────────────────────────────
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Color & Alignment")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack(spacing: 12) {
                            // Text color
                            HStack(spacing: 6) {
                                Text("Text:").font(.caption)
                                ColorPicker("", selection: $textColor)
                                    .labelsHidden()
                                    .frame(width: 32, height: 28)
                            }

                            Divider().frame(height: 24)

                            // Background color
                            HStack(spacing: 6) {
                                Toggle("", isOn: $useBg).labelsHidden()
                                Text("Background:").font(.caption)
                                ColorPicker("", selection: $bgColor)
                                    .labelsHidden()
                                    .frame(width: 32, height: 28)
                                    .disabled(!useBg)
                                    .opacity(useBg ? 1 : 0.4)
                            }

                            Spacer()

                            // Alignment
                            Picker("Alignment", selection: $alignment) {
                                Image(systemName: "text.alignleft").tag(NSTextAlignment.left)
                                Image(systemName: "text.aligncenter").tag(NSTextAlignment.center)
                                Image(systemName: "text.alignright").tag(NSTextAlignment.right)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 100)
                            .labelsHidden()
                        }
                    }

                    // ── Preview ──────────────────────────────────────────────
                    if !text.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Preview")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(text)
                                .font(previewFont)
                                .foregroundColor(textColor)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: alignmentFromNS)
                                .background(useBg ? bgColor : Color(nsColor: .controlBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                        }
                    }
                }
                .padding()
            }

            Divider()

            // ── Footer ───────────────────────────────────────────────────────
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
                Button("Place Text") { place() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .frame(width: 480, height: 600)
        .onAppear { textFocused = true }
    }

    // MARK: - Place annotation

    private func place() {
        guard let page = viewModel.pendingTextPage,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let resolvedFont = makeFont()
        let bgNSColor = useBg ? NSColor(bgColor) : NSColor.clear
        let textNSColor = NSColor(textColor)

        let location = viewModel.pendingTextLocation
        let lineHeight = resolvedFont.pointSize * 1.4
        let estimatedLines = max(1, text.components(separatedBy: "\n").count)
        let height = max(lineHeight * CGFloat(estimatedLines) + 16, 40)
        let width: CGFloat = max(120, min(400, CGFloat(text.count) * resolvedFont.pointSize * 0.6 + 24))

        let bounds = CGRect(
            x: location.x,
            y: location.y - height,
            width: width,
            height: height
        )

        viewModel.addFreeTextAnnotation(
            at: bounds,
            on: page,
            text: text,
            font: resolvedFont,
            textColor: textNSColor,
            bgColor: bgNSColor,
            alignment: alignment
        )
        dismiss()
    }

    private func makeFont() -> NSFont {
        let family = fontFamily == "System Font" ? nil : fontFamily
        var traits: NSFontTraitMask = []
        if isBold   { traits.insert(.boldFontMask) }
        if isItalic { traits.insert(.italicFontMask) }

        if let family {
            if let f = NSFontManager.shared.font(withFamily: family,
                                                  traits: traits,
                                                  weight: 5,
                                                  size: fontSize) { return f }
            if let f = NSFont(name: family, size: fontSize) { return f }
        }

        return isBold
            ? NSFont.boldSystemFont(ofSize: fontSize)
            : NSFont.systemFont(ofSize: fontSize)
    }

    private var alignmentFromNS: Alignment {
        switch alignment {
        case .center: return .center
        case .right:  return .trailing
        default:      return .leading
        }
    }
}

// MARK: - Custom Button Styles

struct ToggleButtonStyle: ButtonStyle {
    let isOn: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(4)
            .background(isOn ? Color.accentColor : Color(nsColor: .controlBackgroundColor),
                        in: RoundedRectangle(cornerRadius: 5))
            .foregroundColor(isOn ? .white : .primary)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}

struct SizePresetStyle: ButtonStyle {
    let isSelected: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(isSelected ? Color.accentColor : Color(nsColor: .controlBackgroundColor),
                        in: RoundedRectangle(cornerRadius: 4))
            .foregroundColor(isSelected ? .white : .secondary)
    }
}

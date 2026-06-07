import SwiftUI

// MARK: - HelpView
struct HelpView: View {

    @State private var selectedSection: HelpSection = .gettingStarted

    var body: some View {
        NavigationSplitView {
            List(HelpSection.allCases, id: \.self, selection: $selectedSection) { section in
                Label(section.title, systemImage: section.icon)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            .listStyle(.sidebar)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    selectedSection.content
                        .padding(32)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .navigationTitle("Khayyam PDF Editor Help")
        .frame(minWidth: 720, minHeight: 520)
    }
}

// MARK: - Help Section enum

enum HelpSection: String, CaseIterable {
    case gettingStarted
    case interface
    case annotationTools
    case textEditing
    case mergeSplit
    case savingExporting
    case keyboardShortcuts
    case about

    var title: String {
        switch self {
        case .gettingStarted:   return "Getting Started"
        case .interface:        return "Interface Overview"
        case .annotationTools:  return "Annotation Tools"
        case .textEditing:      return "Editing Text"
        case .mergeSplit:       return "Merge & Split"
        case .savingExporting:  return "Saving & Exporting"
        case .keyboardShortcuts: return "Keyboard Shortcuts"
        case .about:            return "About"
        }
    }

    var icon: String {
        switch self {
        case .gettingStarted:   return "star.fill"
        case .interface:        return "rectangle.3.group"
        case .annotationTools:  return "pencil.tip"
        case .textEditing:      return "pencil.and.outline"
        case .mergeSplit:       return "arrow.triangle.merge"
        case .savingExporting:  return "square.and.arrow.down"
        case .keyboardShortcuts: return "keyboard"
        case .about:            return "info.circle"
        }
    }

    @ViewBuilder
    var content: some View {
        switch self {
        case .gettingStarted:   GettingStartedContent()
        case .interface:        InterfaceContent()
        case .annotationTools:  AnnotationToolsContent()
        case .textEditing:      TextEditingContent()
        case .mergeSplit:       MergeSplitContent()
        case .savingExporting:  SavingContent()
        case .keyboardShortcuts: ShortcutsContent()
        case .about:            AboutContent()
        }
    }
}

// MARK: - Shared Layout Helpers

private struct SectionHeader: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.largeTitle.bold())
            }
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 24)
    }
}

private struct HelpBlock: View {
    let title: String
    let text: String
    var icon: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let icon {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: icon)
                        .foregroundColor(.accentColor)
                        .frame(width: 20)
                    Text(title).font(.headline)
                }
            } else {
                Text(title).font(.headline)
            }
            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct ShortcutRow: View {
    let key: String
    let description: String

    var body: some View {
        HStack {
            Text(description)
                .font(.body)
            Spacer()
            Text(key)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
        }
        Divider()
    }
}

// MARK: - Section Content Views

private struct GettingStartedContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                icon: "star.fill",
                title: "Getting Started",
                subtitle: "Everything you need to open and start working with PDFs."
            )

            HelpBlock(
                title: "Opening a PDF",
                text: "Use File › Open PDF… (⌘O), drag and drop a PDF file onto the welcome screen, or double-click any PDF file in Finder that is associated with Khayyam PDF Editor.",
                icon: "folder.badge.plus"
            )

            HelpBlock(
                title: "Opening from Finder",
                text: "Right-click a PDF in Finder, choose Open With, and select Khayyam PDF Editor. You can set it as the default PDF app in Finder's Get Info panel.",
                icon: "doc.badge.arrow.up"
            )

            HelpBlock(
                title: "Your first annotation",
                text: "Once a PDF is open, pick any tool from the toolbar at the top — for example Highlight. Select text in the document by clicking and dragging, then click the Highlight button. That's it.",
                icon: "highlighter"
            )

            HelpBlock(
                title: "Saving your work",
                text: "Press ⌘S to save back to the original file. A bullet (•) in the window title indicates unsaved changes. Use ⌘⇧S to save to a new location.",
                icon: "square.and.arrow.down"
            )
        }
    }
}

private struct InterfaceContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                icon: "rectangle.3.group",
                title: "Interface Overview",
                subtitle: "A quick tour of the three main areas."
            )

            HelpBlock(
                title: "Sidebar (left panel)",
                text: "Switch between Thumbnails and Outline using the segmented control at the top.\n\n• Thumbnails — click any page thumbnail to jump to it. The current page is highlighted with an accent border.\n• Outline — shows the PDF's table of contents if it has one. Click an entry to jump to that section.\n• Search — type in the search bar above the thumbnails to find text across the whole document. Use the up/down chevrons to step through results.",
                icon: "sidebar.left"
            )

            HelpBlock(
                title: "Toolbar (top bar)",
                text: "Contains the annotation tools grouped into Navigate, Comment, Draw, Text, and Insert. The active tool is highlighted. Click a selected tool again to return to Select mode.\n\nWhen an annotation is selected, a properties panel appears on the right side of the toolbar — use it to change stroke color, stroke width, fill, or delete the annotation.",
                icon: "rectangle.topthird.inset.filled"
            )

            HelpBlock(
                title: "PDF Viewer (center)",
                text: "The main editing area. Scroll to browse pages. Use the zoom controls in the window toolbar (⌘+ / ⌘−), or pinch on a trackpad.\n\nThe page counter at the top center shows your current page. Click it to type a page number and jump directly.",
                icon: "doc.richtext"
            )

            HelpBlock(
                title: "Status bar",
                text: "A floating pill at the bottom of the viewer shows contextual hints — for example, when you activate the Line tool it reminds you to click a second point to finish the line. Hints disappear automatically after a few seconds.",
                icon: "info.circle"
            )
        }
    }
}

private struct AnnotationToolsContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                icon: "pencil.tip",
                title: "Annotation Tools",
                subtitle: "All the ways to mark up a PDF."
            )

            Group {
                HelpBlock(
                    title: "Select",
                    text: "Click an annotation to select it. A dashed blue border with 8 white handles appears around it.\n\n• Drag the annotation body to move it.\n• Drag any of the 8 handles to resize it.\n• Change stroke color, width, and fill from the toolbar panel that appears.\n• Press ⌫ (Delete) to remove the selected annotation.",
                    icon: "cursorarrow"
                )

                HelpBlock(
                    title: "Hand",
                    text: "Switches the viewer into pan mode. Click and drag to scroll through the document without accidentally creating or selecting annotations.",
                    icon: "hand.raised"
                )
            }

            Group {
                HelpBlock(
                    title: "Note (Sticky Note)",
                    text: "Click anywhere on the page to drop a sticky note icon. Double-click the icon to open the inline editor and type your note. The note text is saved with the PDF.",
                    icon: "note.text"
                )

                HelpBlock(
                    title: "Highlight / Underline / Strikethrough",
                    text: "These are text markup tools. Select text first by clicking and dragging in the PDF, then click the Highlight (or Underline / Strikethrough) button in the toolbar.\n\nYou can also select text, drag to extend the selection, release, and then click the toolbar button.\n\nChange the color by clicking the small chevron (▾) next to each button and picking from the presets or using the custom color picker.",
                    icon: "highlighter"
                )
            }

            Group {
                HelpBlock(
                    title: "Draw (Ink)",
                    text: "Click and drag to draw freehand lines. The stroke uses the current annotation color shown in the toolbar. Switch to Select mode afterward to move or resize the ink stroke.",
                    icon: "pencil.tip"
                )

                HelpBlock(
                    title: "Rectangle & Oval",
                    text: "Click anywhere on the page to place a shape at a default size. Then switch to Select mode to resize it using the 8 handles, move it, and change its stroke color, stroke width, and fill color from the toolbar panel.",
                    icon: "rectangle"
                )

                HelpBlock(
                    title: "Line",
                    text: "Two-click workflow: click once to set the start point (a status hint appears), then click again to set the end point. The line is drawn between the two clicks. Switch to Select to move or adjust it.",
                    icon: "line.diagonal"
                )
            }

            Group {
                HelpBlock(
                    title: "Typewriter",
                    text: "Click on a blank area of the page to open the Add Text sheet. Type your text, choose font family, size, bold/italic, color, background, and alignment. Click Place Text to add it to the page as a free-text annotation.\n\nSwitch to Select afterward to reposition or resize the text box.",
                    icon: "text.cursor"
                )

                HelpBlock(
                    title: "Edit Text (MuPDF)",
                    text: "Uses the MuPDF engine to detect existing text blocks in the PDF. When active, blue outlines appear around every text block. Click a block to open the Edit Text sheet, type the replacement text, and click Apply.\n\nThe original text is covered with a white rectangle and the new text is placed over it as a free-text annotation. This works on most PDFs; PDFs with heavily embedded or encoded fonts may not support editing.",
                    icon: "pencil.and.outline"
                )

                HelpBlock(
                    title: "Insert Image",
                    text: "Click anywhere on the page to open a file picker. Choose a PNG, JPEG, or TIFF image file. The image is inserted centered on the page at a reasonable default size. Switch to Select to move and resize it.",
                    icon: "photo"
                )
            }
        }
    }
}

private struct TextEditingContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                icon: "pencil.and.outline",
                title: "Editing Text",
                subtitle: "How to modify existing PDF text using the MuPDF engine."
            )

            HelpBlock(
                title: "How it works",
                text: "Khayyam PDF Editor uses the open-source MuPDF library to parse the internal structure of a PDF and identify individual text blocks (paragraphs). This is separate from PDFKit's text selection, which only works at the display level.",
                icon: "doc.text.magnifyingglass"
            )

            HelpBlock(
                title: "Step-by-step",
                text: "1. Open a PDF.\n2. Select the Edit Text tool (pencil icon in the Text group).\n3. Blue outlines appear around every detected text block on the current page.\n4. Click any outlined block — the Edit Text sheet opens showing the original text.\n5. Type your replacement text in the New Text field.\n6. Click Apply (⌘↩).\n\nThe original text is hidden under a white rectangle and the new text is rendered on top.",
                icon: "list.number"
            )

            HelpBlock(
                title: "Limitations",
                text: "• The replacement text uses a system font, so the visual appearance may differ from the original if the PDF uses a custom embedded font.\n• Text editing is page-by-page — navigate to each page to edit blocks there.\n• Scanned PDFs (image-only, no text layer) cannot be edited this way; use the Typewriter tool to overlay text instead.",
                icon: "exclamationmark.triangle"
            )

            HelpBlock(
                title: "Saving edited text",
                text: "After applying edits, save the document with ⌘S. The edits are stored as annotation overlays — they are visible in all standard PDF viewers.",
                icon: "square.and.arrow.down"
            )
        }
    }
}

private struct MergeSplitContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                icon: "arrow.triangle.merge",
                title: "Merge & Split",
                subtitle: "Combine multiple PDFs or break one into parts."
            )

            HelpBlock(
                title: "Merging PDFs",
                text: "Open the Merge sheet from PDF › Merge PDFs… (⌘⇧M) or the Welcome screen button.\n\n1. Click Add PDFs… or drag PDF files into the list.\n2. Reorder files by dragging them up or down in the list.\n3. Remove unwanted files with the red minus button.\n4. Click Merge & Save… to combine them and save to a new file.",
                icon: "arrow.triangle.merge"
            )

            HelpBlock(
                title: "Splitting — Every N Pages",
                text: "Open PDF › Split PDF… with a document open. Choose Every N Pages and set the number of pages per part. For example, 1 creates one file per page. Click Split & Save… and choose a folder — files are saved as Document – Part 1.pdf, Document – Part 2.pdf, etc.",
                icon: "scissors"
            )

            HelpBlock(
                title: "Splitting — At Specific Pages",
                text: "Choose At Specific Pages and enter page numbers separated by commas (e.g., 3, 7, 12). Each number starts a new document at that page. Page 1–2 becomes part 1, page 3–6 part 2, and so on.",
                icon: "text.badge.plus"
            )

            HelpBlock(
                title: "Extract Range",
                text: "Choose Extract Range and enter a start and end page number. A single PDF containing just those pages is saved to the location you choose.",
                icon: "doc.on.doc"
            )
        }
    }
}

private struct SavingContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                icon: "square.and.arrow.down",
                title: "Saving & Exporting",
                subtitle: "How to save your work and share PDFs."
            )

            HelpBlock(
                title: "Save (⌘S)",
                text: "Writes the document back to its original file. If the document has never been saved (e.g., a merged result), it falls back to Save As.",
                icon: "square.and.arrow.down"
            )

            HelpBlock(
                title: "Save As… (⌘⇧S)",
                text: "Opens a save panel so you can choose a new name and location. The original file is left unchanged.",
                icon: "square.and.arrow.down.on.square"
            )

            HelpBlock(
                title: "Export as PDF…",
                text: "Equivalent to Save As — opens the same save panel. Useful to remember that Khayyam PDF Editor always saves in PDF format.",
                icon: "arrow.up.doc"
            )

            HelpBlock(
                title: "Unsaved changes indicator",
                text: "A bullet point (•) appears after the document title in the window title bar whenever there are unsaved changes. It disappears immediately after you save.",
                icon: "pencil.circle"
            )

            HelpBlock(
                title: "What gets saved",
                text: "All annotations — highlights, notes, shapes, typewriter text, images, and text edits — are embedded in the PDF as standard annotations. They are visible in Preview, Adobe Acrobat, and any other PDF viewer.",
                icon: "checkmark.seal"
            )
        }
    }
}

private struct ShortcutsContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                icon: "keyboard",
                title: "Keyboard Shortcuts",
                subtitle: "All shortcuts at a glance."
            )

            Group {
                Text("File").font(.headline).padding(.top, 4)
                ShortcutRow(key: "⌘ O", description: "Open PDF…")
                ShortcutRow(key: "⌘ S", description: "Save")
                ShortcutRow(key: "⌘ ⇧ S", description: "Save As…")
                ShortcutRow(key: "⌘ ⇧ M", description: "Merge PDFs…")
            }

            Group {
                Text("Navigation").font(.headline).padding(.top, 4)
                ShortcutRow(key: "⌘ ←", description: "Previous Page")
                ShortcutRow(key: "⌘ →", description: "Next Page")
                ShortcutRow(key: "⌘ ↖", description: "First Page")
                ShortcutRow(key: "⌘ ↘", description: "Last Page")
            }

            Group {
                Text("View").font(.headline).padding(.top, 4)
                ShortcutRow(key: "⌘ +", description: "Zoom In")
                ShortcutRow(key: "⌘ −", description: "Zoom Out")
                ShortcutRow(key: "⌘ 0", description: "Actual Size (100%)")
                ShortcutRow(key: "⌘ 9", description: "Fit Page")
            }

            Group {
                Text("Editing").font(.headline).padding(.top, 4)
                ShortcutRow(key: "⌫", description: "Delete Selected Annotation")
                ShortcutRow(key: "⌘ [", description: "Rotate Page Left")
                ShortcutRow(key: "⌘ ]", description: "Rotate Page Right")
            }

            Group {
                Text("Text Edit Sheet").font(.headline).padding(.top, 4)
                ShortcutRow(key: "⌘ ↩", description: "Apply / Place Text")
                ShortcutRow(key: "⎋", description: "Cancel / Close Sheet")
            }
        }
    }
}

private struct AboutContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionHeader(
                icon: "info.circle",
                title: "About",
                subtitle: "Khayyam PDF Editor — crafted by Oxin Studio."
            )

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.accentColor)
                            .frame(width: 64, height: 64)
                        Image(systemName: "doc.richtext.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Khayyam PDF Editor")
                            .font(.title2.bold())
                        Text("Version 1.0")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("by Oxin Studio")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                Text("Khayyam PDF Editor is a native macOS PDF editing application built on Apple's PDFKit framework and the open-source MuPDF library. It lets you view, annotate, and edit PDF documents without needing a subscription or internet connection.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                HStack(spacing: 8) {
                    Image(systemName: "globe")
                        .foregroundColor(.accentColor)
                    Link("www.oxinstudio.com", destination: URL(string: "https://www.oxinstudio.com")!)
                        .font(.body)
                }

                Text("Copyright © 2026 Oxin Studio. All rights reserved.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)

                Divider()

                Text("Third-party components")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 6) {
                    Text("• MuPDF — Copyright © Artifex Software, Inc. Licensed under AGPL v3.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("• PDFKit — Apple Inc. All rights reserved.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

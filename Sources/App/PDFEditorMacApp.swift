import SwiftUI
import PDFKit
import UniformTypeIdentifiers

@main
struct KhayyamPDFEditorApp: App {
    @StateObject private var viewModel = PDFEditorViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .frame(minWidth: 900, minHeight: 600)
        }
        .commands {
            // Help menu
            CommandGroup(replacing: .help) {
                Button("Khayyam PDF Editor Help") {
                    openHelp()
                }
                .keyboardShortcut("?", modifiers: .command)

                Divider()

                Button("Who was Omar Khayyam?") {
                    openAboutKhayyam()
                }
            }
            // File menu
            CommandGroup(replacing: .newItem) {
                Button("Open PDF…") {
                    viewModel.openPDF()
                }
                .keyboardShortcut("o", modifiers: .command)

                Divider()

                Button("Save") {
                    viewModel.savePDF()
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(viewModel.currentDocument == nil)

                Button("Save As…") {
                    viewModel.saveAsPDF()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(viewModel.currentDocument == nil)

                Divider()

                Button("Export as PDF…") {
                    viewModel.exportAsPDF()
                }
                .disabled(viewModel.currentDocument == nil)
            }

            // Edit menu additions
            CommandGroup(after: .pasteboard) {
                Divider()

                Button("Delete Annotation") {
                    viewModel.deleteSelectedAnnotation()
                }
                .keyboardShortcut(.delete, modifiers: [])
                .disabled(viewModel.selectedAnnotation == nil)
            }

            // View menu
            CommandGroup(after: .toolbar) {
                Divider()

                Button("Zoom In") {
                    viewModel.zoomIn()
                }
                .keyboardShortcut("+", modifiers: .command)
                .disabled(viewModel.currentDocument == nil)

                Button("Zoom Out") {
                    viewModel.zoomOut()
                }
                .keyboardShortcut("-", modifiers: .command)
                .disabled(viewModel.currentDocument == nil)

                Button("Actual Size") {
                    viewModel.zoomToActualSize()
                }
                .keyboardShortcut("0", modifiers: .command)
                .disabled(viewModel.currentDocument == nil)

                Button("Fit Page") {
                    viewModel.zoomToFit()
                }
                .keyboardShortcut("9", modifiers: .command)
                .disabled(viewModel.currentDocument == nil)
            }

            // PDF menu
            CommandMenu("PDF") {
                Button("Go to First Page") {
                    viewModel.goToFirstPage()
                }
                .keyboardShortcut(.home, modifiers: .command)
                .disabled(viewModel.currentDocument == nil)

                Button("Go to Last Page") {
                    viewModel.goToLastPage()
                }
                .keyboardShortcut(.end, modifiers: .command)
                .disabled(viewModel.currentDocument == nil)

                Button("Previous Page") {
                    viewModel.goToPreviousPage()
                }
                .keyboardShortcut(.leftArrow, modifiers: .command)
                .disabled(viewModel.currentDocument == nil)

                Button("Next Page") {
                    viewModel.goToNextPage()
                }
                .keyboardShortcut(.rightArrow, modifiers: .command)
                .disabled(viewModel.currentDocument == nil)

                Divider()

                Button("Merge PDFs…") {
                    viewModel.showMergeSheet = true
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])

                Button("Split PDF…") {
                    viewModel.showSplitSheet = true
                }
                .disabled(viewModel.currentDocument == nil)

                Divider()

                Button("Rotate Page Left") {
                    viewModel.rotateCurrentPage(by: -90)
                }
                .keyboardShortcut("[", modifiers: [.command])
                .disabled(viewModel.currentDocument == nil)

                Button("Rotate Page Right") {
                    viewModel.rotateCurrentPage(by: 90)
                }
                .keyboardShortcut("]", modifiers: [.command])
                .disabled(viewModel.currentDocument == nil)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(viewModel)
        }
    }

    // MARK: - Open Help

    @MainActor
    private func openHelp() {
        // Open the dedicated Help window using NSWindowController so we don't need
        // the openWindow environment (which requires SwiftUI view context).
        for win in NSApplication.shared.windows where win.title == "Khayyam PDF Editor Help" {
            win.makeKeyAndOrderFront(nil)
            return
        }
        // No existing window — create one
        let helpWin = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        helpWin.isReleasedWhenClosed = false   // required for ARC — prevents double-free
        helpWin.title = "Khayyam PDF Editor Help"
        helpWin.center()
        helpWin.contentView = NSHostingView(rootView: HelpView())
        helpWin.minSize = NSSize(width: 720, height: 520)
        helpWin.makeKeyAndOrderFront(nil)
    }

    // MARK: - Open About Khayyam

    @MainActor
    private func openAboutKhayyam() {
        let title = "Who was Omar Khayyam?"
        for win in NSApplication.shared.windows where win.title == title {
            win.makeKeyAndOrderFront(nil)
            return
        }
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 680),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        win.isReleasedWhenClosed = false   // required for ARC — prevents double-free
        win.title = title
        win.center()
        win.contentView = NSHostingView(rootView: AboutKhayyamView())
        win.minSize = NSSize(width: 560, height: 480)
        win.makeKeyAndOrderFront(nil)
    }
}

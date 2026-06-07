import SwiftUI
import PDFKit

// MARK: - Resize Handle positions
enum ResizeHandle: CaseIterable {
    case topLeft, top, topRight
    case right
    case bottomRight, bottom, bottomLeft
    case left

    func position(in rect: CGRect) -> CGPoint {
        switch self {
        case .topLeft:     return CGPoint(x: rect.minX, y: rect.minY)
        case .top:         return CGPoint(x: rect.midX, y: rect.minY)
        case .topRight:    return CGPoint(x: rect.maxX, y: rect.minY)
        case .right:       return CGPoint(x: rect.maxX, y: rect.midY)
        case .bottomRight: return CGPoint(x: rect.maxX, y: rect.maxY)
        case .bottom:      return CGPoint(x: rect.midX, y: rect.maxY)
        case .bottomLeft:  return CGPoint(x: rect.minX, y: rect.maxY)
        case .left:        return CGPoint(x: rect.minX, y: rect.midY)
        }
    }

    var cursor: NSCursor {
        switch self {
        case .top, .bottom:             return .resizeUpDown
        case .left, .right:             return .resizeLeftRight
        case .topLeft, .bottomRight:    return .crosshair  // AppKit has no built-in diagonal resize cursor
        case .topRight, .bottomLeft:    return .crosshair
        }
    }
}

// MARK: - SelectionOverlayView
/// Shows a dashed selection border + 8 resize handles over the selected annotation.
/// Drag handles to resize; the annotation updates live.
struct SelectionOverlayView: View {
    @EnvironmentObject var viewModel: PDFEditorViewModel

    // Real-time bounds during a drag (drives overlay re-render)
    @State private var displayBounds: CGRect = .zero
    // Captured at drag start
    @State private var originalBounds: CGRect = .zero
    @State private var dragStartPagePt: CGPoint = .zero
    @State private var activeHandle: ResizeHandle? = nil

    var body: some View {
        GeometryReader { geo in
            if viewModel.selectedTool == .select,
               let annotation = viewModel.selectedAnnotation,
               let page = annotation.page,
               let pdfView = viewModel.pdfView {

                let pdfBounds = activeHandle != nil ? displayBounds : annotation.bounds
                let viewRect  = pdfView.convert(pdfBounds, from: page)

                // Convert from NSView coords (y-up) to SwiftUI coords (y-down)
                let screenRect = CGRect(
                    x: viewRect.minX,
                    y: geo.size.height - viewRect.maxY,
                    width:  max(viewRect.width,  1),
                    height: max(viewRect.height, 1)
                )

                ZStack {
                    // ── Selection border ──────────────────────────────────────
                    Rectangle()
                        .stroke(
                            Color.accentColor,
                            style: StrokeStyle(lineWidth: 1.5, dash: [5, 3])
                        )
                        .frame(width: screenRect.width, height: screenRect.height)
                        .position(x: screenRect.midX, y: screenRect.midY)

                    // ── 8 resize handles ──────────────────────────────────────
                    ForEach(ResizeHandle.allCases, id: \.self) { handle in
                        Circle()
                            .fill(Color.white)
                            .frame(width: 10, height: 10)
                            .overlay(
                                Circle().stroke(Color.accentColor, lineWidth: 1.5)
                            )
                            .shadow(color: .black.opacity(0.25), radius: 2)
                            .position(handle.position(in: screenRect))
                            .gesture(
                                DragGesture(minimumDistance: 1, coordinateSpace: .local)
                                    .onChanged { val in
                                        performResize(
                                            handle: handle, value: val,
                                            annotation: annotation, page: page,
                                            pdfView: pdfView, geoHeight: geo.size.height
                                        )
                                    }
                                    .onEnded { _ in
                                        activeHandle = nil
                                        viewModel.isModified = true
                                        viewModel.applyShapeProperties()
                                    }
                            )
                    }
                }
            }
        }
        .allowsHitTesting(viewModel.selectedTool == .select && viewModel.selectedAnnotation != nil)
    }

    // MARK: - Resize logic

    private func performResize(
        handle: ResizeHandle,
        value: DragGesture.Value,
        annotation: PDFAnnotation,
        page: PDFPage,
        pdfView: PDFView,
        geoHeight: CGFloat
    ) {
        // Capture original state on first event of this drag
        if activeHandle != handle {
            activeHandle = handle
            originalBounds = annotation.bounds
            displayBounds  = annotation.bounds
            // Convert SwiftUI start location → NSView → page
            let nsStart = CGPoint(x: value.startLocation.x,
                                  y: geoHeight - value.startLocation.y)
            dragStartPagePt = pdfView.convert(nsStart, to: page)
        }

        // Convert current SwiftUI location → page coordinates
        let nsCurrent = CGPoint(x: value.location.x,
                                y: geoHeight - value.location.y)
        let currentPt = pdfView.convert(nsCurrent, to: page)

        // Delta in PDF page space (y increases upward)
        let dx = currentPt.x - dragStartPagePt.x
        let dy = currentPt.y - dragStartPagePt.y

        let minSz: CGFloat = 15
        var nb = originalBounds

        // ── Apply delta per handle ──────────────────────────────────────────
        // "top" in screen = maxY in PDF; "bottom" = minY; left/right same.
        switch handle {

        case .topLeft:
            nb.origin.x  = min(originalBounds.maxX - minSz, originalBounds.minX + dx)
            nb.size.width = originalBounds.maxX - nb.origin.x
            let newMaxY   = max(originalBounds.minY + minSz, originalBounds.maxY + dy)
            nb.size.height = newMaxY - nb.origin.y

        case .top:
            let newMaxY   = max(originalBounds.minY + minSz, originalBounds.maxY + dy)
            nb.size.height = newMaxY - nb.origin.y

        case .topRight:
            nb.size.width  = max(minSz, originalBounds.width + dx)
            let newMaxY    = max(originalBounds.minY + minSz, originalBounds.maxY + dy)
            nb.size.height = newMaxY - nb.origin.y

        case .right:
            nb.size.width  = max(minSz, originalBounds.width + dx)

        case .bottomRight:
            nb.size.width  = max(minSz, originalBounds.width + dx)
            nb.origin.y    = min(originalBounds.maxY - minSz, originalBounds.minY + dy)
            nb.size.height = originalBounds.maxY - nb.origin.y

        case .bottom:
            nb.origin.y    = min(originalBounds.maxY - minSz, originalBounds.minY + dy)
            nb.size.height = originalBounds.maxY - nb.origin.y

        case .bottomLeft:
            nb.origin.x    = min(originalBounds.maxX - minSz, originalBounds.minX + dx)
            nb.size.width  = originalBounds.maxX - nb.origin.x
            nb.origin.y    = min(originalBounds.maxY - minSz, originalBounds.minY + dy)
            nb.size.height = originalBounds.maxY - nb.origin.y

        case .left:
            nb.origin.x   = min(originalBounds.maxX - minSz, originalBounds.minX + dx)
            nb.size.width = originalBounds.maxX - nb.origin.x
        }

        // Shift = constrain to square / circle
        let annotationType = annotation.type ?? ""
        let isSquareable = ["Square", "Circle"].contains(annotationType)
        if isSquareable && NSEvent.modifierFlags.contains(.shift) {
            let side = max(nb.width, nb.height)
            // Anchor the corner that isn't being dragged
            switch handle {
            case .topLeft, .left, .bottomLeft:
                nb.origin.x   = nb.maxX - side
            default:
                break
            }
            switch handle {
            case .bottomLeft, .bottom, .bottomRight:
                nb.origin.y   = nb.maxY - side
            default:
                break
            }
            nb.size = CGSize(width: side, height: side)
        }

        // Clamp to page
        let pageBounds = page.bounds(for: .mediaBox)
        nb.origin.x = max(pageBounds.minX, nb.origin.x)
        nb.origin.y = max(pageBounds.minY, nb.origin.y)
        if nb.maxX > pageBounds.maxX { nb.size.width  = pageBounds.maxX - nb.origin.x }
        if nb.maxY > pageBounds.maxY { nb.size.height = pageBounds.maxY - nb.origin.y }

        displayBounds     = nb
        annotation.bounds = nb
    }
}

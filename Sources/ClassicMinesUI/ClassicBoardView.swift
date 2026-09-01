import AppKit
import GameCore

@MainActor
public final class ClassicBoardView: NSView {
    public var game: MinesweeperGame {
        didSet { needsDisplay = true }
    }

    public var scale: Int {
        didSet {
            precondition((1...3).contains(scale))
            invalidateIntrinsicContentSize()
            needsDisplay = true
        }
    }

    public var previewedCoordinates: Set<Coordinate> = [] {
        didSet { needsDisplay = true }
    }

    public var focusedCoordinate: Coordinate? {
        didSet { needsDisplay = true }
    }

    public override var isFlipped: Bool { true }
    public override var acceptsFirstResponder: Bool { true }

    public init(game: MinesweeperGame, scale: Int) {
        self.game = game
        self.scale = scale
        super.init(frame: .zero)
        wantsLayer = true
        layer?.magnificationFilter = .nearest
        layer?.minificationFilter = .nearest
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    public override var intrinsicContentSize: NSSize {
        ClassicLayout(configuration: game.configuration, scale: scale).boardSize
    }

    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        false
    }

    public override func draw(_ dirtyRect: NSRect) {
        let baseSize = NSSize(
            width: CGFloat(game.configuration.dimensions.columns * 16),
            height: CGFloat(game.configuration.dimensions.rows * 16)
        )
        guard let image = makeBaseImage(size: baseSize) else { return }
        NSGraphicsContext.current?.imageInterpolation = .none
        NSImage(cgImage: image, size: baseSize).draw(
            in: bounds,
            from: NSRect(origin: .zero, size: baseSize),
            operation: .copy,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.none]
        )
    }

    private func makeBaseImage(size: NSSize) -> CGImage? {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        let context = graphics.cgContext
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)
        context.setShouldAntialias(false)
        context.setFillColor(ClassicPalette.darkShadow.cgColor)
        context.fill(NSRect(origin: .zero, size: size))

        let side = CGFloat(16)
        for coordinate in game.allCoordinates() {
            let rect = NSRect(
                x: CGFloat(coordinate.column) * side,
                y: CGFloat(coordinate.row) * side,
                width: side,
                height: side
            )
            drawCell(at: coordinate, in: rect, pixelScale: 1, context: context)
        }
        NSGraphicsContext.restoreGraphicsState()
        return bitmap.cgImage
    }

    private func drawCell(at coordinate: Coordinate, in rect: NSRect, pixelScale: Int, context: CGContext) {
        let cell = game[coordinate]
        let terminal = game.status.isTerminal
        let isExploded: Bool = if case .lost(let exploded) = game.status {
            exploded == coordinate
        } else {
            false
        }

        if isExploded {
            context.setFillColor(ClassicPalette.mineRed.cgColor)
            context.fill(rect)
            ClassicDrawing.drawMine(in: rect, context: context)
        } else if terminal && cell.mark == .flag && !cell.isMine {
            drawRevealedBackground(in: rect, context: context)
            ClassicDrawing.drawMine(in: rect, context: context)
            drawCross(in: rect, context: context)
        } else if terminal && cell.isMine {
            if cell.mark == .flag {
                ClassicDrawing.raised(rect, thickness: CGFloat(2 * pixelScale), context: context)
                ClassicDrawing.drawFlag(in: rect, context: context)
            } else {
                drawRevealedBackground(in: rect, context: context)
                ClassicDrawing.drawMine(in: rect, context: context)
            }
        } else if cell.isRevealed {
            drawRevealedBackground(in: rect, context: context)
            if cell.adjacentMineCount > 0 {
                PixelGlyphs.draw(
                    Character(String(cell.adjacentMineCount)),
                    in: rect.insetBy(dx: CGFloat(3 * pixelScale), dy: CGFloat(2 * pixelScale)),
                    pixelSize: CGFloat(pixelScale),
                    color: ClassicPalette.number(cell.adjacentMineCount),
                    context: context
                )
            }
        } else if previewedCoordinates.contains(coordinate) {
            drawRevealedBackground(in: rect, context: context)
        } else {
            ClassicDrawing.raised(rect, thickness: CGFloat(2 * pixelScale), context: context)
            if cell.mark == .flag {
                ClassicDrawing.drawFlag(in: rect, context: context)
            } else if cell.mark == .question {
                PixelGlyphs.draw(
                    "?",
                    in: rect.insetBy(dx: CGFloat(3 * pixelScale), dy: CGFloat(2 * pixelScale)),
                    pixelSize: CGFloat(pixelScale),
                    color: ClassicPalette.black,
                    context: context
                )
            }
        }

        if focusedCoordinate == coordinate {
            let focusRect = rect.insetBy(dx: CGFloat(3 * pixelScale), dy: CGFloat(3 * pixelScale))
            context.setStrokeColor(NSColor.keyboardFocusIndicatorColor.cgColor)
            context.setLineWidth(CGFloat(pixelScale))
            context.stroke(focusRect)
        }
    }

    private func drawRevealedBackground(in rect: NSRect, context: CGContext) {
        context.setFillColor(ClassicPalette.panel.cgColor)
        context.fill(rect)
        context.setStrokeColor(ClassicPalette.shadow.cgColor)
        context.setLineWidth(1)
        context.stroke(rect.insetBy(dx: 0.5, dy: 0.5))
    }

    private func drawCross(in rect: NSRect, context: CGContext) {
        context.setStrokeColor(ClassicPalette.mineRed.cgColor)
        context.setLineWidth(2)
        context.move(to: CGPoint(x: rect.minX + 3, y: rect.minY + 3))
        context.addLine(to: CGPoint(x: rect.maxX - 3, y: rect.maxY - 3))
        context.move(to: CGPoint(x: rect.maxX - 3, y: rect.minY + 3))
        context.addLine(to: CGPoint(x: rect.minX + 3, y: rect.maxY - 3))
        context.strokePath()
    }
}

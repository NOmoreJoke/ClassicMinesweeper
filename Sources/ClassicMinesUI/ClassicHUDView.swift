import AppKit
import GameCore

@MainActor
public final class ClassicHUDView: NSView {
    public var remainingMines = 0 { didSet { needsDisplay = true } }
    public var elapsedSeconds = 0 { didSet { needsDisplay = true } }
    public var gameStatus: GameStatus = .ready { didSet { needsDisplay = true } }
    public var isPressingBoard = false { didSet { needsDisplay = true } }
    public var scale = 1 { didSet { needsDisplay = true } }

    public override var isFlipped: Bool { true }

    public override func draw(_ dirtyRect: NSRect) {
        let baseSize = NSSize(width: bounds.width / CGFloat(scale), height: bounds.height / CGFloat(scale))
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
        let baseBounds = NSRect(origin: .zero, size: size)
        ClassicDrawing.recessed(baseBounds, thickness: 2, context: context)

        let counterSize = NSSize(width: 39, height: 23)
        let y = floor((baseBounds.height - counterSize.height) / 2)
        drawCounter(
            remainingMines,
            in: NSRect(x: 6, y: y, width: counterSize.width, height: counterSize.height),
            pixelScale: 1,
            context: context
        )
        drawCounter(
            elapsedSeconds,
            in: NSRect(
                x: baseBounds.width - counterSize.width - 6,
                y: y,
                width: counterSize.width,
                height: counterSize.height
            ),
            pixelScale: 1,
            context: context
        )

        let faceSide = CGFloat(26)
        drawFace(
            in: NSRect(x: floor(baseBounds.midX - faceSide / 2), y: floor(baseBounds.midY - faceSide / 2), width: faceSide, height: faceSide),
            pixelScale: 1,
            context: context
        )
        NSGraphicsContext.restoreGraphicsState()
        return bitmap.cgImage
    }

    private func drawCounter(_ rawValue: Int, in rect: NSRect, pixelScale: Int, context: CGContext) {
        ClassicDrawing.recessed(rect, thickness: CGFloat(pixelScale), context: context)
        let inner = rect.insetBy(dx: CGFloat(2 * pixelScale), dy: CGFloat(2 * pixelScale))
        context.setFillColor(ClassicPalette.black.cgColor)
        context.fill(inner)

        let value = min(999, max(-99, rawValue))
        let text = value < 0
            ? String(format: "-%02d", abs(value))
            : String(format: "%03d", value)
        let characterWidth = inner.width / 3
        for (index, character) in text.enumerated() {
            PixelGlyphs.draw(
                character,
                in: NSRect(
                    x: inner.minX + CGFloat(index) * characterWidth,
                    y: inner.minY,
                    width: characterWidth,
                    height: inner.height
                ).insetBy(dx: CGFloat(pixelScale), dy: CGFloat(pixelScale)),
                pixelSize: CGFloat(2 * pixelScale),
                color: ClassicPalette.ledRed,
                context: context
            )
        }
    }

    private func drawFace(in rect: NSRect, pixelScale: Int, context: CGContext) {
        ClassicDrawing.raised(rect, thickness: CGFloat(2 * pixelScale), context: context)
        let face = rect.insetBy(dx: CGFloat(4 * pixelScale), dy: CGFloat(4 * pixelScale))
        let pixel = CGFloat(pixelScale)
        for row in 0..<18 {
            for column in 0..<18 {
                let dx = Double(column) - 8.5
                let dy = Double(row) - 8.5
                let distance = dx * dx + dy * dy
                guard distance <= 72 else { continue }
                let color = distance >= 58 ? ClassicPalette.black : NSColor.yellow
                context.setFillColor(color.cgColor)
                context.fill(NSRect(
                    x: face.minX + CGFloat(column) * pixel,
                    y: face.minY + CGFloat(row) * pixel,
                    width: pixel,
                    height: pixel
                ))
            }
        }

        let eye = CGFloat(2 * pixelScale)
        context.setFillColor(ClassicPalette.black.cgColor)
        context.fill(NSRect(x: face.minX + CGFloat(4 * pixelScale), y: face.minY + CGFloat(5 * pixelScale), width: eye, height: eye))
        context.fill(NSRect(x: face.maxX - CGFloat(6 * pixelScale), y: face.minY + CGFloat(5 * pixelScale), width: eye, height: eye))

        switch gameStatus {
        case .lost:
            drawDeadMouth(in: face, pixelScale: pixelScale, context: context)
        case .won:
            drawSunglasses(in: face, pixelScale: pixelScale, context: context)
        case .ready, .playing:
            if isPressingBoard {
                context.strokeEllipse(in: NSRect(x: face.midX - eye, y: face.maxY - CGFloat(6 * pixelScale), width: eye * 2, height: eye * 2))
            } else {
                context.setStrokeColor(ClassicPalette.black.cgColor)
                context.setLineWidth(CGFloat(pixelScale))
                context.move(to: CGPoint(x: face.minX + CGFloat(4 * pixelScale), y: face.maxY - CGFloat(6 * pixelScale)))
                context.addLine(to: CGPoint(x: face.midX, y: face.maxY - CGFloat(3 * pixelScale)))
                context.addLine(to: CGPoint(x: face.maxX - CGFloat(4 * pixelScale), y: face.maxY - CGFloat(6 * pixelScale)))
                context.strokePath()
            }
        }
    }

    private func drawDeadMouth(in face: NSRect, pixelScale: Int, context: CGContext) {
        context.setStrokeColor(ClassicPalette.black.cgColor)
        context.setLineWidth(CGFloat(pixelScale))
        context.move(to: CGPoint(x: face.minX + CGFloat(4 * pixelScale), y: face.maxY - CGFloat(3 * pixelScale)))
        context.addLine(to: CGPoint(x: face.midX, y: face.maxY - CGFloat(6 * pixelScale)))
        context.addLine(to: CGPoint(x: face.maxX - CGFloat(4 * pixelScale), y: face.maxY - CGFloat(3 * pixelScale)))
        context.strokePath()
    }

    private func drawSunglasses(in face: NSRect, pixelScale: Int, context: CGContext) {
        context.setFillColor(ClassicPalette.black.cgColor)
        context.fill(NSRect(x: face.minX + CGFloat(2 * pixelScale), y: face.minY + CGFloat(4 * pixelScale), width: face.width - CGFloat(4 * pixelScale), height: CGFloat(4 * pixelScale)))
    }
}

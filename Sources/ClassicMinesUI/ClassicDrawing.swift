import AppKit
import GameCore

enum ClassicDrawing {
    static func raised(_ rect: NSRect, thickness: CGFloat, context: CGContext) {
        context.setFillColor(ClassicPalette.panel.cgColor)
        context.fill(rect)
        context.setFillColor(ClassicPalette.highlight.cgColor)
        context.fill(NSRect(x: rect.minX, y: rect.minY, width: rect.width, height: thickness))
        context.fill(NSRect(x: rect.minX, y: rect.minY, width: thickness, height: rect.height))
        context.setFillColor(ClassicPalette.darkShadow.cgColor)
        context.fill(NSRect(x: rect.minX, y: rect.maxY - thickness, width: rect.width, height: thickness))
        context.fill(NSRect(x: rect.maxX - thickness, y: rect.minY, width: thickness, height: rect.height))
    }

    static func recessed(_ rect: NSRect, thickness: CGFloat, context: CGContext) {
        context.setFillColor(ClassicPalette.panel.cgColor)
        context.fill(rect)
        context.setFillColor(ClassicPalette.darkShadow.cgColor)
        context.fill(NSRect(x: rect.minX, y: rect.minY, width: rect.width, height: thickness))
        context.fill(NSRect(x: rect.minX, y: rect.minY, width: thickness, height: rect.height))
        context.setFillColor(ClassicPalette.highlight.cgColor)
        context.fill(NSRect(x: rect.minX, y: rect.maxY - thickness, width: rect.width, height: thickness))
        context.fill(NSRect(x: rect.maxX - thickness, y: rect.minY, width: thickness, height: rect.height))
    }

    static func drawFlag(in rect: NSRect, context: CGContext) {
        let unit = max(1, floor(rect.width / 16))
        context.setFillColor(ClassicPalette.black.cgColor)
        context.fill(NSRect(x: rect.midX, y: rect.minY + 4 * unit, width: unit, height: 8 * unit))
        context.fill(NSRect(x: rect.midX - 3 * unit, y: rect.maxY - 4 * unit, width: 7 * unit, height: unit))
        context.setFillColor(ClassicPalette.mineRed.cgColor)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY + 4 * unit))
        path.addLine(to: CGPoint(x: rect.midX - 5 * unit, y: rect.minY + 7 * unit))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY + 10 * unit))
        path.closeSubpath()
        context.addPath(path)
        context.fillPath()
    }

    static func drawMine(in rect: NSRect, context: CGContext) {
        let unit = max(1, floor(rect.width / 16))
        context.setFillColor(ClassicPalette.black.cgColor)
        context.fillEllipse(in: rect.insetBy(dx: 4 * unit, dy: 4 * unit))
        context.fill(NSRect(x: rect.midX - unit / 2, y: rect.minY + 2 * unit, width: unit, height: 12 * unit))
        context.fill(NSRect(x: rect.minX + 2 * unit, y: rect.midY - unit / 2, width: 12 * unit, height: unit))
    }
}

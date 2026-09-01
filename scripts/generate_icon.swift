import AppKit

guard CommandLine.arguments.count == 2 else {
    fatalError("usage: generate_icon.swift OUTPUT.png")
}

let size = 1024
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else { fatalError("bitmap allocation failed") }

NSGraphicsContext.saveGraphicsState()
guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fatalError("graphics context creation failed")
}
NSGraphicsContext.current = context
context.shouldAntialias = false

let canvas = NSRect(x: 0, y: 0, width: size, height: size)
NSColor(calibratedWhite: 0.75, alpha: 1).setFill()
canvas.fill()

let border = 72
NSColor.white.setFill()
NSRect(x: border, y: border, width: size - border * 2, height: size - border * 2).fill()
NSColor(calibratedWhite: 0.25, alpha: 1).setFill()
NSRect(x: border + 28, y: border + 28, width: size - border * 2 - 28, height: size - border * 2 - 28).fill()
NSColor(calibratedWhite: 0.75, alpha: 1).setFill()
NSRect(x: border + 28, y: border + 28, width: size - border * 2 - 56, height: size - border * 2 - 56).fill()

let tile: CGFloat = 150
let gap: CGFloat = 8
let origin: CGFloat = 125
for row in 0..<5 {
    for column in 0..<5 {
        let rect = NSRect(
            x: origin + CGFloat(column) * (tile + gap),
            y: origin + CGFloat(row) * (tile + gap),
            width: tile,
            height: tile
        )
        NSColor.white.setFill()
        rect.fill()
        NSColor(calibratedWhite: 0.35, alpha: 1).setFill()
        let shadowRect = NSRect(
            x: rect.minX + 14,
            y: rect.minY + 14,
            width: tile - 14,
            height: tile - 14
        )
        shadowRect.fill()
        NSColor(calibratedWhite: 0.75, alpha: 1).setFill()
        let faceRect = NSRect(
            x: rect.minX + 14,
            y: rect.minY + 14,
            width: tile - 28,
            height: tile - 28
        )
        faceRect.fill()
    }
}

let center = NSPoint(x: 512, y: 512)
NSColor.black.setFill()
NSRect(x: center.x - 62, y: center.y - 18, width: 124, height: 36).fill()
NSRect(x: center.x - 18, y: center.y - 62, width: 36, height: 124).fill()
NSRect(x: center.x - 44, y: center.y - 44, width: 88, height: 88).fill()
NSColor.white.setFill()
NSRect(x: center.x - 24, y: center.y + 18, width: 18, height: 18).fill()

NSGraphicsContext.restoreGraphicsState()
guard let data = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("PNG encoding failed")
}
try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]), options: .atomic)

import AppKit

enum PixelGlyphs {
    private static let glyphs: [Character: [String]] = [
        "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
        "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
        "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
        "3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
        "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
        "5": ["11111", "10000", "10000", "11110", "00001", "00001", "11110"],
        "6": ["01110", "10000", "10000", "11110", "10001", "10001", "01110"],
        "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
        "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
        "9": ["01110", "10001", "10001", "01111", "00001", "00001", "01110"],
        "?": ["01110", "10001", "00001", "00010", "00100", "00000", "00100"],
        "-": ["00000", "00000", "00000", "11111", "00000", "00000", "00000"],
    ]

    static func draw(
        _ character: Character,
        in rect: NSRect,
        pixelSize: CGFloat,
        color: NSColor,
        context: CGContext
    ) {
        guard let rows = glyphs[character] else { return }
        let unit = pixelSize
        let originX = floor(rect.midX - unit * 2.5)
        let originY = floor(rect.midY - unit * 3.5)
        context.setFillColor(color.cgColor)
        for (rowIndex, row) in rows.enumerated() {
            for (columnIndex, bit) in row.enumerated() where bit == "1" {
                context.fill(NSRect(
                    x: originX + CGFloat(columnIndex) * unit,
                    y: originY + CGFloat(rowIndex) * unit,
                    width: unit,
                    height: unit
                ))
            }
        }
    }
}

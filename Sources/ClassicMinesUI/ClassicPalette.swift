import AppKit

public enum ClassicPalette {
    public static let panel = NSColor(srgbRed: 0.753, green: 0.753, blue: 0.753, alpha: 1)
    public static let highlight = NSColor.white
    public static let shadow = NSColor(srgbRed: 0.502, green: 0.502, blue: 0.502, alpha: 1)
    public static let darkShadow = NSColor(srgbRed: 0.251, green: 0.251, blue: 0.251, alpha: 1)
    public static let black = NSColor.black
    public static let ledRed = NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)
    public static let ledOff = NSColor(srgbRed: 0.22, green: 0, blue: 0, alpha: 1)
    public static let mineRed = NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)

    public static func number(_ value: UInt8) -> NSColor {
        switch value {
        case 1: NSColor(srgbRed: 0, green: 0, blue: 1, alpha: 1)
        case 2: NSColor(srgbRed: 0, green: 0.5, blue: 0, alpha: 1)
        case 3: NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)
        case 4: NSColor(srgbRed: 0, green: 0, blue: 0.5, alpha: 1)
        case 5: NSColor(srgbRed: 0.5, green: 0, blue: 0, alpha: 1)
        case 6: NSColor(srgbRed: 0, green: 0.5, blue: 0.5, alpha: 1)
        case 7: NSColor.black
        default: NSColor.darkGray
        }
    }
}


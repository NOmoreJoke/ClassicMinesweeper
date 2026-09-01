import AppKit
import GameCore

public struct ClassicLayout: Equatable, Sendable {
    public let configuration: GameConfiguration
    public let scale: Int

    public init(configuration: GameConfiguration, scale: Int) {
        precondition((1...3).contains(scale))
        self.configuration = configuration
        self.scale = scale
    }

    public var cellSide: CGFloat { CGFloat(16 * scale) }
    public var padding: CGFloat { CGFloat(6 * scale) }
    public var menuHeight: CGFloat { CGFloat(20 * scale) }
    public var hudHeight: CGFloat { CGFloat(40 * scale) }
    public var gap: CGFloat { CGFloat(6 * scale) }

    public var boardSize: NSSize {
        NSSize(
            width: CGFloat(configuration.dimensions.columns) * cellSide,
            height: CGFloat(configuration.dimensions.rows) * cellSide
        )
    }

    public var contentSize: NSSize {
        NSSize(
            width: boardSize.width + padding * 2,
            height: menuHeight + padding + hudHeight + gap + boardSize.height + padding
        )
    }

    public var menuFrame: NSRect {
        NSRect(x: 0, y: 0, width: contentSize.width, height: menuHeight)
    }

    public var hudFrame: NSRect {
        NSRect(x: padding, y: menuHeight + padding, width: boardSize.width, height: hudHeight)
    }

    public var boardFrame: NSRect {
        NSRect(
            x: padding,
            y: menuHeight + padding + hudHeight + gap,
            width: boardSize.width,
            height: boardSize.height
        )
    }

    public static func largestFittingScale(
        configuration: GameConfiguration,
        preferred: Int,
        visibleSize: NSSize
    ) -> Int {
        for candidate in stride(from: min(3, max(1, preferred)), through: 1, by: -1) {
            let size = ClassicLayout(configuration: configuration, scale: candidate).contentSize
            if size.width <= visibleSize.width && size.height <= visibleSize.height {
                return candidate
            }
        }
        return 1
    }
}

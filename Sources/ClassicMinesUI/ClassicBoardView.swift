import AppKit
import GameCore
import os

@MainActor
public final class ClassicBoardView: NSView {
    enum AccessibilityChangeScope: Equatable {
        case none
        case single
        case batch
    }
    public weak var interactionDelegate: ClassicBoardInteractionDelegate?
    public var pressingStateDidChange: ((Bool) -> Void)?

    public var game: MinesweeperGame {
        didSet {
            if let focusedCoordinate,
               !game.configuration.dimensions.contains(focusedCoordinate) {
                self.focusedCoordinate = Coordinate(row: 0, column: 0)
            }
            rebuildAccessibilityElementsIfNeeded()
            refreshAccessibilityValues()
            needsDisplay = true
        }
    }

    public var scale: Int {
        didSet {
            precondition((1...3).contains(scale))
            invalidateIntrinsicContentSize()
            refreshAccessibilityFrames()
            needsDisplay = true
        }
    }

    public var previewedCoordinates: Set<Coordinate> = [] {
        didSet {
            pressingStateDidChange?(!previewedCoordinates.isEmpty)
            needsDisplay = true
        }
    }

    public var focusedCoordinate: Coordinate? {
        didSet {
            needsDisplay = true
            if let focusedCoordinate, let element = accessibilityCells[focusedCoordinate] {
                NSAccessibility.post(element: element, notification: .focusedUIElementChanged)
            }
        }
    }

    private var leftDown = false
    private var rightDown = false
    private var gestureOrigin: Coordinate?
    private var chordMode = false
    private var chordTriggered = false
    private var rightMarked = false
    private var controlClickActive = false
    private var accessibilityCells: [Coordinate: BoardAccessibilityCell] = [:]
    private let signposter = OSSignposter(subsystem: BuildInfo.bundleIdentifier, category: "BoardInput")

    public override var isFlipped: Bool { true }
    public override var acceptsFirstResponder: Bool { true }

    public init(game: MinesweeperGame, scale: Int) {
        self.game = game
        self.scale = scale
        super.init(frame: .zero)
        wantsLayer = true
        layer?.magnificationFilter = .nearest
        layer?.minificationFilter = .nearest
        setAccessibilityRole(.grid)
        setAccessibilityLabel("Minesweeper board")
        rebuildAccessibilityElementsIfNeeded()
        refreshAccessibilityValues()
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

    public override func becomeFirstResponder() -> Bool {
        if focusedCoordinate == nil {
            focusedCoordinate = Coordinate(row: 0, column: 0)
        }
        return true
    }

    public override func mouseDown(with event: NSEvent) {
        let state = signposter.beginInterval("PrimaryPress")
        defer { signposter.endInterval("PrimaryPress", state) }
        guard let coordinate = coordinate(for: event) else { return }
        handlePrimaryMouseDown(at: coordinate, control: event.modifierFlags.contains(.control))
    }

    public override func rightMouseDown(with event: NSEvent) {
        let state = signposter.beginInterval("SecondaryPress")
        defer { signposter.endInterval("SecondaryPress", state) }
        guard let coordinate = coordinate(for: event) else { return }
        handlePress(.secondary, at: coordinate)
    }

    public override func mouseDragged(with event: NSEvent) {
        handleDrag(to: coordinate(for: event))
    }

    public override func rightMouseDragged(with event: NSEvent) {
        handleDrag(to: coordinate(for: event))
    }

    public override func mouseUp(with event: NSEvent) {
        let state = signposter.beginInterval("PrimaryRelease")
        defer { signposter.endInterval("PrimaryRelease", state) }
        handlePrimaryMouseUp(at: coordinate(for: event))
        reconcilePhysicalButtons()
    }

    public override func rightMouseUp(with event: NSEvent) {
        let state = signposter.beginInterval("SecondaryRelease")
        defer { signposter.endInterval("SecondaryRelease", state) }
        handleRelease(.secondary, at: coordinate(for: event))
        reconcilePhysicalButtons()
    }

    public override func menu(for event: NSEvent) -> NSMenu? {
        nil
    }

    public override func keyDown(with event: NSEvent) {
        guard let focused = focusedCoordinate else {
            super.keyDown(with: event)
            return
        }
        let dimensions = game.configuration.dimensions
        switch event.keyCode {
        case 123:
            moveFocus(to: Coordinate(row: focused.row, column: max(0, focused.column - 1)))
        case 124:
            moveFocus(to: Coordinate(row: focused.row, column: min(dimensions.columns - 1, focused.column + 1)))
        case 125:
            moveFocus(to: Coordinate(row: min(dimensions.rows - 1, focused.row + 1), column: focused.column))
        case 126:
            moveFocus(to: Coordinate(row: max(0, focused.row - 1), column: focused.column))
        case 49 where !event.isARepeat:
            interactionDelegate?.boardView(self, reveal: focused)
        case 3 where !event.isARepeat:
            interactionDelegate?.boardView(self, toggleMark: focused)
        case 36 where !event.isARepeat, 76 where !event.isARepeat:
            interactionDelegate?.boardView(self, chord: focused)
        default:
            super.keyDown(with: event)
        }
    }

    func handlePress(_ button: PointerButton, at coordinate: Coordinate) {
        guard !game.status.isTerminal else { return }
        if gestureOrigin == nil {
            gestureOrigin = coordinate
        }
        guard coordinate == gestureOrigin else { return }

        switch button {
        case .primary:
            leftDown = true
        case .secondary:
            rightDown = true
        }

        if leftDown && rightDown && isChordOrigin(coordinate) {
            chordMode = true
            updatePreview(pointer: coordinate)
        } else if button == .secondary && !leftDown && !rightMarked && !game[coordinate].isRevealed {
            rightMarked = true
            interactionDelegate?.boardView(self, toggleMark: coordinate)
            updatePreview(pointer: coordinate)
        } else {
            updatePreview(pointer: coordinate)
        }
    }

    func handlePrimaryMouseDown(at coordinate: Coordinate, control: Bool) {
        controlClickActive = control
        handlePress(control ? .secondary : .primary, at: coordinate)
    }

    func handlePrimaryMouseUp(at coordinate: Coordinate?) {
        handleRelease(controlClickActive ? .secondary : .primary, at: coordinate)
        controlClickActive = false
    }

    func handleDrag(to coordinate: Coordinate?) {
        updatePreview(pointer: coordinate)
    }

    func handleRelease(_ button: PointerButton, at coordinate: Coordinate?) {
        guard let origin = gestureOrigin else { return }
        let isInsideOrigin = coordinate == origin

        if chordMode {
            if !chordTriggered && isInsideOrigin {
                chordTriggered = true
                interactionDelegate?.boardView(self, chord: origin)
            }
        } else if button == .primary && isInsideOrigin && !rightDown {
            interactionDelegate?.boardView(self, reveal: origin)
        }

        switch button {
        case .primary: leftDown = false
        case .secondary: rightDown = false
        }
        previewedCoordinates = []
        if !leftDown && !rightDown {
            resetPointerState()
        }
    }

    public func cancelPointerGesture() {
        resetPointerState()
        previewedCoordinates = []
    }

    public func apply(game: MinesweeperGame, changedCoordinates: Set<Coordinate>) {
        self.game = game
        if Self.accessibilityChangeScope(for: changedCoordinates.count) == .single,
           let coordinate = changedCoordinates.first,
           let element = accessibilityCells[coordinate] {
            NSAccessibility.post(element: element, notification: .valueChanged)
        } else if Self.accessibilityChangeScope(for: changedCoordinates.count) == .batch {
            NSAccessibility.post(element: self, notification: .valueChanged)
            if !game.status.isTerminal {
                announce("\(changedCoordinates.count) cells revealed")
            }
        }
    }

    static func accessibilityChangeScope(for count: Int) -> AccessibilityChangeScope {
        if count == 0 { return .none }
        if count == 1 { return .single }
        return .batch
    }

    public func announce(_ message: String) {
        NSAccessibility.post(
            element: NSApplication.shared,
            notification: .announcementRequested,
            userInfo: [.announcement: message, .priority: NSAccessibilityPriorityLevel.high.rawValue]
        )
    }

    func performAccessibilityReveal(at coordinate: Coordinate) -> Bool {
        guard game.configuration.dimensions.contains(coordinate),
              !game[coordinate].isRevealed,
              game[coordinate].mark != .flag,
              !game.status.isTerminal else { return false }
        focusedCoordinate = coordinate
        interactionDelegate?.boardView(self, reveal: coordinate)
        return true
    }

    func performAccessibilityToggleMark(at coordinate: Coordinate) -> Bool {
        guard game.configuration.dimensions.contains(coordinate),
              !game[coordinate].isRevealed,
              !game.status.isTerminal else { return false }
        focusedCoordinate = coordinate
        interactionDelegate?.boardView(self, toggleMark: coordinate)
        return true
    }

    func performAccessibilityChord(at coordinate: Coordinate) -> Bool {
        guard game.configuration.dimensions.contains(coordinate),
              isChordOrigin(coordinate),
              !game.status.isTerminal else { return false }
        focusedCoordinate = coordinate
        interactionDelegate?.boardView(self, chord: coordinate)
        return true
    }

    private func coordinate(for event: NSEvent) -> Coordinate? {
        let point = convert(event.locationInWindow, from: nil)
        guard bounds.contains(point) else { return nil }
        let side = CGFloat(16 * scale)
        let coordinate = Coordinate(row: Int(point.y / side), column: Int(point.x / side))
        return game.configuration.dimensions.contains(coordinate) ? coordinate : nil
    }

    private func moveFocus(to coordinate: Coordinate) {
        focusedCoordinate = coordinate
    }

    private func updatePreview(pointer coordinate: Coordinate?) {
        guard coordinate == gestureOrigin, let origin = gestureOrigin else {
            previewedCoordinates = []
            return
        }
        if chordMode {
            previewedCoordinates = Set(origin.neighbors(in: game.configuration.dimensions).filter {
                !game[$0].isRevealed && game[$0].mark != .flag
            })
        } else if leftDown && !rightDown && !game[origin].isRevealed && game[origin].mark != .flag {
            previewedCoordinates = [origin]
        } else {
            previewedCoordinates = []
        }
    }

    private func isChordOrigin(_ coordinate: Coordinate) -> Bool {
        game[coordinate].isRevealed && game[coordinate].adjacentMineCount > 0
    }

    private func resetPointerState() {
        leftDown = false
        rightDown = false
        gestureOrigin = nil
        chordMode = false
        chordTriggered = false
        rightMarked = false
        controlClickActive = false
    }

    private func reconcilePhysicalButtons() {
        let pressed = NSEvent.pressedMouseButtons
        let physicalLeft = (pressed & 1) != 0
        let physicalRight = (pressed & 2) != 0
        if (leftDown && !physicalLeft) || (rightDown && !physicalRight && !controlClickActive) {
            cancelPointerGesture()
        }
    }

    private func rebuildAccessibilityElementsIfNeeded() {
        let coordinates = game.allCoordinates()
        let coordinateSet = Set(coordinates)
        guard Set(accessibilityCells.keys) != coordinateSet else {
            refreshAccessibilityFrames()
            return
        }
        accessibilityCells = Dictionary(uniqueKeysWithValues: coordinates.map { coordinate in
            (coordinate, BoardAccessibilityCell(coordinate: coordinate, boardView: self))
        })
        setAccessibilityChildren(coordinates.compactMap { accessibilityCells[$0] })
        refreshAccessibilityFrames()
    }

    private func refreshAccessibilityFrames() {
        let side = CGFloat(16 * scale)
        for (coordinate, element) in accessibilityCells {
            element.setAccessibilityFrameInParentSpace(NSRect(
                x: CGFloat(coordinate.column) * side,
                y: CGFloat(coordinate.row) * side,
                width: side,
                height: side
            ))
        }
    }

    private func refreshAccessibilityValues() {
        for (coordinate, element) in accessibilityCells {
            element.setAccessibilityLabel("Row \(coordinate.row + 1), column \(coordinate.column + 1)")
            element.setAccessibilityValue(accessibilityValue(for: coordinate))
            let cell = game[coordinate]
            if !game.status.isTerminal && !cell.isRevealed && cell.mark == .flag {
                element.setAccessibilityCustomActions([
                    NSAccessibilityCustomAction(name: "Toggle mark", target: element, selector: #selector(BoardAccessibilityCell.performToggleMark)),
                ])
            } else if !game.status.isTerminal && !cell.isRevealed {
                element.setAccessibilityCustomActions([
                    NSAccessibilityCustomAction(name: "Reveal", target: element, selector: #selector(BoardAccessibilityCell.performReveal)),
                    NSAccessibilityCustomAction(name: "Toggle mark", target: element, selector: #selector(BoardAccessibilityCell.performToggleMark)),
                ])
            } else if !game.status.isTerminal && cell.isRevealed && cell.adjacentMineCount > 0 {
                element.setAccessibilityCustomActions([
                    NSAccessibilityCustomAction(name: "Chord", target: element, selector: #selector(BoardAccessibilityCell.performChord)),
                ])
            } else {
                element.setAccessibilityCustomActions([])
            }
        }
    }

    @objc func accessibilityPerformDefaultCell(_ request: AccessibilityRequest) {
        let coordinate = request.coordinate
        guard game.configuration.dimensions.contains(coordinate), !game.status.isTerminal else {
            request.complete(false)
            return
        }
        let cell = game[coordinate]
        if cell.isRevealed {
            request.complete(performAccessibilityChord(at: coordinate))
        } else if cell.mark == .flag {
            request.complete(performAccessibilityToggleMark(at: coordinate))
        } else {
            request.complete(performAccessibilityReveal(at: coordinate))
        }
    }

    @objc func accessibilityRevealCell(_ request: AccessibilityRequest) {
        request.complete(performAccessibilityReveal(at: request.coordinate))
    }

    @objc func accessibilityToggleMarkCell(_ request: AccessibilityRequest) {
        request.complete(performAccessibilityToggleMark(at: request.coordinate))
    }

    @objc func accessibilityChordCell(_ request: AccessibilityRequest) {
        request.complete(performAccessibilityChord(at: request.coordinate))
    }

    @objc func accessibilityFocusCell(_ request: AccessibilityRequest) {
        let coordinate = request.coordinate
        if game.configuration.dimensions.contains(coordinate) {
            focusedCoordinate = coordinate
            request.complete(true)
        } else {
            request.complete(false)
        }
    }

    private func accessibilityValue(for coordinate: Coordinate) -> String {
        let cell = game[coordinate]
        if game.status.isTerminal && cell.mark == .flag && !cell.isMine { return "Wrong flag" }
        if cell.mark == .flag { return "Flag" }
        if cell.mark == .question { return "Question mark" }
        if cell.isRevealed && cell.isMine { return "Mine" }
        if cell.isRevealed && cell.adjacentMineCount == 0 { return "Empty" }
        if cell.isRevealed { return "Number \(cell.adjacentMineCount)" }
        if game.status.isTerminal && cell.isMine { return "Mine" }
        return "Covered"
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

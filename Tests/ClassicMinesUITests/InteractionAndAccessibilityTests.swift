import AppKit
import Testing
@testable import ClassicMinesUI
@testable import GameCore

@MainActor
private final class InteractionSpy: ClassicBoardInteractionDelegate {
    var reveals: [Coordinate] = []
    var marks: [Coordinate] = []
    var chords: [Coordinate] = []

    func boardView(_ boardView: ClassicBoardView, reveal coordinate: Coordinate) {
        reveals.append(coordinate)
    }

    func boardView(_ boardView: ClassicBoardView, toggleMark coordinate: Coordinate) {
        marks.append(coordinate)
    }

    func boardView(_ boardView: ClassicBoardView, chord coordinate: Coordinate) {
        chords.append(coordinate)
    }
}

private final class SendableAccessibilityCellBox: @unchecked Sendable {
    let cell: BoardAccessibilityCell

    init(_ cell: BoardAccessibilityCell) {
        self.cell = cell
    }
}

@MainActor
private final class ApplyingMarkDelegate: ClassicBoardInteractionDelegate {
    private var game: MinesweeperGame

    init(game: MinesweeperGame) {
        self.game = game
    }

    func boardView(_ boardView: ClassicBoardView, reveal coordinate: Coordinate) {}

    func boardView(_ boardView: ClassicBoardView, toggleMark coordinate: Coordinate) {
        let change = game.toggleMark(at: coordinate)
        boardView.apply(game: game, changedCoordinates: change.changedCoordinates)
    }

    func boardView(_ boardView: ClassicBoardView, chord coordinate: Coordinate) {}
}

@MainActor
private func makeBoard(game: MinesweeperGame? = nil) -> (ClassicBoardView, InteractionSpy) {
    let game = game ?? MinesweeperGame(configuration: GamePreset.beginner.configuration, seed: 42)
    let board = ClassicBoardView(game: game, scale: 2)
    board.frame = NSRect(origin: .zero, size: board.intrinsicContentSize)
    let spy = InteractionSpy()
    board.interactionDelegate = spy
    return (board, spy)
}

@MainActor
func accessibilityCells(in board: ClassicBoardView) -> [BoardAccessibilityCell] {
    (board.accessibilityRows() as? [BoardAccessibilityRow])?.flatMap { row in
        row.accessibilityChildren() as? [BoardAccessibilityCell] ?? []
    } ?? []
}

@Test @MainActor func primaryGesturePreviewsCancelsRestoresAndRevealsOnce() {
    let (board, spy) = makeBoard()
    let origin = Coordinate(row: 2, column: 3)

    board.handlePress(.primary, at: origin)
    #expect(board.previewedCoordinates == [origin])
    board.handleDrag(to: nil)
    #expect(board.previewedCoordinates.isEmpty)
    board.handleDrag(to: origin)
    #expect(board.previewedCoordinates == [origin])
    board.handleRelease(.primary, at: origin)
    board.handleRelease(.primary, at: origin)

    #expect(spy.reveals == [origin])
    #expect(board.previewedCoordinates.isEmpty)
}

@Test @MainActor func secondaryGestureMarksOnlyOnceOnPress() {
    let (board, spy) = makeBoard()
    let origin = Coordinate(row: 1, column: 1)

    board.handlePress(.secondary, at: origin)
    board.handleDrag(to: nil)
    board.handleDrag(to: origin)
    board.handleRelease(.secondary, at: origin)

    #expect(spy.marks == [origin])
    #expect(spy.reveals.isEmpty)
}

@Test @MainActor func controlClickKeepsSecondaryIdentityWhenModifierChangesBeforeRelease() {
    let (board, spy) = makeBoard()
    let origin = Coordinate(row: 1, column: 1)
    board.handlePrimaryMouseDown(at: origin, control: true)
    board.handlePrimaryMouseUp(at: origin)
    board.handlePress(.primary, at: origin)
    board.handleRelease(.primary, at: origin)

    #expect(spy.marks == [origin])
    #expect(spy.reveals == [origin])
}

@Test @MainActor func chordAcceptsEitherButtonOrderAndTriggersOnce() {
    var game = MinesweeperGame(configuration: GamePreset.beginner.configuration, seed: 42)
    game.reveal(Coordinate(row: 4, column: 4), atNanoseconds: 0)
    let target = game.allCoordinates().first {
        game[$0].isRevealed && game[$0].adjacentMineCount > 0
    }!

    for order: [PointerButton] in [[.primary, .secondary], [.secondary, .primary]] {
        let (board, spy) = makeBoard(game: game)
        board.handlePress(order[0], at: target)
        board.handlePress(order[1], at: target)
        #expect(!board.previewedCoordinates.isEmpty)
        board.handleDrag(to: nil)
        #expect(board.previewedCoordinates.isEmpty)
        board.handleDrag(to: target)
        #expect(!board.previewedCoordinates.isEmpty)
        board.handleRelease(order[1], at: target)
        board.handleRelease(order[0], at: target)
        #expect(spy.chords == [target])
        #expect(spy.marks.isEmpty)
        #expect(spy.reveals.isEmpty)
    }
}

@Test @MainActor func releasingOutsideOrCancelingNeverExecutesAnAction() {
    let (board, spy) = makeBoard()
    let origin = Coordinate(row: 0, column: 0)
    board.handlePress(.primary, at: origin)
    board.handleRelease(.primary, at: nil)
    board.handlePress(.primary, at: origin)
    board.cancelPointerGesture()
    board.handleRelease(.primary, at: origin)

    #expect(spy.reveals.isEmpty)
    #expect(spy.marks.isEmpty)
    #expect(spy.chords.isEmpty)
}

@Test @MainActor func chordCannotRecoverAfterEitherButtonReleasesOutsideOrigin() {
    var game = MinesweeperGame(configuration: GamePreset.beginner.configuration, seed: 42)
    game.reveal(Coordinate(row: 4, column: 4), atNanoseconds: 0)
    let origin = game.allCoordinates().first { game[$0].isRevealed && game[$0].adjacentMineCount > 0 }!
    let (board, spy) = makeBoard(game: game)

    board.handlePress(.primary, at: origin)
    board.handlePress(.secondary, at: origin)
    board.handleRelease(.secondary, at: nil)
    board.handleDrag(to: origin)
    board.handleRelease(.primary, at: origin)

    #expect(spy.chords.isEmpty)
    #expect(board.previewedCoordinates.isEmpty)
}

@Test @MainActor func dirtyRectMapsOnlyToIntersectingCells() {
    let (board, _) = makeBoard()
    let coordinate = Coordinate(row: 3, column: 4)
    #expect(board.coordinates(intersecting: board.cellRect(for: coordinate)) == [coordinate])
    #expect(board.coordinates(intersecting: .zero).isEmpty)
}

@Test @MainActor func keyboardActionsIgnoreRepeatsAndFocusDoesNotWrap() throws {
    let (board, spy) = makeBoard()
    board.focusedCoordinate = Coordinate(row: 0, column: 0)

    let repeatedF = try #require(NSEvent.keyEvent(
        with: .keyDown,
        location: .zero,
        modifierFlags: [],
        timestamp: 0,
        windowNumber: 0,
        context: nil,
        characters: "f",
        charactersIgnoringModifiers: "f",
        isARepeat: true,
        keyCode: 3
    ))
    board.keyDown(with: repeatedF)
    #expect(spy.marks.isEmpty)

    let left = try #require(NSEvent.keyEvent(
        with: .keyDown,
        location: .zero,
        modifierFlags: [],
        timestamp: 0,
        windowNumber: 0,
        context: nil,
        characters: "",
        charactersIgnoringModifiers: "",
        isARepeat: true,
        keyCode: 123
    ))
    board.keyDown(with: left)
    #expect(board.focusedCoordinate == Coordinate(row: 0, column: 0))
}

@Test @MainActor func virtualAccessibilityGridHasStableCellsValuesAndActions() {
    let (board, spy) = makeBoard()
    let rows = board.accessibilityRows() as? [BoardAccessibilityRow]
    let columns = board.accessibilityColumns() as? [BoardAccessibilityColumn]
    #expect(board.accessibilityRowCount() == 9)
    #expect(board.accessibilityColumnCount() == 9)
    #expect(rows?.count == 9)
    #expect(columns?.count == 9)
    #expect((board.accessibilityChildren() as? [BoardAccessibilityRow])?.count == 9)
    let firstChildren = accessibilityCells(in: board)
    #expect(firstChildren.count == 81)
    let first = firstChildren.first
    #expect(first?.accessibilityParent() as AnyObject? === rows?.first)
    #expect(first?.accessibilityIdentifier() == "cell-0-0")
    #expect(first?.accessibilityLabel() == "Row 1, column 1")
    #expect(first?.accessibilityValue() as? String == "Covered")
    #expect(first?.accessibilityCustomActions()?.map(\.name) == ["Reveal", "Toggle mark"])

    _ = first?.accessibilityPerformPress()
    #expect(spy.reveals == [Coordinate(row: 0, column: 0)])

    board.apply(game: board.game, changedCoordinates: [])
    let secondChildren = accessibilityCells(in: board)
    #expect(first === secondChildren.first)

    let last = secondChildren.last
    last?.setAccessibilityFocused(true)
    #expect(board.focusedCoordinate == Coordinate(row: 8, column: 8))
}

@Test @MainActor func flaggedAccessibilityCellOnlyTogglesAndNeverReportsRevealSuccess() async throws {
    var game = MinesweeperGame(configuration: GamePreset.beginner.configuration, seed: 42)
    let coordinate = Coordinate(row: 0, column: 0)
    _ = game.toggleMark(at: coordinate)
    let (board, spy) = makeBoard(game: game)
    let cell = try #require(accessibilityCells(in: board).first)
    let box = SendableAccessibilityCellBox(cell)

    #expect(cell.accessibilityCustomActions()?.map(\.name) == ["Toggle mark"])
    let revealResult = await Task.detached { box.cell.performReveal() }.value
    #expect(revealResult == false)
    #expect(spy.reveals.isEmpty)

    let defaultResult = await Task.detached { box.cell.accessibilityPerformPress() }.value
    #expect(defaultResult)
    #expect(spy.marks == [coordinate])
}

@Test @MainActor func accessibilityGridRebuildsForEqualAreaShapeChanges() throws {
    let firstConfiguration = try GameConfiguration(columns: 9, rows: 16, mineCount: 20)
    let secondConfiguration = try GameConfiguration(columns: 12, rows: 12, mineCount: 20)
    let firstGame = MinesweeperGame(configuration: firstConfiguration, seed: 1)
    let board = ClassicBoardView(game: firstGame, scale: 1)
    board.focusedCoordinate = Coordinate(row: 15, column: 8)
    let oldLast = accessibilityCells(in: board).last

    let secondGame = MinesweeperGame(configuration: secondConfiguration, seed: 2)
    board.apply(game: secondGame, changedCoordinates: [])
    let children = accessibilityCells(in: board)

    #expect(board.accessibilityRowCount() == 12)
    #expect(board.accessibilityColumnCount() == 12)
    #expect(children.count == 144)
    #expect(children.last?.accessibilityIdentifier() == "cell-11-11")
    #expect(board.focusedCoordinate == Coordinate(row: 0, column: 0))
    _ = oldLast?.accessibilityPerformPress()
}

@Test @MainActor func newGameAndSheetsCancelInFlightPointerState() throws {
    let controller = try ClassicGameWindowController.make()
    controller.showWindow(nil)
    let board = controller.boardViewForTesting
    let coordinate = Coordinate(row: 0, column: 0)

    board.handlePress(.primary, at: coordinate)
    #expect(board.previewedCoordinates == [coordinate])
    controller.newGame(nil)
    #expect(board.previewedCoordinates.isEmpty)
    board.handleRelease(.primary, at: coordinate)
    #expect(controller.gameForTesting.status == .ready)

    board.handlePress(.primary, at: coordinate)
    board.handleRelease(.primary, at: coordinate)
    #expect(controller.gameForTesting.status == .playing)
    let covered = try #require(controller.gameForTesting.allCoordinates().first {
        !controller.gameForTesting[$0].isRevealed
    })
    board.focusedCoordinate = covered
    let markBefore = controller.gameForTesting[covered].mark
    let marksEnabledBefore = controller.gameForTesting.marksEnabled

    board.handlePress(.primary, at: covered)
    controller.showRules(nil)
    #expect(board.previewedCoordinates.isEmpty)
    #expect(controller.modalInputBlockedForTesting)
    #expect(!board.inputEnabled)
    #expect(accessibilityCells(in: board).allSatisfy { $0.accessibilityCustomActions()?.isEmpty == true })
    let coveredElement = try #require(accessibilityCells(in: board).first {
        $0.coordinate == covered
    })
    #expect(!coveredElement.accessibilityPerformPress())

    let markKey = try #require(NSEvent.keyEvent(
        with: .keyDown,
        location: .zero,
        modifierFlags: [],
        timestamp: 0,
        windowNumber: 0,
        context: nil,
        characters: "f",
        charactersIgnoringModifiers: "f",
        isARepeat: false,
        keyCode: 3
    ))
    board.keyDown(with: markKey)
    controller.toggleMarks(nil)
    controller.newGame(nil)
    board.handleRelease(.primary, at: covered)
    #expect(controller.gameForTesting.status == .playing)
    #expect(controller.gameForTesting[covered].mark == markBefore)
    #expect(controller.gameForTesting.marksEnabled == marksEnabledBefore)

    let newItem = NSMenuItem(
        title: "New",
        action: #selector(ClassicGameWindowController.newGame(_:)),
        keyEquivalent: "n"
    )
    #expect(!controller.validateMenuItem(newItem))
    if let sheet = controller.window?.attachedSheet {
        controller.window?.endSheet(sheet)
    }
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
    #expect(!controller.modalInputBlockedForTesting)
    #expect(board.inputEnabled)
    controller.close()
}

@Test @MainActor func windowForcesClassicAquaAppearance() throws {
    let controller = try ClassicGameWindowController.make()
    #expect(controller.window?.appearance?.name == .aqua)
    #expect(controller.window?.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .aqua)
}

    @Test @MainActor func accessibilityNotificationsCollapseBatchChanges() {
    #expect(ClassicBoardView.accessibilityChangeScope(for: 0) == .none)
    #expect(ClassicBoardView.accessibilityChangeScope(for: 1) == .single)
    #expect(ClassicBoardView.accessibilityChangeScope(for: 2) == .batch)
    #expect(ClassicBoardView.accessibilityChangeScope(for: 720) == .batch)
}

@Test @MainActor func faceButtonRestartsOnlyWhenReleasedInside() {
    let hud = ClassicHUDView(frame: NSRect(x: 0, y: 0, width: 144, height: 40))
    var restartCount = 0
    hud.onRestart = { restartCount += 1 }

    hud.handleFacePress(at: NSPoint(x: 72, y: 20))
    hud.handleFaceDrag(to: NSPoint(x: 0, y: 0))
    hud.handleFaceRelease(at: NSPoint(x: 0, y: 0))
    #expect(restartCount == 0)

    hud.handleFacePress(at: NSPoint(x: 72, y: 20))
    hud.handleFaceRelease(at: NSPoint(x: 72, y: 20))
    #expect(restartCount == 1)

    hud.handleFacePress(at: NSPoint(x: 0, y: 0))
    hud.handleFaceDrag(to: NSPoint(x: 72, y: 20))
    hud.handleFaceRelease(at: NSPoint(x: 72, y: 20))
    #expect(restartCount == 1)
}

@Test @MainActor func preferencesRoundTripAndRejectCorruptRecords() throws {
    let suite = "ClassicMinesUITests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }

    let store = PreferencesStore(defaults: defaults)
    store.scale = 3
    store.marksEnabled = false
    store.playerName = "Tester"
    let accepted = store.bestTimes.submit(
        CompletedGame(preset: .beginner, seconds: 12),
        name: "Tester"
    )
    #expect(accepted)
    store.savePreferences()
    store.saveBestTimes()

    let loaded = PreferencesStore(defaults: defaults)
    #expect(loaded.scale == 3)
    #expect(!loaded.marksEnabled)
    #expect(loaded.playerName == "Tester")
    #expect(loaded.bestTimes.records[.beginner]?.seconds == 12)

    defaults.set(Data("not-json".utf8), forKey: "bestTimes")
    let recovered = PreferencesStore(defaults: defaults)
    #expect(recovered.bestTimes.records.isEmpty)
}

@Test @MainActor func newGamesInheritTheMarksPreference() throws {
    let game = try ClassicGameWindowController.makeGame(
        configuration: GamePreset.expert.configuration,
        marksEnabled: false
    )
    #expect(!game.marksEnabled)
}

#if !DEBUG
@Test @MainActor func realMarkInputModelAccessibilityAndDirtyDrawMeetBudget() throws {
    let game = MinesweeperGame(configuration: GamePreset.expert.configuration, seed: 42)
    let board = ClassicBoardView(game: game, scale: 2)
    board.frame = NSRect(origin: .zero, size: board.intrinsicContentSize)
    let delegate = ApplyingMarkDelegate(game: game)
    board.interactionDelegate = delegate
    let bitmap = try #require(NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(board.bounds.width),
        pixelsHigh: Int(board.bounds.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ))
    let graphics = try #require(NSGraphicsContext(bitmapImageRep: bitmap))
    let coordinate = Coordinate(row: 8, column: 15)
    let dirtyRect = board.cellRect(for: coordinate)
    let clock = ContinuousClock()
    var samples: [UInt64] = []

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    board.draw(board.bounds)
    for iteration in 0..<520 {
        let start = clock.now
        board.handlePress(.secondary, at: coordinate)
        board.handleRelease(.secondary, at: coordinate)
        graphics.saveGraphicsState()
        graphics.cgContext.clip(to: dirtyRect)
        board.draw(dirtyRect)
        graphics.restoreGraphicsState()
        let components = start.duration(to: clock.now).components
        if iteration >= 20 {
            samples.append(
                UInt64(components.seconds) * 1_000_000_000
                    + UInt64(components.attoseconds / 1_000_000_000)
            )
        }
    }
    NSGraphicsContext.restoreGraphicsState()
    samples.sort()
    #expect(samples[(samples.count * 95) / 100] <= 4_000_000)
    #expect(samples[(samples.count * 99) / 100] <= 8_000_000)
}

@Test @MainActor func pointerStateMachineMeetsInputBudget() {
    let (board, _) = makeBoard()
    let coordinate = Coordinate(row: 0, column: 0)
    let clock = ContinuousClock()
    var samples: [UInt64] = []

    for iteration in 0..<520 {
        let start = clock.now
        board.handlePress(.primary, at: coordinate)
        board.handleRelease(.primary, at: coordinate)
        let components = start.duration(to: clock.now).components
        if iteration >= 20 {
            samples.append(
                UInt64(components.seconds) * 1_000_000_000
                    + UInt64(components.attoseconds / 1_000_000_000)
            )
        }
    }
    samples.sort()
    #expect(samples[(samples.count * 95) / 100] <= 4_000_000)
    #expect(samples[(samples.count * 99) / 100] <= 8_000_000)
}
#endif

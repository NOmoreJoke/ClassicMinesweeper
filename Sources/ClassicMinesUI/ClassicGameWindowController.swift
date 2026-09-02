import AppKit
import GameCore

@MainActor
public final class ClassicGameWindowController: NSWindowController, NSMenuItemValidation, ClassicBoardInteractionDelegate {
    private var game: MinesweeperGame
    private var scale: Int
    private let gameView: ClassicGameView
    private let preferences: PreferencesStore
    private var refreshTimer: Timer?
    private var reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    private var modalInputBlocked = false

    public static func make() throws -> ClassicGameWindowController {
        let preferences = PreferencesStore()
        let game = try makeGame(
            configuration: GamePreset.beginner.configuration,
            marksEnabled: preferences.marksEnabled
        )
        return ClassicGameWindowController(
            initialGame: game,
            preferences: preferences
        )
    }

    static func makeGame(configuration: GameConfiguration, marksEnabled: Bool) throws -> MinesweeperGame {
        var game = try MinesweeperGame(configuration: configuration)
        game.setMarksEnabled(marksEnabled)
        return game
    }

    private init(initialGame: MinesweeperGame, preferences: PreferencesStore) {
        game = initialGame
        self.preferences = preferences
        scale = preferences.scale
        gameView = ClassicGameView(game: game, scale: scale, commandTarget: nil)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: gameView.frame.size),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = BuildInfo.productName
        window.appearance = NSAppearance(named: .aqua)
        window.isReleasedWhenClosed = false
        window.backgroundColor = ClassicPalette.panel
        window.contentView = gameView
        super.init(window: window)
        gameView.setCommandTarget(self)
        gameView.boardView.interactionDelegate = self
        gameView.hudView.onRestart = { [weak self] in self?.newGame(nil) }
        window.initialFirstResponder = gameView.boardView
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cancelPointerGesture(_:)),
            name: NSWindow.didResignKeyNotification,
            object: window
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cancelPointerGesture(_:)),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilityDisplayOptionsChanged(_:)),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil
        )
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    @objc public func newGame(_ sender: Any?) {
        guard !modalInputBlocked else { return }
        replaceGame(configuration: game.configuration)
    }

    @objc public func selectBeginner(_ sender: Any?) {
        guard !modalInputBlocked else { return }
        replaceGame(configuration: GamePreset.beginner.configuration)
    }

    @objc public func selectIntermediate(_ sender: Any?) {
        guard !modalInputBlocked else { return }
        replaceGame(configuration: GamePreset.intermediate.configuration)
    }

    @objc public func selectExpert(_ sender: Any?) {
        guard !modalInputBlocked else { return }
        replaceGame(configuration: GamePreset.expert.configuration)
    }

    @objc public func toggleMarks(_ sender: Any?) {
        guard !modalInputBlocked else { return }
        game.setMarksEnabled(!game.marksEnabled)
        preferences.marksEnabled = game.marksEnabled
        preferences.savePreferences()
        gameView.update(game: game, scale: scale)
    }

    @objc public func selectScale1(_ sender: Any?) { if !modalInputBlocked { applyScale(1) } }
    @objc public func selectScale2(_ sender: Any?) { if !modalInputBlocked { applyScale(2) } }
    @objc public func selectScale3(_ sender: Any?) { if !modalInputBlocked { applyScale(3) } }

    @objc public func showRules(_ sender: Any?) {
        guard !modalInputBlocked else { return }
        showSheet(
            title: "Rules",
            message: "Reveal every safe square. Right-click to place a flag. Press both mouse buttons on a number to reveal its neighbors when the flag count matches."
        )
    }

    @objc public func showAbout(_ sender: Any?) {
        guard !modalInputBlocked else { return }
        showSheet(title: "Classic Mines", message: "A local, offline, ad-free classic minesweeper for macOS.")
    }

    @objc public func showCustomGame(_ sender: Any?) {
        guard !modalInputBlocked else { return }
        let columns = NSTextField(string: "16")
        let rows = NSTextField(string: "16")
        let mines = NSTextField(string: "40")
        let grid = NSGridView(views: [
            [NSTextField(labelWithString: "Columns (9–30)"), columns],
            [NSTextField(labelWithString: "Rows (9–24)"), rows],
            [NSTextField(labelWithString: "Mines"), mines],
        ])
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 1).width = 90

        let alert = NSAlert()
        alert.messageText = "Custom Game"
        alert.accessoryView = grid
        alert.addButton(withTitle: "Start")
        alert.addButton(withTitle: "Cancel")
        presentSheet(alert) { [weak self] response in
            guard response == .alertFirstButtonReturn,
                  let columnCount = Int(columns.stringValue),
                  let rowCount = Int(rows.stringValue),
                  let mineCount = Int(mines.stringValue),
                  let configuration = try? GameConfiguration(
                      columns: columnCount,
                      rows: rowCount,
                      mineCount: mineCount
                  ) else {
                if response == .alertFirstButtonReturn {
                    self?.showSheet(title: "Invalid Board", message: "Use columns 9–30, rows 9–24, and no more than cells minus 9 mines.")
                }
                return
            }
            self?.replaceGame(configuration: configuration)
        }
    }

    @objc public func showBestTimes(_ sender: Any?) {
        guard !modalInputBlocked else { return }
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 520, height: 320))
        textView.string = Self.recordsMessage(
            bestTimes: preferences.bestTimes,
            history: preferences.completionHistory
        )
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        let scrollView = NSScrollView(frame: textView.frame)
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        let alert = NSAlert()
        alert.messageText = "Records"
        alert.informativeText = "Best times and local completion history"
        alert.accessoryView = scrollView
        alert.addButton(withTitle: "OK")
        presentSheet(alert)
    }

    static func recordsMessage(
        bestTimes: BestTimes,
        history: CompletionHistory,
        dateFormatter: DateFormatter? = nil
    ) -> String {
        let bestLines = GamePreset.allCases.map { preset -> String in
            let title = preset.rawValue.capitalized
            if let record = bestTimes.records[preset] {
                return "\(title): \(record.seconds)s — \(record.name)"
            }
            return "\(title): —"
        }
        let formatter = dateFormatter ?? {
            let value = DateFormatter()
            value.dateStyle = .short
            value.timeStyle = .short
            return value
        }()
        let recentLines = history.records.map { record in
            let board = record.configuration.preset?.rawValue.capitalized
                ?? "\(record.configuration.dimensions.columns)×\(record.configuration.dimensions.rows)/\(record.configuration.mineCount)"
            return "\(formatter.string(from: record.completedAt)) · \(board) · \(record.seconds)s · \(record.name)"
        }
        return (["Best Times"] + bestLines + ["", "Recent Wins"]
            + (recentLines.isEmpty ? ["—"] : recentLines))
            .joined(separator: "\n")
    }

    @objc public func resetRecords(_ sender: Any?) {
        guard !modalInputBlocked else { return }
        let alert = NSAlert()
        alert.messageText = "Reset Best Times?"
        alert.informativeText = "This removes all best times and local completion history."
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        presentSheet(alert) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            self?.preferences.bestTimes.reset()
            self?.preferences.completionHistory.reset()
            self?.preferences.saveBestTimes()
            self?.preferences.saveCompletionHistory()
        }
    }

    @objc public func showPreferences(_ sender: Any?) {
        guard !modalInputBlocked else { return }
        let nameField = NSTextField(string: preferences.playerName)
        nameField.frame.size = NSSize(width: 200, height: 24)
        let alert = NSAlert()
        alert.messageText = "Preferences"
        alert.informativeText = "Name used for local best times"
        alert.accessoryView = nameField
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        presentSheet(alert) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            self?.preferences.playerName = name.isEmpty ? NSUserName() : name
            self?.preferences.savePreferences()
        }
    }

    public func boardView(_ boardView: ClassicBoardView, reveal coordinate: Coordinate) {
        guard !modalInputBlocked else { return }
        let previous = game.status
        let change = game.reveal(coordinate)
        apply(change: change, previousStatus: previous)
    }

    public func boardView(_ boardView: ClassicBoardView, toggleMark coordinate: Coordinate) {
        guard !modalInputBlocked else { return }
        let previous = game.status
        let change = game.toggleMark(at: coordinate)
        apply(change: change, previousStatus: previous)
    }

    public func boardView(_ boardView: ClassicBoardView, chord coordinate: Coordinate) {
        guard !modalInputBlocked else { return }
        let previous = game.status
        let change = game.chord(at: coordinate)
        apply(change: change, previousStatus: previous)
    }

    public func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if modalInputBlocked, Self.gameChangingActions.contains(menuItem.action) {
            return false
        }
        switch menuItem.action {
        case #selector(toggleMarks(_:)):
            menuItem.state = game.marksEnabled ? .on : .off
        case #selector(selectBeginner(_:)):
            menuItem.state = game.configuration.preset == .beginner ? .on : .off
        case #selector(selectIntermediate(_:)):
            menuItem.state = game.configuration.preset == .intermediate ? .on : .off
        case #selector(selectExpert(_:)):
            menuItem.state = game.configuration.preset == .expert ? .on : .off
        case #selector(selectScale1(_:)):
            menuItem.state = scale == 1 ? .on : .off
        case #selector(selectScale2(_:)):
            menuItem.state = scale == 2 ? .on : .off
        case #selector(selectScale3(_:)):
            menuItem.state = scale == 3 ? .on : .off
        default:
            break
        }
        return menuItem.isEnabled
    }

    private func replaceGame(configuration: GameConfiguration) {
        gameView.boardView.cancelPointerGesture()
        do {
            game = try Self.makeGame(
                configuration: configuration,
                marksEnabled: preferences.marksEnabled
            )
            refreshTimer?.invalidate()
            refreshTimer = nil
            applyCurrentState()
        } catch {
            showSheet(title: "New Game Failed", message: "A secure local game seed could not be created.")
        }
    }

    private func applyScale(_ candidate: Int) {
        let layout = ClassicLayout(configuration: game.configuration, scale: candidate)
        if let screen = window?.screen,
           layout.contentSize.width > screen.visibleFrame.width || layout.contentSize.height > screen.visibleFrame.height {
            NSSound.beep()
            return
        }
        scale = candidate
        preferences.scale = scale
        preferences.savePreferences()
        applyCurrentState()
    }

    private func applyCurrentState() {
        if let visibleFrame = window?.screen?.visibleFrame ?? NSScreen.main?.visibleFrame {
            scale = ClassicLayout.largestFittingScale(
                configuration: game.configuration,
                preferred: scale,
                visibleSize: visibleFrame.size
            )
        }
        let layout = ClassicLayout(configuration: game.configuration, scale: scale)
        gameView.update(game: game, scale: scale)
        window?.setContentSize(layout.contentSize)
        window?.center()
    }

    private func apply(change: GameChange, previousStatus: GameStatus) {
        gameView.updateGame(game, changedCoordinates: change.changedCoordinates)
        if previousStatus == .ready && game.status == .playing {
            startRefreshTimer()
        }
        if !previousStatus.isTerminal && game.status.isTerminal {
            refreshTimer?.invalidate()
            refreshTimer = nil
            switch game.status {
            case .won:
                preferences.addCompletion(
                    configuration: game.configuration,
                    seconds: game.elapsedSeconds(),
                    name: preferences.playerName
                )
                if let result = game.completedGame(),
                   preferences.bestTimes.submit(result, name: preferences.playerName) {
                    preferences.saveBestTimes()
                }
                gameView.boardView.announce("Victory, \(game.elapsedSeconds()) seconds")
            case .lost:
                gameView.boardView.announce("Mine hit, game over")
            case .ready, .playing:
                break
            }
        }
    }

    private func startRefreshTimer() {
        guard refreshTimer == nil else { return }
        refreshTimer = Timer.scheduledTimer(
            timeInterval: 0.2,
            target: self,
            selector: #selector(refreshTimerFired(_:)),
            userInfo: nil,
            repeats: true
        )
    }

    @objc private func refreshTimerFired(_ timer: Timer) {
        gameView.refresh()
    }

    @objc private func cancelPointerGesture(_ notification: Notification) {
        gameView.boardView.cancelPointerGesture()
    }

    @objc private func accessibilityDisplayOptionsChanged(_ notification: Notification) {
        reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        gameView.boardView.needsDisplay = true
    }

    private func showSheet(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        presentSheet(alert)
    }

    var boardViewForTesting: ClassicBoardView { gameView.boardView }
    var gameForTesting: MinesweeperGame { game }
    var modalInputBlockedForTesting: Bool { modalInputBlocked }

    private func presentSheet(_ alert: NSAlert, completion: ((NSApplication.ModalResponse) -> Void)? = nil) {
        guard let window, !modalInputBlocked else { return }
        modalInputBlocked = true
        gameView.boardView.inputEnabled = false
        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self else { return }
            modalInputBlocked = false
            gameView.boardView.inputEnabled = true
            completion?(response)
        }
    }

    private static let gameChangingActions: Set<Selector?> = [
        #selector(newGame(_:)), #selector(selectBeginner(_:)), #selector(selectIntermediate(_:)),
        #selector(selectExpert(_:)), #selector(showCustomGame(_:)), #selector(toggleMarks(_:)),
        #selector(selectScale1(_:)), #selector(selectScale2(_:)), #selector(selectScale3(_:)),
        #selector(resetRecords(_:)), #selector(showPreferences(_:)),
    ]
}

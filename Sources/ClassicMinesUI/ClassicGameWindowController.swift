import AppKit
import GameCore

@MainActor
public final class ClassicGameWindowController: NSWindowController, NSMenuItemValidation {
    private var game: MinesweeperGame
    private var scale = 2
    private let gameView: ClassicGameView

    public static func make() throws -> ClassicGameWindowController {
        ClassicGameWindowController(
            initialGame: try MinesweeperGame(configuration: GamePreset.beginner.configuration)
        )
    }

    private init(initialGame: MinesweeperGame) {
        game = initialGame
        gameView = ClassicGameView(game: game, scale: scale, commandTarget: nil)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: gameView.frame.size),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = BuildInfo.productName
        window.isReleasedWhenClosed = false
        window.backgroundColor = ClassicPalette.panel
        window.contentView = gameView
        super.init(window: window)
        gameView.setCommandTarget(self)
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    @objc public func newGame(_ sender: Any?) {
        replaceGame(configuration: game.configuration)
    }

    @objc public func selectBeginner(_ sender: Any?) {
        replaceGame(configuration: GamePreset.beginner.configuration)
    }

    @objc public func selectIntermediate(_ sender: Any?) {
        replaceGame(configuration: GamePreset.intermediate.configuration)
    }

    @objc public func selectExpert(_ sender: Any?) {
        replaceGame(configuration: GamePreset.expert.configuration)
    }

    @objc public func toggleMarks(_ sender: Any?) {
        game.setMarksEnabled(!game.marksEnabled)
        gameView.update(game: game, scale: scale)
    }

    @objc public func selectScale1(_ sender: Any?) { applyScale(1) }
    @objc public func selectScale2(_ sender: Any?) { applyScale(2) }
    @objc public func selectScale3(_ sender: Any?) { applyScale(3) }

    @objc public func showRules(_ sender: Any?) {
        showSheet(
            title: "Rules",
            message: "Reveal every safe square. Right-click to place a flag. Press both mouse buttons on a number to reveal its neighbors when the flag count matches."
        )
    }

    @objc public func showAbout(_ sender: Any?) {
        showSheet(title: "Classic Mines", message: "A local, offline, ad-free classic minesweeper for macOS.")
    }

    public func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
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
        do {
            game = try MinesweeperGame(configuration: configuration)
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

    private func showSheet(title: String, message: String) {
        guard let window else { return }
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: window)
    }
}

import AppKit

@MainActor
final class ClassicMenuBarView: NSView {
    weak var commandTarget: AnyObject?
    var scale = 1 { didSet { needsLayout = true } }

    private lazy var gameButton = makeButton(title: "Game", action: #selector(showGameMenu(_:)))
    private lazy var helpButton = makeButton(title: "Help", action: #selector(showHelpMenu(_:)))

    override var isFlipped: Bool { true }

    init(commandTarget: AnyObject?) {
        self.commandTarget = commandTarget
        super.init(frame: .zero)
        addSubview(gameButton)
        addSubview(helpButton)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func draw(_ dirtyRect: NSRect) {
        ClassicPalette.panel.setFill()
        dirtyRect.fill()
    }

    override func layout() {
        super.layout()
        let width = CGFloat(46 * scale)
        gameButton.frame = NSRect(x: CGFloat(4 * scale), y: 0, width: width, height: bounds.height)
        helpButton.frame = NSRect(x: CGFloat(50 * scale), y: 0, width: width, height: bounds.height)
        for button in [gameButton, helpButton] {
            button.font = .systemFont(ofSize: CGFloat(11 * scale))
        }
    }

    @objc private func showGameMenu(_ sender: NSButton) {
        popUp(ClassicMenuFactory.gameMenu(target: commandTarget), from: sender)
    }

    @objc private func showHelpMenu(_ sender: NSButton) {
        popUp(ClassicMenuFactory.helpMenu(target: commandTarget), from: sender)
    }

    private func popUp(_ menu: NSMenu, from button: NSButton) {
        menu.popUp(positioning: nil, at: NSPoint(x: button.frame.minX, y: button.frame.maxY), in: self)
    }

    private func makeButton(title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.isBordered = false
        button.alignment = .left
        button.setButtonType(.momentaryPushIn)
        return button
    }
}


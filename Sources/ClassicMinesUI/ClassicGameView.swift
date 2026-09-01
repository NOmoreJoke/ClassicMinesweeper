import AppKit
import GameCore

@MainActor
public final class ClassicGameView: NSView {
    public private(set) var game: MinesweeperGame
    public private(set) var scale: Int
    public let boardView: ClassicBoardView
    public let hudView = ClassicHUDView(frame: .zero)

    private let menuBarView: ClassicMenuBarView

    var menuScaleForTesting: Int { menuBarView.scale }

    public override var isFlipped: Bool { true }

    public init(game: MinesweeperGame, scale: Int, commandTarget: AnyObject?) {
        self.game = game
        self.scale = scale
        boardView = ClassicBoardView(game: game, scale: scale)
        menuBarView = ClassicMenuBarView(commandTarget: commandTarget)
        super.init(frame: NSRect(origin: .zero, size: ClassicLayout(configuration: game.configuration, scale: scale).contentSize))
        wantsLayer = true
        layer?.backgroundColor = ClassicPalette.panel.cgColor
        addSubview(menuBarView)
        addSubview(hudView)
        addSubview(boardView)
        boardView.pressingStateDidChange = { [weak hudView] isPressing in
            hudView?.isPressingBoard = isPressing
        }
        menuBarView.scale = scale
        hudView.scale = scale
        refresh()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    public func update(game: MinesweeperGame, scale: Int) {
        self.game = game
        self.scale = scale
        boardView.game = game
        boardView.scale = scale
        menuBarView.scale = scale
        hudView.scale = scale
        frame.size = ClassicLayout(configuration: game.configuration, scale: scale).contentSize
        needsLayout = true
        refresh()
    }

    public func setCommandTarget(_ target: AnyObject?) {
        menuBarView.commandTarget = target
    }

    public func updateGame(_ game: MinesweeperGame, changedCoordinates: Set<Coordinate>) {
        precondition(game.configuration == self.game.configuration)
        self.game = game
        boardView.apply(game: game, changedCoordinates: changedCoordinates)
        refresh()
    }

    public func refresh(nowNanoseconds: UInt64 = ContinuousTime.nowNanoseconds()) {
        hudView.remainingMines = game.remainingMineCount
        hudView.elapsedSeconds = game.elapsedSeconds(atNanoseconds: nowNanoseconds)
        hudView.gameStatus = game.status
    }

    public override func layout() {
        super.layout()
        let layout = ClassicLayout(configuration: game.configuration, scale: scale)
        menuBarView.frame = layout.menuFrame
        hudView.frame = layout.hudFrame
        boardView.frame = layout.boardFrame
    }
}

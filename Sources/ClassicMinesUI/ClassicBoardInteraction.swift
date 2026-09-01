import GameCore

@MainActor
public protocol ClassicBoardInteractionDelegate: AnyObject {
    func boardView(_ boardView: ClassicBoardView, reveal coordinate: Coordinate)
    func boardView(_ boardView: ClassicBoardView, toggleMark coordinate: Coordinate)
    func boardView(_ boardView: ClassicBoardView, chord coordinate: Coordinate)
}

enum PointerButton: Equatable {
    case primary
    case secondary
}

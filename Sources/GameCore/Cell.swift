public enum CellMark: String, Sendable, Codable {
    case none
    case flag
    case question
}

public struct Cell: Equatable, Sendable, Codable {
    public internal(set) var isMine = false
    public internal(set) var adjacentMineCount: UInt8 = 0
    public internal(set) var isRevealed = false
    public internal(set) var mark: CellMark = .none

    public init() {}
}

public struct Coordinate: Hashable, Comparable, Sendable, Codable {
    public let row: Int
    public let column: Int

    public init(row: Int, column: Int) {
        self.row = row
        self.column = column
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.row == rhs.row ? lhs.column < rhs.column : lhs.row < rhs.row
    }

    public func neighbors(in dimensions: BoardDimensions) -> [Coordinate] {
        let rows = max(0, row - 1)...min(dimensions.rows - 1, row + 1)
        let columns = max(0, column - 1)...min(dimensions.columns - 1, column + 1)

        return rows.flatMap { neighborRow in
            columns.compactMap { neighborColumn in
                let candidate = Coordinate(row: neighborRow, column: neighborColumn)
                return candidate == self ? nil : candidate
            }
        }
    }
}


public struct BoardDimensions: Hashable, Sendable, Codable {
    public let columns: Int
    public let rows: Int

    public var cellCount: Int { columns * rows }

    public init(columns: Int, rows: Int) throws {
        guard (9...30).contains(columns), (9...24).contains(rows) else {
            throw GameConfigurationError.invalidDimensions
        }
        self.columns = columns
        self.rows = rows
    }

    public func contains(_ coordinate: Coordinate) -> Bool {
        (0..<rows).contains(coordinate.row) && (0..<columns).contains(coordinate.column)
    }

    private enum CodingKeys: String, CodingKey {
        case columns
        case rows
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            columns: values.decode(Int.self, forKey: .columns),
            rows: values.decode(Int.self, forKey: .rows)
        )
    }
}

public enum GamePreset: String, CaseIterable, Hashable, Sendable, Codable {
    case beginner
    case intermediate
    case expert

    public var configuration: GameConfiguration {
        switch self {
        case .beginner:
            return try! GameConfiguration(columns: 9, rows: 9, mineCount: 10, preset: self)
        case .intermediate:
            return try! GameConfiguration(columns: 16, rows: 16, mineCount: 40, preset: self)
        case .expert:
            return try! GameConfiguration(columns: 30, rows: 16, mineCount: 99, preset: self)
        }
    }

    func matches(columns: Int, rows: Int, mineCount: Int) -> Bool {
        switch self {
        case .beginner: columns == 9 && rows == 9 && mineCount == 10
        case .intermediate: columns == 16 && rows == 16 && mineCount == 40
        case .expert: columns == 30 && rows == 16 && mineCount == 99
        }
    }
}

public struct GameConfiguration: Hashable, Sendable, Codable {
    public let dimensions: BoardDimensions
    public let mineCount: Int
    public let preset: GamePreset?

    public init(columns: Int, rows: Int, mineCount: Int) throws {
        try self.init(columns: columns, rows: rows, mineCount: mineCount, preset: nil)
    }

    init(columns: Int, rows: Int, mineCount: Int, preset: GamePreset?) throws {
        let dimensions = try BoardDimensions(columns: columns, rows: rows)
        guard (1...(dimensions.cellCount - 9)).contains(mineCount) else {
            throw GameConfigurationError.invalidMineCount
        }
        if let preset, !preset.matches(columns: columns, rows: rows, mineCount: mineCount) {
            throw GameConfigurationError.presetMismatch
        }
        self.dimensions = dimensions
        self.mineCount = mineCount
        self.preset = preset
    }

    private enum CodingKeys: String, CodingKey {
        case dimensions
        case mineCount
        case preset
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let dimensions = try values.decode(BoardDimensions.self, forKey: .dimensions)
        let mineCount = try values.decode(Int.self, forKey: .mineCount)
        let preset = try values.decodeIfPresent(GamePreset.self, forKey: .preset)
        try self.init(
            columns: dimensions.columns,
            rows: dimensions.rows,
            mineCount: mineCount,
            preset: preset
        )
    }
}

public enum GameConfigurationError: Error, Equatable, Sendable {
    case invalidDimensions
    case invalidMineCount
    case presetMismatch
}

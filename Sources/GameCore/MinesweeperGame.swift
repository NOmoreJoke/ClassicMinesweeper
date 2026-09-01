public enum GameStatus: Equatable, Sendable {
    case ready
    case playing
    case won
    case lost(exploded: Coordinate)

    public var isTerminal: Bool {
        switch self {
        case .won, .lost: true
        case .ready, .playing: false
        }
    }
}

public struct GameChange: Equatable, Sendable {
    public let changedCoordinates: Set<Coordinate>
    public let status: GameStatus

    public init(changedCoordinates: Set<Coordinate>, status: GameStatus) {
        self.changedCoordinates = changedCoordinates
        self.status = status
    }
}

public struct CompletedGame: Equatable, Sendable {
    public let preset: GamePreset
    public let seconds: Int

    init(preset: GamePreset, seconds: Int) {
        self.preset = preset
        self.seconds = seconds
    }
}

public struct MinesweeperGame: Sendable {
    public let configuration: GameConfiguration
    public private(set) var status: GameStatus = .ready
    public private(set) var marksEnabled = true
    public private(set) var isGenerated = false
    public private(set) var timer = GameTimer()

    private let seed: UInt64
    private let isOfficialSeed: Bool
    private var cells: [Cell]
    private var revealedSafeCellCount = 0

    public init(configuration: GameConfiguration) throws {
        self.init(configuration: configuration, seed: try SecureSeed.generate(), isOfficialSeed: true)
    }

    init(configuration: GameConfiguration, seed: UInt64) {
        self.init(configuration: configuration, seed: seed, isOfficialSeed: false)
    }

    private init(configuration: GameConfiguration, seed: UInt64, isOfficialSeed: Bool) {
        self.configuration = configuration
        self.seed = seed
        self.isOfficialSeed = isOfficialSeed
        cells = Array(repeating: Cell(), count: configuration.dimensions.cellCount)
    }

    public var flagCount: Int {
        cells.lazy.filter { $0.mark == .flag }.count
    }

    public var remainingMineCount: Int {
        configuration.mineCount - flagCount
    }

    public func elapsedSeconds(atNanoseconds now: UInt64 = ContinuousTime.nowNanoseconds()) -> Int {
        timer.elapsedSeconds(atNanoseconds: now)
    }

    public func completedGame() -> CompletedGame? {
        guard status == .won,
              isOfficialSeed,
              let preset = configuration.preset else {
            return nil
        }
        return CompletedGame(
            preset: preset,
            seconds: timer.elapsedSeconds(atNanoseconds: timer.stoppedAtNanoseconds ?? 0)
        )
    }

    public subscript(coordinate: Coordinate) -> Cell {
        precondition(configuration.dimensions.contains(coordinate))
        return cells[index(for: coordinate)]
    }

    public func allCoordinates() -> [Coordinate] {
        (0..<configuration.dimensions.rows).flatMap { row in
            (0..<configuration.dimensions.columns).map { column in
                Coordinate(row: row, column: column)
            }
        }
    }

    @discardableResult
    public mutating func setMarksEnabled(_ enabled: Bool) -> GameChange {
        guard marksEnabled != enabled else {
            return GameChange(changedCoordinates: [], status: status)
        }
        marksEnabled = enabled
        guard !enabled else {
            return GameChange(changedCoordinates: [], status: status)
        }

        var changed: Set<Coordinate> = []
        for coordinate in allCoordinates() where self[coordinate].mark == .question {
            cells[index(for: coordinate)].mark = .none
            changed.insert(coordinate)
        }
        return GameChange(changedCoordinates: changed, status: status)
    }

    @discardableResult
    public mutating func toggleMark(at coordinate: Coordinate) -> GameChange {
        guard configuration.dimensions.contains(coordinate),
              !status.isTerminal,
              !self[coordinate].isRevealed else {
            return GameChange(changedCoordinates: [], status: status)
        }

        let nextMark: CellMark = switch self[coordinate].mark {
        case .none: .flag
        case .flag: marksEnabled ? .question : .none
        case .question: .none
        }
        cells[index(for: coordinate)].mark = nextMark
        return GameChange(changedCoordinates: [coordinate], status: status)
    }

    @discardableResult
    public mutating func reveal(_ coordinate: Coordinate) -> GameChange {
        reveal(coordinate, atNanoseconds: ContinuousTime.nowNanoseconds())
    }

    @discardableResult
    mutating func reveal(_ coordinate: Coordinate, atNanoseconds now: UInt64) -> GameChange {
        guard configuration.dimensions.contains(coordinate),
              !status.isTerminal,
              !self[coordinate].isRevealed,
              self[coordinate].mark != .flag else {
            return GameChange(changedCoordinates: [], status: status)
        }

        if !isGenerated {
            generateBoard(firstReveal: coordinate)
            status = .playing
            timer.start(atNanoseconds: now)
        }

        var changed: Set<Coordinate> = []
        revealFrom(coordinate, changed: &changed)
        resolveWinIfNeeded(changed: &changed)
        if status.isTerminal {
            timer.stop(atNanoseconds: now)
        }
        return GameChange(changedCoordinates: changed, status: status)
    }

    @discardableResult
    public mutating func chord(at coordinate: Coordinate) -> GameChange {
        chord(at: coordinate, atNanoseconds: ContinuousTime.nowNanoseconds())
    }

    @discardableResult
    mutating func chord(at coordinate: Coordinate, atNanoseconds now: UInt64) -> GameChange {
        guard status == .playing,
              configuration.dimensions.contains(coordinate),
              self[coordinate].isRevealed,
              self[coordinate].adjacentMineCount > 0 else {
            return GameChange(changedCoordinates: [], status: status)
        }

        let neighbors = coordinate.neighbors(in: configuration.dimensions).sorted()
        var flaggedCount = 0
        for neighbor in neighbors where self[neighbor].mark == .flag {
            flaggedCount += 1
        }
        guard flaggedCount == Int(self[coordinate].adjacentMineCount) else {
            return GameChange(changedCoordinates: [], status: status)
        }

        var changed: Set<Coordinate> = []
        for neighbor in neighbors where !self[neighbor].isRevealed && self[neighbor].mark != .flag {
            if self[neighbor].isMine {
                cells[index(for: neighbor)].isRevealed = true
                changed.insert(neighbor)
                status = .lost(exploded: neighbor)
                break
            }
            revealFrom(neighbor, changed: &changed)
        }
        resolveWinIfNeeded(changed: &changed)
        if status.isTerminal {
            timer.stop(atNanoseconds: now)
        }
        return GameChange(changedCoordinates: changed, status: status)
    }

    private mutating func generateBoard(firstReveal: Coordinate) {
        let mines = MineGenerator.generate(
            configuration: configuration,
            seed: seed,
            firstReveal: firstReveal
        )
        for mine in mines {
            cells[index(for: mine)].isMine = true
        }
        for coordinate in allCoordinates() where !self[coordinate].isMine {
            var count = 0
            for neighbor in coordinate.neighbors(in: configuration.dimensions)
                where self[neighbor].isMine {
                count += 1
            }
            cells[index(for: coordinate)].adjacentMineCount = UInt8(count)
        }
        isGenerated = true
    }

    private mutating func revealFrom(_ start: Coordinate, changed: inout Set<Coordinate>) {
        var queue = [start]
        var cursor = 0
        var enqueued: Set<Coordinate> = [start]

        while cursor < queue.count {
            let coordinate = queue[cursor]
            cursor += 1
            let cell = self[coordinate]
            guard !cell.isRevealed, cell.mark != .flag else { continue }

            if cell.isMine {
                cells[index(for: coordinate)].isRevealed = true
                changed.insert(coordinate)
                status = .lost(exploded: coordinate)
                return
            }

            cells[index(for: coordinate)].isRevealed = true
            cells[index(for: coordinate)].mark = .none
            revealedSafeCellCount += 1
            changed.insert(coordinate)

            if cell.adjacentMineCount == 0 {
                for neighbor in coordinate.neighbors(in: configuration.dimensions).sorted()
                    where !enqueued.contains(neighbor)
                    && !self[neighbor].isRevealed
                    && self[neighbor].mark != .flag {
                    enqueued.insert(neighbor)
                    queue.append(neighbor)
                }
            }
        }
    }

    private mutating func resolveWinIfNeeded(changed: inout Set<Coordinate>) {
        guard !status.isTerminal,
              revealedSafeCellCount == configuration.dimensions.cellCount - configuration.mineCount else {
            return
        }
        status = .won
        for coordinate in allCoordinates() where self[coordinate].isMine {
            if self[coordinate].mark != .flag {
                cells[index(for: coordinate)].mark = .flag
                changed.insert(coordinate)
            }
        }
    }

    private func index(for coordinate: Coordinate) -> Int {
        coordinate.row * configuration.dimensions.columns + coordinate.column
    }
}

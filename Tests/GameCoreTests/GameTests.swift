import Testing
@testable import GameCore

@Test func firstRevealGeneratesBoardAndAccurateNeighborCounts() {
    var game = MinesweeperGame(configuration: GamePreset.beginner.configuration, seed: 42)
    let first = Coordinate(row: 4, column: 4)
    let change = game.reveal(first)

    #expect(game.isGenerated)
    #expect(game.status == .playing)
    #expect(!game[first].isMine)
    #expect(!change.changedCoordinates.isEmpty)

    for coordinate in game.allCoordinates() where !game[coordinate].isMine {
        let expected = coordinate.neighbors(in: game.configuration.dimensions)
            .filter { game[$0].isMine }
            .count
        #expect(game[coordinate].adjacentMineCount == UInt8(expected))
    }
}

@Test func markingDoesNotGenerateOrStartTheGame() {
    var game = MinesweeperGame(configuration: GamePreset.beginner.configuration, seed: 1)
    let coordinate = Coordinate(row: 0, column: 0)

    game.toggleMark(at: coordinate)
    #expect(game[coordinate].mark == .flag)
    #expect(game.status == .ready)
    #expect(!game.isGenerated)

    game.toggleMark(at: coordinate)
    #expect(game[coordinate].mark == .question)
    game.toggleMark(at: coordinate)
    #expect(game[coordinate].mark == .none)
}

@Test func disablingMarksClearsQuestionsAndUsesTwoStateCycle() {
    var game = MinesweeperGame(configuration: GamePreset.beginner.configuration, seed: 1)
    let coordinate = Coordinate(row: 0, column: 0)
    game.toggleMark(at: coordinate)
    game.toggleMark(at: coordinate)
    #expect(game[coordinate].mark == .question)

    let change = game.setMarksEnabled(false)
    #expect(game[coordinate].mark == .none)
    #expect(change.changedCoordinates == [coordinate])

    game.toggleMark(at: coordinate)
    game.toggleMark(at: coordinate)
    #expect(game[coordinate].mark == .none)
}

@Test func revealingEverySafeCellWinsAndAutoFlagsMines() {
    var game = MinesweeperGame(configuration: GamePreset.beginner.configuration, seed: 11)
    game.reveal(Coordinate(row: 4, column: 4))

    for coordinate in game.allCoordinates() where !game[coordinate].isMine {
        game.reveal(coordinate)
    }

    #expect(game.status == .won)
    #expect(game.flagCount == game.configuration.mineCount)
}

@Test func revealingAMineLosesAtThatCoordinate() {
    var game = MinesweeperGame(configuration: GamePreset.beginner.configuration, seed: 99)
    game.reveal(Coordinate(row: 4, column: 4))
    let mine = game.allCoordinates().first { game[$0].isMine }!

    let change = game.reveal(mine)
    #expect(change.status == .lost(exploded: mine))
    #expect(game[mine].isRevealed)
}

@Test func correctChordRevealsCoveredSafeNeighbors() {
    var game = MinesweeperGame(configuration: GamePreset.beginner.configuration, seed: 42)
    game.reveal(Coordinate(row: 4, column: 4))
    let target = game.allCoordinates().first { coordinate in
        game[coordinate].isRevealed
            && game[coordinate].adjacentMineCount > 0
            && coordinate.neighbors(in: game.configuration.dimensions).contains {
                !game[$0].isRevealed && !game[$0].isMine
            }
    }!

    for neighbor in target.neighbors(in: game.configuration.dimensions) where game[neighbor].isMine {
        game.toggleMark(at: neighbor)
    }
    let change = game.chord(at: target)

    #expect(!change.changedCoordinates.isEmpty)
    #expect(game.status != .lost(exploded: target))
}

@Test func incorrectChordStopsAtFirstMineInCoordinateOrder() {
    var selectedGame: MinesweeperGame?
    var selectedTarget: Coordinate?

    for seed in UInt64(0)..<200 {
        var candidate = MinesweeperGame(configuration: GamePreset.beginner.configuration, seed: seed)
        candidate.reveal(Coordinate(row: 4, column: 4))
        if let target = candidate.allCoordinates().first(where: { coordinate in
            guard candidate[coordinate].isRevealed,
                  candidate[coordinate].adjacentMineCount > 0 else { return false }
            let coveredSafe = coordinate.neighbors(in: candidate.configuration.dimensions)
                .filter { !candidate[$0].isRevealed && !candidate[$0].isMine }
            return coveredSafe.count >= Int(candidate[coordinate].adjacentMineCount)
        }) {
            selectedGame = candidate
            selectedTarget = target
            break
        }
    }

    var game = selectedGame!
    let target = selectedTarget!
    let safeNeighbors = target.neighbors(in: game.configuration.dimensions)
        .filter { !game[$0].isRevealed && !game[$0].isMine }
    for neighbor in safeNeighbors.prefix(Int(game[target].adjacentMineCount)) {
        game.toggleMark(at: neighbor)
    }

    let expectedMine = target.neighbors(in: game.configuration.dimensions)
        .filter { game[$0].isMine }
        .sorted()
        .first!
    game.chord(at: target)
    #expect(game.status == .lost(exploded: expectedMine))
}


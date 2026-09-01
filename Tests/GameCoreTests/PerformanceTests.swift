import Testing
@testable import GameCore

private func nanoseconds(_ duration: Duration) -> UInt64 {
    let components = duration.components
    return UInt64(components.seconds) * 1_000_000_000
        + UInt64(components.attoseconds / 1_000_000_000)
}

private func percentiles(_ samples: [UInt64]) -> (p95: UInt64, p99: UInt64) {
    let sorted = samples.sorted()
    return (
        sorted[(sorted.count * 95) / 100],
        sorted[(sorted.count * 99) / 100]
    )
}

#if !DEBUG
@Test func maximumFloodPerformanceMeetsReleaseBudget() throws {
    let configuration = try GameConfiguration(columns: 30, rows: 24, mineCount: 1)
    let seeds = (0..<50).map(UInt64.init)
    var samples: [UInt64] = []
    samples.reserveCapacity(500)

    for iteration in 0..<520 {
        var game = MinesweeperGame(
            configuration: configuration,
            seed: seeds[iteration % seeds.count]
        )
        let clock = ContinuousClock()
        let start = clock.now
        game.reveal(Coordinate(row: 12, column: 15))
        let duration = start.duration(to: clock.now)

        if iteration >= 20 {
            samples.append(nanoseconds(duration))
        }
    }

    let result = percentiles(samples)
    #expect(result.p95 <= 8_000_000)
    #expect(result.p99 <= 12_000_000)
}

@Test func ordinaryActionsHaveIndependentPerformanceBudgets() {
    var revealSamples: [UInt64] = []
    var markSamples: [UInt64] = []
    var chordSamples: [UInt64] = []
    var winSamples: [UInt64] = []
    let clock = ContinuousClock()

    for iteration in 0..<520 {
        let seed = UInt64(iteration % 50)

        var markGame = MinesweeperGame(configuration: GamePreset.expert.configuration, seed: seed)
        var start = clock.now
        markGame.toggleMark(at: Coordinate(row: 0, column: 0))
        var duration = start.duration(to: clock.now)
        if iteration >= 20 { markSamples.append(nanoseconds(duration)) }

        var revealGame = MinesweeperGame(configuration: GamePreset.beginner.configuration, seed: seed)
        revealGame.reveal(Coordinate(row: 4, column: 4), atNanoseconds: 0)
        let revealTarget = revealGame.allCoordinates().first {
            !revealGame[$0].isRevealed
                && !revealGame[$0].isMine
                && revealGame[$0].adjacentMineCount > 0
        }!
        start = clock.now
        revealGame.reveal(revealTarget, atNanoseconds: 1)
        duration = start.duration(to: clock.now)
        if iteration >= 20 { revealSamples.append(nanoseconds(duration)) }

        var chordGame = MinesweeperGame(configuration: GamePreset.beginner.configuration, seed: seed)
        chordGame.reveal(Coordinate(row: 4, column: 4), atNanoseconds: 0)
        let chordTarget = chordGame.allCoordinates().first { coordinate in
            chordGame[coordinate].isRevealed
                && chordGame[coordinate].adjacentMineCount > 0
                && coordinate.neighbors(in: chordGame.configuration.dimensions).contains {
                    !chordGame[$0].isRevealed && !chordGame[$0].isMine
                }
        }!
        for neighbor in chordTarget.neighbors(in: chordGame.configuration.dimensions)
            where chordGame[neighbor].isMine {
            chordGame.toggleMark(at: neighbor)
        }
        start = clock.now
        chordGame.chord(at: chordTarget, atNanoseconds: 1)
        duration = start.duration(to: clock.now)
        if iteration >= 20 { chordSamples.append(nanoseconds(duration)) }

        var winGame = MinesweeperGame(configuration: GamePreset.beginner.configuration, seed: seed)
        winGame.reveal(Coordinate(row: 4, column: 4), atNanoseconds: 0)
        var winningState: (game: MinesweeperGame, target: Coordinate)?
        for coordinate in winGame.allCoordinates() where !winGame[coordinate].isMine {
            guard !winGame[coordinate].isRevealed else { continue }
            let before = winGame
            winGame.reveal(coordinate, atNanoseconds: 1)
            if winGame.status == .won {
                winningState = (before, coordinate)
                break
            }
        }
        var finalGame = winningState!.game
        start = clock.now
        finalGame.reveal(winningState!.target, atNanoseconds: 2)
        duration = start.duration(to: clock.now)
        if iteration >= 20 { winSamples.append(nanoseconds(duration)) }
    }

    for samples in [revealSamples, markSamples, chordSamples, winSamples] {
        let result = percentiles(samples)
        #expect(result.p95 <= 4_000_000)
        #expect(result.p99 <= 8_000_000)
    }
}
#endif

@Test func fiftySeedCorpusPreservesMineInvariants() {
    let configurations = GamePreset.allCases.map(\.configuration)
    for configuration in configurations {
        let firstReveals = [
            Coordinate(row: 0, column: 0),
            Coordinate(row: 0, column: configuration.dimensions.columns / 2),
            Coordinate(
                row: configuration.dimensions.rows / 2,
                column: configuration.dimensions.columns / 2
            ),
        ]
        for seed in UInt64(0)..<50 {
            for first in firstReveals {
                let mines = MineGenerator.generate(
                    configuration: configuration,
                    seed: seed,
                    firstReveal: first
                )
                #expect(mines.count == configuration.mineCount)
                #expect(!mines.contains(first))
                for neighbor in first.neighbors(in: configuration.dimensions) {
                    #expect(!mines.contains(neighbor))
                }
            }
        }
    }
}

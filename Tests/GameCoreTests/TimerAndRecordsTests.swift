import Testing
@testable import GameCore

@Test func timerFloorsAndSaturatesElapsedSeconds() {
    var timer = GameTimer()
    #expect(timer.elapsedSeconds(atNanoseconds: 50) == 0)

    timer.start(atNanoseconds: 1_000_000_000)
    #expect(timer.elapsedSeconds(atNanoseconds: 2_999_999_999) == 1)
    timer.stop(atNanoseconds: 4_500_000_000)
    #expect(timer.elapsedSeconds(atNanoseconds: 9_000_000_000) == 3)

    var longTimer = GameTimer()
    longTimer.start(atNanoseconds: 0)
    #expect(longTimer.elapsedSeconds(atNanoseconds: 2_000_000_000_000) == 999)
}

@Test func bestTimesAcceptOnlyStrictlyBetterOfficialStandardGames() {
    var bestTimes = BestTimes()
    let result = CompletedGame(preset: .beginner, seconds: 30)
    let accepted = bestTimes.submit(result, name: "Kyle")
    #expect(accepted)
    let tieAccepted = bestTimes.submit(result, name: "Tie")
    #expect(!tieAccepted)
    #expect(bestTimes.records[.beginner] == (try? BestTimeRecord(seconds: 30, name: "Kyle")))

    let fasterAccepted = bestTimes.submit(
        CompletedGame(preset: .beginner, seconds: 29),
        name: "Faster"
    )
    #expect(fasterAccepted)
    #expect(bestTimes.records[.beginner]?.seconds == 29)
    bestTimes.reset()
    #expect(bestTimes.records.isEmpty)
}

@Test func gameOwnsTimerAndTestSeedsCannotProduceRecordResults() {
    var game = MinesweeperGame(configuration: GamePreset.beginner.configuration, seed: 5)
    game.toggleMark(at: Coordinate(row: 0, column: 0))
    #expect(!game.timer.isRunning)

    game.reveal(Coordinate(row: 4, column: 4), atNanoseconds: 1_000_000_000)
    #expect(game.timer.isRunning)
    for coordinate in game.allCoordinates() where !game[coordinate].isMine {
        game.reveal(coordinate, atNanoseconds: 3_900_000_000)
    }

    #expect(game.status == .won)
    #expect(!game.timer.isRunning)
    #expect(game.elapsedSeconds(atNanoseconds: 100_000_000_000) == 2)
    #expect(game.completedGame() == nil)
}

@Test func officialSessionProducesAnEligibleCompletedGame() throws {
    var game = try MinesweeperGame(configuration: GamePreset.beginner.configuration)
    game.reveal(Coordinate(row: 4, column: 4), atNanoseconds: 1_000_000_000)
    for coordinate in game.allCoordinates() where !game[coordinate].isMine {
        game.reveal(coordinate, atNanoseconds: 3_900_000_000)
    }

    let completed = try #require(game.completedGame())
    #expect(completed.preset == .beginner)
    #expect(completed.seconds == 2)

    var bestTimes = BestTimes()
    let accepted = bestTimes.submit(completed, name: "Kyle")
    #expect(accepted)
}

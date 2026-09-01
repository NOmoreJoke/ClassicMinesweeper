import Testing
@testable import GameCore

@Test func splitMix64FixtureIsStable() {
    var generator = SplitMix64(seed: 0)
    #expect(generator.next() == 0xE220_A839_7B1D_CDAF)
    #expect(generator.next() == 0x6E78_9E6A_A1B9_65F4)
}

@Test func generationIsDeterministicAndProtectsFirstNeighborhood() {
    let configuration = GamePreset.beginner.configuration
    let first = Coordinate(row: 4, column: 4)
    let mines = MineGenerator.generate(configuration: configuration, seed: 42, firstReveal: first)
    let repeated = MineGenerator.generate(configuration: configuration, seed: 42, firstReveal: first)

    #expect(mines == repeated)
    #expect(mines.count == configuration.mineCount)
    #expect(!mines.contains(first))
    for neighbor in first.neighbors(in: configuration.dimensions) {
        #expect(!mines.contains(neighbor))
    }

    let fixture = [
        Coordinate(row: 0, column: 5),
        Coordinate(row: 1, column: 4),
        Coordinate(row: 2, column: 3),
        Coordinate(row: 3, column: 2),
        Coordinate(row: 3, column: 6),
        Coordinate(row: 4, column: 1),
        Coordinate(row: 4, column: 7),
        Coordinate(row: 6, column: 0),
        Coordinate(row: 6, column: 5),
        Coordinate(row: 7, column: 2),
    ]
    #expect(mines.sorted() == fixture)
}

@Test func cornerProtectionAndMaximumMineCountRemainValid() throws {
    let configuration = try GameConfiguration(columns: 9, rows: 9, mineCount: 72)
    let first = Coordinate(row: 0, column: 0)
    let mines = MineGenerator.generate(configuration: configuration, seed: 7, firstReveal: first)
    #expect(mines.count == 72)
    #expect(!mines.contains(first))
    #expect(!mines.contains(Coordinate(row: 0, column: 1)))
    #expect(!mines.contains(Coordinate(row: 1, column: 0)))
    #expect(!mines.contains(Coordinate(row: 1, column: 1)))
}

@Test func secureSeedsCanBeCreated() throws {
    let seeds = try Set((0..<8).map { _ in try SecureSeed.generate() })
    #expect(seeds.count == 8)
}

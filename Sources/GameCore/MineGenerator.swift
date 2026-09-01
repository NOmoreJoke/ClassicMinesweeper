public enum MineGenerator {
    public static func generate(
        configuration: GameConfiguration,
        seed: UInt64,
        firstReveal: Coordinate
    ) -> Set<Coordinate> {
        precondition(configuration.dimensions.contains(firstReveal))
        let dimensions = configuration.dimensions
        var candidates: [Coordinate] = []
        candidates.reserveCapacity(dimensions.cellCount - 9)

        for row in 0..<dimensions.rows {
            for column in 0..<dimensions.columns {
                let coordinate = Coordinate(row: row, column: column)
                let isProtected = abs(row - firstReveal.row) <= 1
                    && abs(column - firstReveal.column) <= 1
                if !isProtected {
                    candidates.append(coordinate)
                }
            }
        }

        precondition(configuration.mineCount <= candidates.count)
        var generator = SplitMix64(seed: seed)
        for index in 0..<configuration.mineCount {
            let offset = Int(generator.bounded(UInt64(candidates.count - index)))
            candidates.swapAt(index, index + offset)
        }
        return Set(candidates.prefix(configuration.mineCount))
    }
}


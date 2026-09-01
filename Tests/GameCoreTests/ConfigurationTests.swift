import Testing
import Foundation
@testable import GameCore

@Test func classicPresetsAreFrozen() {
    let beginner = GamePreset.beginner.configuration
    #expect(beginner.dimensions.columns == 9)
    #expect(beginner.dimensions.rows == 9)
    #expect(beginner.mineCount == 10)

    let intermediate = GamePreset.intermediate.configuration
    #expect(intermediate.dimensions.columns == 16)
    #expect(intermediate.dimensions.rows == 16)
    #expect(intermediate.mineCount == 40)

    let expert = GamePreset.expert.configuration
    #expect(expert.dimensions.columns == 30)
    #expect(expert.dimensions.rows == 16)
    #expect(expert.mineCount == 99)
}

@Test func decodingCannotBypassConfigurationValidation() {
    let invalidDimensions = #"{"dimensions":{"columns":0,"rows":0},"mineCount":-5,"preset":"expert"}"#
    #expect(throws: (any Error).self) {
        try JSONDecoder().decode(GameConfiguration.self, from: Data(invalidDimensions.utf8))
    }

    let mismatchedPreset = #"{"dimensions":{"columns":9,"rows":9},"mineCount":10,"preset":"expert"}"#
    #expect(throws: (any Error).self) {
        try JSONDecoder().decode(GameConfiguration.self, from: Data(mismatchedPreset.utf8))
    }

    let invalidRecord = #"{"seconds":-1,"name":"Injected"}"#
    #expect(throws: (any Error).self) {
        try JSONDecoder().decode(BestTimeRecord.self, from: Data(invalidRecord.utf8))
    }
}

@Test func invalidConfigurationsAreRejected() {
    do {
        _ = try GameConfiguration(columns: 8, rows: 9, mineCount: 10)
        Issue.record("Expected invalid dimensions")
    } catch {
        #expect(error as? GameConfigurationError == .invalidDimensions)
    }

    do {
        _ = try GameConfiguration(columns: 9, rows: 9, mineCount: 73)
        Issue.record("Expected invalid mine count")
    } catch {
        #expect(error as? GameConfigurationError == .invalidMineCount)
    }
}

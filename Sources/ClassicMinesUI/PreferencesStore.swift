import Foundation
import GameCore

@MainActor
final class PreferencesStore {
    private enum Key {
        static let scale = "scale"
        static let marksEnabled = "marksEnabled"
        static let bestTimes = "bestTimes"
        static let playerName = "playerName"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    var scale: Int
    var marksEnabled: Bool
    var bestTimes: BestTimes
    var playerName: String

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedScale = defaults.integer(forKey: Key.scale)
        scale = (1...3).contains(storedScale) ? storedScale : 2
        marksEnabled = defaults.object(forKey: Key.marksEnabled) == nil
            ? true
            : defaults.bool(forKey: Key.marksEnabled)
        if let data = defaults.data(forKey: Key.bestTimes),
           let decoded = try? decoder.decode(BestTimes.self, from: data) {
            bestTimes = decoded
        } else {
            bestTimes = BestTimes()
        }
        let storedName = defaults.string(forKey: Key.playerName)?.trimmingCharacters(in: .whitespacesAndNewlines)
        playerName = storedName?.isEmpty == false ? storedName! : NSUserName()
    }

    func savePreferences() {
        defaults.set(scale, forKey: Key.scale)
        defaults.set(marksEnabled, forKey: Key.marksEnabled)
        defaults.set(playerName, forKey: Key.playerName)
    }

    func saveBestTimes() {
        if let data = try? encoder.encode(bestTimes) {
            defaults.set(data, forKey: Key.bestTimes)
        }
    }
}


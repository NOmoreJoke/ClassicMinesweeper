import Foundation
import GameCore

struct CompletionHistoryRecord: Equatable, Sendable, Codable {
    let completedAt: Date
    let configuration: GameConfiguration
    let seconds: Int
    let name: String

    init(completedAt: Date, configuration: GameConfiguration, seconds: Int, name: String) throws {
        guard completedAt.timeIntervalSinceReferenceDate.isFinite,
              (0...999).contains(seconds) else {
            throw CompletionHistoryError.invalidRecord
        }
        self.completedAt = completedAt
        self.configuration = configuration
        self.seconds = seconds
        self.name = name
    }

    private enum CodingKeys: String, CodingKey {
        case completedAt, configuration, seconds, name
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            completedAt: values.decode(Date.self, forKey: .completedAt),
            configuration: values.decode(GameConfiguration.self, forKey: .configuration),
            seconds: values.decode(Int.self, forKey: .seconds),
            name: values.decode(String.self, forKey: .name)
        )
    }
}

enum CompletionHistoryError: Error {
    case invalidRecord
}

struct CompletionHistory: Equatable, Sendable, Codable {
    static let maximumRecordCount = 100
    private(set) var records: [CompletionHistoryRecord]

    init(records: [CompletionHistoryRecord] = []) {
        self.records = Array(records.prefix(Self.maximumRecordCount))
    }

    mutating func add(_ record: CompletionHistoryRecord) {
        records.insert(record, at: 0)
        if records.count > Self.maximumRecordCount {
            records.removeLast(records.count - Self.maximumRecordCount)
        }
    }

    mutating func reset() {
        records.removeAll()
    }

    private enum CodingKeys: String, CodingKey { case records }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(records: try values.decode([CompletionHistoryRecord].self, forKey: .records))
    }
}

@MainActor
final class PreferencesStore {
    private enum Key {
        static let scale = "scale"
        static let marksEnabled = "marksEnabled"
        static let bestTimes = "bestTimes"
        static let playerName = "playerName"
        static let completionHistory = "completionHistory"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    var scale: Int
    var marksEnabled: Bool
    var bestTimes: BestTimes
    var playerName: String
    var completionHistory: CompletionHistory

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
        if let data = defaults.data(forKey: Key.completionHistory),
           let decoded = try? decoder.decode(CompletionHistory.self, from: data) {
            completionHistory = decoded
        } else {
            completionHistory = CompletionHistory()
        }
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

    func addCompletion(
        configuration: GameConfiguration,
        seconds: Int,
        name: String,
        completedAt: Date = Date()
    ) {
        guard let record = try? CompletionHistoryRecord(
            completedAt: completedAt,
            configuration: configuration,
            seconds: seconds,
            name: name
        ) else { return }
        completionHistory.add(record)
        saveCompletionHistory()
    }

    func saveCompletionHistory() {
        if let data = try? encoder.encode(completionHistory) {
            defaults.set(data, forKey: Key.completionHistory)
        }
    }
}

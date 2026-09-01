public struct BestTimeRecord: Equatable, Sendable, Codable {
    public let seconds: Int
    public let name: String

    public init(seconds: Int, name: String) throws {
        guard (0...999).contains(seconds) else {
            throw BestTimeError.invalidSeconds
        }
        self.seconds = seconds
        self.name = name
    }

    private enum CodingKeys: String, CodingKey {
        case seconds
        case name
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            seconds: values.decode(Int.self, forKey: .seconds),
            name: values.decode(String.self, forKey: .name)
        )
    }
}

public enum BestTimeError: Error, Equatable, Sendable {
    case invalidSeconds
}

public struct BestTimes: Equatable, Sendable, Codable {
    public private(set) var records: [GamePreset: BestTimeRecord]

    public init(records: [GamePreset: BestTimeRecord] = [:]) {
        self.records = records
    }

    @discardableResult
    public mutating func submit(_ result: CompletedGame, name: String) -> Bool {
        if let existing = records[result.preset], existing.seconds <= result.seconds {
            return false
        }
        records[result.preset] = try! BestTimeRecord(seconds: result.seconds, name: name)
        return true
    }

    public mutating func reset() {
        records.removeAll()
    }
}

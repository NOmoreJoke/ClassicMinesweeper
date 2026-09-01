import Security

public enum SecureSeedError: Error, Equatable, Sendable {
    case generationFailed(OSStatus)
}

public enum SecureSeed {
    public static func generate() throws -> UInt64 {
        var seed: UInt64 = 0
        let status = withUnsafeMutableBytes(of: &seed) { buffer in
            SecRandomCopyBytes(kSecRandomDefault, buffer.count, buffer.baseAddress!)
        }
        guard status == errSecSuccess else {
            throw SecureSeedError.generationFailed(status)
        }
        return seed
    }
}


import Testing
@testable import GameCore

@Test func productIdentityIsFrozen() {
    #expect(BuildInfo.productName == "Classic Mines")
    #expect(BuildInfo.bundleIdentifier == "com.local.classicmines")
}


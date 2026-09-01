import AppKit
import GameCore

final class AccessibilityRequest: NSObject, @unchecked Sendable {
    let coordinate: Coordinate
    private let lock = NSLock()
    private var storedResult = false

    init(coordinate: Coordinate) {
        self.coordinate = coordinate
    }

    func complete(_ result: Bool) {
        lock.lock()
        storedResult = result
        lock.unlock()
    }

    func result() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return storedResult
    }
}

private final class AccessibilityBoardReference: @unchecked Sendable {
    private let lock = NSLock()
    private weak var storedBoardView: ClassicBoardView?

    @MainActor init(_ boardView: ClassicBoardView) {
        storedBoardView = boardView
    }

    func boardView() -> ClassicBoardView? {
        lock.lock()
        defer { lock.unlock() }
        return storedBoardView
    }
}

final class BoardAccessibilityCell: NSAccessibilityElement, @unchecked Sendable {
    let coordinate: Coordinate
    private nonisolated let boardReference: AccessibilityBoardReference

    @MainActor
    init(coordinate: Coordinate, boardView: ClassicBoardView) {
        self.coordinate = coordinate
        boardReference = AccessibilityBoardReference(boardView)
        super.init()
        setAccessibilityRole(.cell)
        setAccessibilityParent(boardView)
        setAccessibilityIdentifier("cell-\(coordinate.row)-\(coordinate.column)")
    }

    nonisolated override func accessibilityPerformPress() -> Bool {
        performOnMainThread(#selector(ClassicBoardView.accessibilityPerformDefaultCell(_:)))
    }

    @objc nonisolated func performReveal() -> Bool {
        performOnMainThread(#selector(ClassicBoardView.accessibilityRevealCell(_:)))
    }

    @objc nonisolated func performToggleMark() -> Bool {
        performOnMainThread(#selector(ClassicBoardView.accessibilityToggleMarkCell(_:)))
    }

    @objc nonisolated func performChord() -> Bool {
        performOnMainThread(#selector(ClassicBoardView.accessibilityChordCell(_:)))
    }

    nonisolated override func setAccessibilityFocused(_ accessibilityFocused: Bool) {
        super.setAccessibilityFocused(accessibilityFocused)
        if accessibilityFocused {
            _ = performOnMainThread(#selector(ClassicBoardView.accessibilityFocusCell(_:)))
        }
    }

    private nonisolated func performOnMainThread(_ selector: Selector) -> Bool {
        guard let boardView = boardReference.boardView() else { return false }
        let request = AccessibilityRequest(coordinate: coordinate)
        boardView.performSelector(onMainThread: selector, with: request, waitUntilDone: true)
        return request.result()
    }
}

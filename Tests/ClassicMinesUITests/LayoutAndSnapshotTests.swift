import AppKit
import Foundation
import Testing
@testable import ClassicMinesUI
@testable import GameCore

@MainActor
private func render(_ view: NSView) throws -> NSBitmapImageRep {
    view.layoutSubtreeIfNeeded()
    let bitmap = try #require(NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(view.bounds.width),
        pixelsHigh: Int(view.bounds.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ))
    let context = try #require(NSGraphicsContext(bitmapImageRep: bitmap))
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    view.displayIgnoringOpacity(view.bounds, in: context)
    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}

private func pixels(_ bitmap: NSBitmapImageRep) -> [UInt8] {
    let source = bitmap.bitmapData!
    var output: [UInt8] = []
    output.reserveCapacity(bitmap.pixelsWide * bitmap.pixelsHigh * 4)
    for row in 0..<bitmap.pixelsHigh {
        let start = source.advanced(by: row * bitmap.bytesPerRow)
        output.append(contentsOf: UnsafeBufferPointer(start: start, count: bitmap.pixelsWide * 4))
    }
    return output
}

private func fnv1a64(_ bytes: [UInt8]) -> UInt64 {
    bytes.reduce(0xCBF2_9CE4_8422_2325) { hash, byte in
        (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01B3
    }
}

private func expectExactTwoTimesScale(_ one: NSBitmapImageRep, _ two: NSBitmapImageRep) {
    #expect(two.pixelsWide == one.pixelsWide * 2)
    #expect(two.pixelsHigh == one.pixelsHigh * 2)
    let source = pixels(one)
    let target = pixels(two)
    var mismatchCount = 0
    for y in 0..<one.pixelsHigh {
        for x in 0..<one.pixelsWide {
            for dy in 0..<2 {
                for dx in 0..<2 {
                    for channel in 0..<4 {
                        let sourceIndex = (y * one.pixelsWide + x) * 4 + channel
                        let targetIndex = (((y * 2 + dy) * two.pixelsWide + x * 2 + dx) * 4) + channel
                        if target[targetIndex] != source[sourceIndex] {
                            mismatchCount += 1
                        }
                    }
                }
            }
        }
    }
    #expect(mismatchCount == 0)
}

@Test func integerLayoutsMatchFrozenGeometry() {
    let beginner = ClassicLayout(configuration: GamePreset.beginner.configuration, scale: 2)
    #expect(beginner.boardSize == NSSize(width: 288, height: 288))
    #expect(beginner.contentSize == NSSize(width: 312, height: 444))

    let expert = ClassicLayout(configuration: GamePreset.expert.configuration, scale: 3)
    #expect(expert.boardSize == NSSize(width: 1_440, height: 768))
    #expect(expert.contentSize == NSSize(width: 1_476, height: 1_002))

    let fitted = ClassicLayout.largestFittingScale(
        configuration: GamePreset.expert.configuration,
        preferred: 3,
        visibleSize: NSSize(width: 1_440, height: 900)
    )
    #expect(fitted == 2)
}

@Test @MainActor func menusExposeTheFrozenCommandSet() {
    let gameMenu = ClassicMenuFactory.gameMenu(target: nil)
    #expect(gameMenu.items.map(\.title) == [
        "New", "", "Beginner", "Intermediate", "Expert", "Custom…", "", "Marks (?)", "Best Times…",
    ])
    #expect(gameMenu.item(withTitle: "New")?.action == #selector(ClassicGameWindowController.newGame(_:)))
    #expect(gameMenu.item(withTitle: "Marks (?)")?.action == #selector(ClassicGameWindowController.toggleMarks(_:)))
}

@Test @MainActor func initialScalePropagatesToEveryRenderedRegion() {
    let game = MinesweeperGame(configuration: GamePreset.beginner.configuration, seed: 1)
    let view = ClassicGameView(game: game, scale: 2, commandTarget: nil)
    #expect(view.boardView.scale == 2)
    #expect(view.hudView.scale == 2)
    #expect(view.menuScaleForTesting == 2)
}

@Test @MainActor func boardStatesHaveFrozenPixelsAndExactTwoTimesScaling() throws {
    var playing = MinesweeperGame(configuration: GamePreset.beginner.configuration, seed: 42)
    playing.toggleMark(at: Coordinate(row: 0, column: 0))
    playing.toggleMark(at: Coordinate(row: 0, column: 1))
    playing.toggleMark(at: Coordinate(row: 0, column: 1))
    playing.reveal(Coordinate(row: 4, column: 4), atNanoseconds: 0)

    var lost = playing
    let mine = lost.allCoordinates().first { lost[$0].isMine && lost[$0].mark != .flag }!
    lost.reveal(mine, atNanoseconds: 1)

    var won = MinesweeperGame(configuration: GamePreset.beginner.configuration, seed: 11)
    won.reveal(Coordinate(row: 4, column: 4), atNanoseconds: 0)
    for coordinate in won.allCoordinates() where !won[coordinate].isMine {
        won.reveal(coordinate, atNanoseconds: 1)
    }

    let ready = MinesweeperGame(configuration: GamePreset.beginner.configuration, seed: 7)
    let states: [(String, MinesweeperGame)] = [
        ("ready", ready),
        ("playing", playing),
        ("lost", lost),
        ("won", won),
    ]
    let expectedHashes: [String: UInt64] = [
        "ready": 0xFB6F_E4B8_379C_4675,
        "playing": 0xB3DA_9111_4C8C_76A5,
        "lost": 0x5319_ED29_5F05_217D,
        "won": 0x21AC_D31D_1B56_8B1A,
    ]
    let snapshotDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent(".build/snapshots", isDirectory: true)
    try FileManager.default.createDirectory(at: snapshotDirectory, withIntermediateDirectories: true)

    for (name, game) in states {
        let oneView = ClassicBoardView(game: game, scale: 1)
        oneView.frame = NSRect(origin: .zero, size: oneView.intrinsicContentSize)
        let one = try render(oneView)

        let twoView = ClassicBoardView(game: game, scale: 2)
        twoView.frame = NSRect(origin: .zero, size: twoView.intrinsicContentSize)
        let two = try render(twoView)
        expectExactTwoTimesScale(one, two)

        let png = try #require(two.representation(using: .png, properties: [:]))
        try png.write(to: snapshotDirectory.appendingPathComponent("\(name)-2x.png"), options: .atomic)
        #expect(fnv1a64(pixels(one)) == expectedHashes[name])
    }
}

@Test @MainActor func hudStatesHaveFrozenPixelsAndExactTwoTimesScaling() throws {
    let states: [(String, GameStatus, Int, Int)] = [
        ("ready", .ready, 10, 0),
        ("lost", .lost(exploded: Coordinate(row: 0, column: 0)), -5, 87),
        ("won", .won, 0, 999),
    ]
    let expectedHashes: [String: UInt64] = [
        "ready": 0x868B_B8EC_53D6_4F85,
        "lost": 0x2A55_2322_9E93_1C13,
        "won": 0x8F5C_DEAE_516A_9265,
    ]
    for (name, status, mines, seconds) in states {
        let one = ClassicHUDView(frame: NSRect(x: 0, y: 0, width: 144, height: 40))
        one.scale = 1
        one.gameStatus = status
        one.remainingMines = mines
        one.elapsedSeconds = seconds
        let oneBitmap = try render(one)

        let two = ClassicHUDView(frame: NSRect(x: 0, y: 0, width: 288, height: 80))
        two.scale = 2
        two.gameStatus = status
        two.remainingMines = mines
        two.elapsedSeconds = seconds
        let twoBitmap = try render(two)
        expectExactTwoTimesScale(oneBitmap, twoBitmap)
        #expect(fnv1a64(pixels(oneBitmap)) == expectedHashes[name])
    }
}

import AppKit

final class BoardAccessibilityRow: NSAccessibilityElement {
    let index: Int

    @MainActor
    init(index: Int, boardView: ClassicBoardView, cells: [BoardAccessibilityCell]) {
        self.index = index
        super.init()
        setAccessibilityRole(.row)
        setAccessibilityParent(boardView)
        setAccessibilityIdentifier("row-\(index)")
        setAccessibilityLabel("Row \(index + 1)")
        setAccessibilityChildren(cells)
        for cell in cells {
            cell.setAccessibilityParent(self)
        }
    }
}

final class BoardAccessibilityColumn: NSAccessibilityElement {
    let index: Int

    @MainActor
    init(index: Int, boardView: ClassicBoardView, cells: [BoardAccessibilityCell]) {
        self.index = index
        super.init()
        setAccessibilityRole(.column)
        setAccessibilityParent(boardView)
        setAccessibilityIdentifier("column-\(index)")
        setAccessibilityLabel("Column \(index + 1)")
        setAccessibilityChildren(cells)
    }
}

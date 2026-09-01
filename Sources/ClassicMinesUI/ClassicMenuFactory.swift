import AppKit

@MainActor
public enum ClassicMenuFactory {
    public static func makeApplicationMenu(target: AnyObject?) -> NSMenu {
        let main = NSMenu()

        let applicationItem = NSMenuItem()
        let applicationMenu = NSMenu(title: "Classic Mines")
        applicationMenu.addItem(withTitle: "About Classic Mines", action: #selector(ClassicGameWindowController.showAbout(_:)), keyEquivalent: "")
        applicationMenu.items.last?.target = target
        applicationMenu.addItem(.separator())
        applicationMenu.addItem(withTitle: "Quit Classic Mines", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        applicationItem.submenu = applicationMenu
        main.addItem(applicationItem)

        let gameItem = NSMenuItem()
        gameItem.submenu = gameMenu(target: target)
        main.addItem(gameItem)

        let viewItem = NSMenuItem()
        viewItem.submenu = viewMenu(target: target)
        main.addItem(viewItem)

        let helpItem = NSMenuItem()
        helpItem.submenu = helpMenu(target: target)
        main.addItem(helpItem)
        return main
    }

    static func gameMenu(target: AnyObject?) -> NSMenu {
        let menu = NSMenu(title: "Game")
        add("New", action: #selector(ClassicGameWindowController.newGame(_:)), key: "n", target: target, to: menu)
        menu.addItem(.separator())
        add("Beginner", action: #selector(ClassicGameWindowController.selectBeginner(_:)), target: target, to: menu)
        add("Intermediate", action: #selector(ClassicGameWindowController.selectIntermediate(_:)), target: target, to: menu)
        add("Expert", action: #selector(ClassicGameWindowController.selectExpert(_:)), target: target, to: menu)
        add("Custom…", action: #selector(ClassicGameWindowController.showCustomGame(_:)), target: target, to: menu)
        menu.addItem(.separator())
        add("Marks (?)", action: #selector(ClassicGameWindowController.toggleMarks(_:)), target: target, to: menu)
        add("Best Times…", action: #selector(ClassicGameWindowController.showBestTimes(_:)), target: target, to: menu)
        add("Reset Records…", action: #selector(ClassicGameWindowController.resetRecords(_:)), target: target, to: menu)
        menu.addItem(.separator())
        add("Preferences…", action: #selector(ClassicGameWindowController.showPreferences(_:)), key: ",", target: target, to: menu)
        return menu
    }

    static func viewMenu(target: AnyObject?) -> NSMenu {
        let menu = NSMenu(title: "View")
        add("1×", action: #selector(ClassicGameWindowController.selectScale1(_:)), target: target, to: menu)
        add("2×", action: #selector(ClassicGameWindowController.selectScale2(_:)), target: target, to: menu)
        add("3×", action: #selector(ClassicGameWindowController.selectScale3(_:)), target: target, to: menu)
        return menu
    }

    static func helpMenu(target: AnyObject?) -> NSMenu {
        let menu = NSMenu(title: "Help")
        add("Rules", action: #selector(ClassicGameWindowController.showRules(_:)), target: target, to: menu)
        add("About Classic Mines", action: #selector(ClassicGameWindowController.showAbout(_:)), target: target, to: menu)
        return menu
    }

    @discardableResult
    private static func add(
        _ title: String,
        action: Selector?,
        key: String = "",
        target: AnyObject?,
        to menu: NSMenu
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = target
        menu.addItem(item)
        return item
    }
}

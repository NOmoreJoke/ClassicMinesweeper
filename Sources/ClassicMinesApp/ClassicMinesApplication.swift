import AppKit
import ClassicMinesUI

@main
@MainActor
final class ClassicMinesApplication: NSObject, NSApplicationDelegate {
    private var windowController: ClassicGameWindowController?

    static func main() {
        let application = NSApplication.shared
        let delegate = ClassicMinesApplication()
        application.delegate = delegate
        application.setActivationPolicy(.regular)
        application.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let controller = try ClassicGameWindowController.make()
            windowController = controller
            NSApp.mainMenu = ClassicMenuFactory.makeApplicationMenu(target: controller)
            controller.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Classic Mines Could Not Start"
            alert.informativeText = "A secure local game seed could not be created."
            alert.runModal()
            NSApp.terminate(nil)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

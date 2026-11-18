import AppKit
import CodexNotchCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = IslandViewModel()
    private var controller: NotchController?
    private var rolloutWatcher: RolloutWatcher?
    private var inbox: EventInbox?
    private var demoDriver: DemoDriver?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = NotchController(model: model)
        controller.start()
        self.controller = controller

        installStatusItem()

        if CommandLine.arguments.contains("--demo") {
            let driver = DemoDriver(model: model)
            driver.start()
            demoDriver = driver
        } else {
            rolloutWatcher = RolloutWatcher(
                onReset: { [model] threadID in model.resetSession(threadID: threadID) },
                onSignal: { [model] signal in model.apply(signal: signal) }
            )
            rolloutWatcher?.start()
            inbox = EventInbox { [model] event in model.apply(hook: event) }
            inbox?.start()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        rolloutWatcher?.stop()
        inbox?.stop()
        controller?.stop()
        demoDriver?.stop()
    }

    // MARK: - Menu bar

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "command",
            accessibilityDescription: "Codex Notch"
        )
        item.button?.image?.isTemplate = true

        let menu = NSMenu()
        menu.addItem(withTitle: Copy.text("Open Codex", "打开 Codex"), action: #selector(openCodex), keyEquivalent: "o")
        menu.addItem(.separator())
        menu.addItem(withTitle: Copy.text("Copy hook config", "复制 hook 配置"), action: #selector(copyHookConfig), keyEquivalent: "h")
        menu.addItem(withTitle: Copy.text("Reveal data folder", "显示数据文件夹"), action: #selector(revealDataFolder), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: Copy.text("Quit Codex Notch", "退出 Codex Notch"), action: #selector(quit), keyEquivalent: "q")
        for menuItem in menu.items { menuItem.target = self }

        item.menu = menu
        statusItem = item
    }

    @objc private func openCodex() {
        NotchController.openCodex()
    }

    @objc private func copyHookConfig() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(NotchController.hookCommand(), forType: .string)
    }

    @objc private func revealDataFolder() {
        try? AppPaths.ensureSupportDirectory()
        NSWorkspace.shared.open(AppPaths.supportDirectory)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

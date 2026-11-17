import AppKit
import CodexNotchCore

let application = NSApplication.shared

if CommandLine.arguments.contains("--probe") {
    Probe.printReport()
    exit(0)
}

application.setActivationPolicy(.accessory)
let appDelegate = AppDelegate()
application.delegate = appDelegate
application.run()

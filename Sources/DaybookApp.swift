import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        switch ProcessInfo.processInfo.environment["DAYBOOK_FORCE_APPEARANCE"] {
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        default: break
        }
        if ProcessInfo.processInfo.environment["DAYBOOK_COMPACT_PREVIEW"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                NSApp.windows.first?.setContentSize(NSSize(width: 500, height: 700))
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct DaybookApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = JournalStore()
    private static let compactPreview = ProcessInfo.processInfo.environment["DAYBOOK_COMPACT_PREVIEW"] == "1"

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .tint(JournalTheme.accent)
                .frame(minWidth: 500, minHeight: 620)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: Self.compactPreview ? 500 : 660,
                     height: Self.compactPreview ? 700 : 840)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Entry") {
                    NotificationCenter.default.post(name: .daybookNewEntry, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}

extension Notification.Name {
    static let daybookNewEntry = Notification.Name("daybookNewEntry")
}

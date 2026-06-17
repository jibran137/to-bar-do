import SwiftUI

@main
struct ToBarDoApp: App {
    // The AppDelegate owns the menu bar status item, popover, and main window.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // No window scene: the app is menu-bar-only and the main window is
        // managed by the AppDelegate. `Settings` satisfies the App's required
        // Scene without showing anything at launch.
        Settings {
            EmptyView()
        }
    }
}

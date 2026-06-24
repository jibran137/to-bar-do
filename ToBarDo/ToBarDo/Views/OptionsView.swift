import SwiftUI
import ServiceManagement

/// The little settings popover reached from the gear button in the main window.
/// Auto-archive delay, launch-at-login, and the global shortcut reference.
struct OptionsView: View {
    @EnvironmentObject private var store: TaskStore

    /// Mirrors `SMAppService.mainApp` registration. Seeded from the live status
    /// so the toggle reflects reality each time the popover opens.
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Options")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("Move completed tasks to the archive")
                    .font(.callout)
                Picker("", selection: $store.autoArchiveDelay) {
                    ForEach(AutoArchiveDelay.allCases) { delay in
                        Text(delay.label).tag(delay)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)

                if store.autoArchiveDelay == .custom {
                    Stepper(value: $store.customDays, in: 1...365) {
                        Text("After ^[\(store.customDays) day](inflect: true)")
                    }
                }
            }

            Text("Completed tasks leave your list after this long. They're always kept in the archive until you delete them there.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, wantsEnabled in
                    do {
                        if wantsEnabled {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        // Roll the toggle back to the real state if the system
                        // refused (e.g. running from a quarantined location).
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }
            Text("Start To-Bar-Do automatically when you log in, so ⌥⌘T works without launching it first.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            HStack(spacing: 6) {
                Text("Global shortcut")
                    .font(.callout)
                Spacer()
                Text("⌥⌘T")
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
            }
            Text("Opens To-Bar-Do from any app — no Raycast needed.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(width: 280)
    }
}

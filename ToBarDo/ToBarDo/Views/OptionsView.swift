import SwiftUI

/// The little settings popover reached from the gear button in the main window.
/// Currently just the auto-archive delay; room to grow if more options arrive.
struct OptionsView: View {
    @EnvironmentObject private var store: TaskStore

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

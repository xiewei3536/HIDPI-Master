import SwiftUI

struct SettingsView: View {
    @Binding var isPresented: Bool
    @ObservedObject var l10n = L10n.shared
    @ObservedObject var profiles = ProfileStore.shared
    @ObservedObject var manager = DisplayManager.shared
    @ObservedObject var updater = UpdateChecker.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                section(L("settings.language"), icon: "globe") {
                    Picker("", selection: $l10n.language) {
                        ForEach(L10n.supported, id: \.code) { item in
                            Text(item.code == "auto" ? L(item.nameKey) : item.nameKey)
                                .tag(item.code)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                section(L("settings.pref"), icon: "textformat.size") {
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("", selection: $profiles.sizePreference) {
                            ForEach(ProfileStore.SizePreference.allCases) { pref in
                                Text(L(pref.labelKey)).tag(pref)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        Text(L("settings.pref.desc"))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                section(L("settings.behavior"), icon: "slider.horizontal.3") {
                    VStack(alignment: .leading, spacing: 10) {
                        toggleRow($profiles.advancedMode, "settings.advanced", "settings.advanced.desc")
                        toggleRow($profiles.autoApply, "settings.autoApply", "settings.autoApply.desc")
                        if profiles.supportsLaunchAtLogin {
                            toggleRow($profiles.launchAtLogin, "settings.launchAtLogin", "settings.launchAtLogin.desc")
                        }
                    }
                }

                section(L("settings.updates"), icon: "arrow.down.circle") {
                    VStack(alignment: .leading, spacing: 10) {
                        toggleRow($profiles.autoCheckUpdates, "update.autoCheck", "update.autoCheck.desc")
                        HStack(spacing: 8) {
                            Button {
                                UpdateChecker.shared.check(userInitiated: true)
                            } label: {
                                Text(L("update.check"))
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .controlSize(.small)
                            .disabled(updater.isChecking)
                            if updater.isChecking {
                                ProgressView().controlSize(.small)
                            }
                        }
                    }
                }

                section(L("settings.restoreSection"), icon: "arrow.uturn.backward") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L("settings.restore.desc"))
                            .font(.system(size: 10.5))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button(role: .destructive) {
                            restoreAll()
                        } label: {
                            Text(L("settings.restore"))
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .controlSize(.small)
                    }
                }

                section(L("settings.about"), icon: "info.circle") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("app.name") + " v" + SystemInfo.appVersion)
                            .font(.system(size: 11, weight: .semibold))
                        Text(L("about.text"))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(SystemInfo.chipDescription)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(Color.secondary.opacity(0.7))
                        Link(L("about.github"), destination: URL(string: "https://github.com/xiewei3536/HIDPI-Master")!)
                            .font(.system(size: 10))
                    }
                }
            }
            .padding(14)
        }
    }

    private func toggleRow(_ binding: Binding<Bool>, _ titleKey: String, _ descKey: String) -> some View {
        Toggle(isOn: binding) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L(titleKey))
                    .font(.system(size: 12, weight: .medium))
                Text(L(descKey))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
            }
            content()
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                )
        }
    }

    private func restoreAll() {
        VirtualDisplayController.shared.disableAll()
        let installed = manager.displays.filter { EDIDOverrideInstaller.isInstalled(for: $0) }
        DispatchQueue.global().async {
            var failed = false
            for d in installed {
                do { try EDIDOverrideInstaller.uninstall(for: d) } catch { failed = true }
            }
            DispatchQueue.main.async {
                ProfileStore.shared.resetAll()
                DisplayManager.shared.refreshSoon()
                if failed {
                    Alerts.error(L("err.restoreFailed"), L("err.restoreFailedMsg"))
                } else {
                    Alerts.info(L("settings.restore.doneTitle"), L("settings.restore.doneMsg"))
                }
            }
        }
    }
}

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

                section(L("settings.behavior"), icon: "slider.horizontal.3") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(isOn: $profiles.advancedMode) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L("settings.advanced"))
                                    .font(.system(size: 12, weight: .medium))
                                Text(L("settings.advanced.desc"))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                        .controlSize(.small)

                        Toggle(isOn: $profiles.autoApply) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L("settings.autoApply"))
                                    .font(.system(size: 12, weight: .medium))
                                Text(L("settings.autoApply.desc"))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                        .controlSize(.small)

                        if profiles.supportsLaunchAtLogin {
                            Toggle(isOn: $profiles.launchAtLogin) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(L("settings.launchAtLogin"))
                                        .font(.system(size: 12, weight: .medium))
                                    Text(L("settings.launchAtLogin.desc"))
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .toggleStyle(.switch)
                            .controlSize(.small)
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

                section(L("settings.updates"), icon: "arrow.down.circle") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(isOn: $profiles.autoCheckUpdates) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L("update.autoCheck"))
                                    .font(.system(size: 12, weight: .medium))
                                Text(L("update.autoCheck.desc"))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                        .controlSize(.small)
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
                    }
                }
            }
            .padding(14)
        }
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
        // 1. Tear down all virtual displays
        VirtualDisplayController.shared.disableAll()
        // 2. Remove installed EDID overrides for currently connected displays
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

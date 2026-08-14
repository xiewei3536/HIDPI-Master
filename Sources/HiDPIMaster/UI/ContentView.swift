import SwiftUI

struct ContentView: View {
    @ObservedObject var manager = DisplayManager.shared
    @ObservedObject var l10n = L10n.shared
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if showSettings {
                SettingsView(isPresented: $showSettings)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        if manager.displays.isEmpty {
                            emptyState
                        }
                        ForEach(manager.displays) { display in
                            DisplayCardView(display: display)
                        }
                        tipCard
                    }
                    .padding(12)
                }
            }
            Divider()
            footer
        }
        .frame(width: 420, height: 600)
        .background(WindowBackground())
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color(red: 0.35, green: 0.45, blue: 1.0),
                                 Color(red: 0.65, green: 0.35, blue: 0.95)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 34, height: 34)
                Image(systemName: "sparkles.tv")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(L("app.name"))
                    .font(.system(size: 15, weight: .bold))
                Text(SystemInfo.isAppleSilicon ? L("app.chip.apple") : L("app.chip.intel"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button {
                manager.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .help(L("footer.refresh"))
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showSettings.toggle() }
            } label: {
                Image(systemName: showSettings ? "xmark.circle.fill" : "gearshape.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(showSettings ? .secondary : .primary)
            }
            .buttonStyle(.borderless)
            .help(L("settings.title"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "display.trianglebadge.exclamationmark")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text(L("header.noDisplays"))
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var tipCard: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(.yellow)
                .font(.system(size: 12))
                .padding(.top, 2)
            Text(SystemInfo.isAppleSilicon ? L("tip.appleSilicon") : L("tip.intel"))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    private var footer: some View {
        HStack {
            Text("v" + SystemInfo.appVersion)
                .font(.system(size: 10))
                .foregroundColor(Color.secondary.opacity(0.7))
            Spacer()
            Button {
                NSApp.terminate(nil)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "power")
                        .font(.system(size: 10, weight: .semibold))
                    Text(L("footer.quit"))
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

/// Soft adaptive background for the popover.
struct WindowBackground: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        (scheme == .dark ? Color(nsColor: .windowBackgroundColor) : Color(nsColor: .windowBackgroundColor))
            .overlay(
                LinearGradient(
                    colors: [Color.blue.opacity(scheme == .dark ? 0.06 : 0.04),
                             Color.purple.opacity(scheme == .dark ? 0.05 : 0.03),
                             Color.clear],
                    startPoint: .top, endPoint: .bottom)
            )
    }
}

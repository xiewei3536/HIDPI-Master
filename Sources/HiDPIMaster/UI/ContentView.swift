import SwiftUI

extension Notification.Name {
    static let hidpiContentHeight = Notification.Name("HiDPIMaster.contentHeight")
}

private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

struct ContentView: View {
    static let width: CGFloat = 420
    static let minHeight: CGFloat = 360
    static let maxHeight: CGFloat = 680
    static let settingsHeight: CGFloat = 620
    private static let chromeHeight: CGFloat = 96

    @ObservedObject var manager = DisplayManager.shared
    @ObservedObject var l10n = L10n.shared
    @ObservedObject var profiles = ProfileStore.shared
    @State private var showSettings = false
    @State private var showWelcome = ProfileStore.shared.isFirstLaunch
    @State private var contentHeight: CGFloat = 0

    private var frameHeight: CGFloat {
        showSettings ? Self.settingsHeight
                     : min(max(contentHeight + Self.chromeHeight, Self.minHeight), Self.maxHeight)
    }

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
                        if showWelcome { welcomeCard }
                        if manager.displays.isEmpty { emptyState }
                        ForEach(manager.displays) { display in
                            DisplayCardView(display: display)
                        }
                        if !manager.displays.isEmpty && manager.externalDisplays.isEmpty {
                            noExternalHint
                        }
                        if showTip { tipCard }
                    }
                    .padding(12)
                    .background(GeometryReader { geo in
                        Color.clear.preference(key: ContentHeightKey.self, value: geo.size.height)
                    })
                }
            }
            Divider()
            footer
        }
        .frame(width: Self.width, height: frameHeight)
        .background(WindowBackground())
        .onPreferenceChange(ContentHeightKey.self) { h in
            contentHeight = h
            postHeight()
        }
        .onChange(of: showSettings) { _ in postHeight() }
    }

    private func postHeight() {
        NotificationCenter.default.post(name: .hidpiContentHeight, object: nil,
                                        userInfo: ["height": frameHeight])
    }

    // MARK: - Header

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
            if !showSettings {
                if manager.needsOptimization {
                    Button {
                        manager.optimizeAll()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                            Text(L("header.optimize"))
                        }
                        .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .help(L("header.optimizeHint"))
                } else if manager.allExternalsGood {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.circle.fill")
                        Text(L("header.allGood"))
                    }
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(.green)
                }
            }
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

    // MARK: - Cards

    private var welcomeCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("👋").font(.system(size: 22))
            VStack(alignment: .leading, spacing: 4) {
                Text(L("welcome.title"))
                    .font(.system(size: 12.5, weight: .bold))
                Text(L("welcome.body"))
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showWelcome = false }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(colors: [Color.blue.opacity(0.10), Color.purple.opacity(0.08)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        )
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

    private var noExternalHint: some View {
        HStack(spacing: 10) {
            Image(systemName: "cable.connector")
                .font(.system(size: 18))
                .foregroundColor(.secondary)
            Text(L("hint.noExternal"))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.04)))
    }

    private var showTip: Bool {
        if SystemInfo.isAppleSilicon {
            return manager.displays.contains { $0.isVirtualMirror }
        }
        return manager.externalDisplays.contains { !$0.hasHiDPIModes }
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
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.04)))
    }

    // MARK: - Footer

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
        Color(nsColor: .windowBackgroundColor)
            .overlay(
                LinearGradient(
                    colors: [Color.blue.opacity(scheme == .dark ? 0.06 : 0.04),
                             Color.purple.opacity(scheme == .dark ? 0.05 : 0.03),
                             Color.clear],
                    startPoint: .top, endPoint: .bottom)
            )
    }
}

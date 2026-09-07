import SwiftUI

struct DisplayCardView: View {
    let display: DisplayInfo
    @ObservedObject var manager = DisplayManager.shared
    @ObservedObject var l10n = L10n.shared
    @ObservedObject var profiles = ProfileStore.shared

    @State private var showAllModes = false
    @State private var isWorking = false
    @State private var showEnableSheet = false
    @State private var sliderIndex: Double = 0

    private static let inchChoices: [Double] = [21.5, 24, 27, 32, 34, 38, 43, 49]

    private var isSimple: Bool { !profiles.advancedMode }
    private var topReco: Recommendation? { RecommendationEngine.recommend(for: display).first }
    private var isVirtualActive: Bool { display.isVirtualMirror }
    private var isIntel: Bool { !SystemInfo.isAppleSilicon }

    private var hasUnsavedHiDPI: Bool { manager.needsPersistence(display) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            titleRow
            specRow
            if display.sizeUnknown && !display.isBuiltin {
                sizeAskBanner
            }
            if isVirtualActive {
                virtualBadge
            }
            if let reco = topReco, !display.isBuiltin {
                recommendationBlock(reco)
            }
            if !display.hasHiDPIModes && !display.isBuiltin && !isVirtualActive {
                enableBanner
            }
            if hasUnsavedHiDPI {
                persistBanner
            }
            modesSection
            refreshSection
            if display.hasHiDPIModes && !display.isBuiltin && !isVirtualActive {
                addMoreButton
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
                )
        )
        .sheet(isPresented: $showEnableSheet) {
            EnableHiDPISheet(display: display, isPresented: $showEnableSheet)
        }
    }

    // MARK: - Title & specs

    private var titleRow: some View {
        HStack(spacing: 8) {
            Image(systemName: display.isBuiltin ? "laptopcomputer" : "display")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.accentColor)
            Text(display.name)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            Spacer()
            if let mode = display.currentMode {
                HStack(spacing: 3) {
                    if mode.isHiDPI {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 9))
                        Text("HiDPI")
                            .font(.system(size: 10, weight: .bold))
                    } else {
                        Text(L("badge.lowres"))
                            .font(.system(size: 10, weight: .semibold))
                    }
                }
                .foregroundColor(mode.isHiDPI ? .green : .orange)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill((mode.isHiDPI ? Color.green : Color.orange).opacity(0.12)))
                .help(mode.isHiDPI ? L("badge.hidpi.help") : L("badge.lowres.help"))
            }
        }
    }

    private var specRow: some View {
        HStack(spacing: 6) {
            if !display.isBuiltin {
                sizeMenu
            } else if display.diagonalInches > 1 {
                specChip(inchText(display.diagonalInches))
            }
            if !isSimple {
                if display.diagonalInches > 1 {
                    specChip(L("spec.ppi", Int(display.ppi.rounded())))
                }
                specChip("\(display.nativePixelWidth) × \(display.nativePixelHeight)")
                if let mode = display.currentMode {
                    specChip(L("spec.current", mode.width, mode.height))
                }
            } else if let mode = display.currentMode, display.hasHiDPIModes, !display.sizeUnknown {
                specChip(L("size.current", L(RecommendationEngine.sizeLevelKey(for: display, mode: mode))))
                    .help(modeTooltip(mode))
            }
            Spacer()
        }
    }

    private func inchText(_ inches: Double) -> String {
        let rounded = (inches * 2).rounded() / 2
        let text = rounded == rounded.rounded() ? String(Int(rounded)) : String(format: "%.1f", rounded)
        return text + "\u{2033}"
    }

    /// Screen size chip; click to correct a wrong/missing EDID size.
    private var sizeMenu: some View {
        Menu {
            ForEach(Self.inchChoices, id: \.self) { inch in
                Button {
                    profiles.setManualDiagonal(inch, for: display.persistentKey)
                } label: {
                    if display.manualDiagonalInches == inch {
                        Label(inchText(inch), systemImage: "checkmark")
                    } else {
                        Text(inchText(inch))
                    }
                }
            }
            Divider()
            Button(L("size.auto")) {
                profiles.setManualDiagonal(nil, for: display.persistentKey)
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "ruler")
                    .font(.system(size: 8))
                Text(display.sizeUnknown ? L("size.unknown.chip") : inchText(display.diagonalInches))
            }
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .foregroundColor(display.sizeUnknown ? .accentColor : .secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(display.sizeUnknown ? Color.accentColor.opacity(0.12)
                                                          : Color.primary.opacity(0.05)))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(L("size.chip.help"))
    }

    private func specChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .foregroundColor(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.primary.opacity(0.05)))
    }

    private func modeTooltip(_ mode: ModeInfo) -> String {
        var parts = ["\(mode.width) × \(mode.height)"]
        if mode.isHiDPI { parts.append("HiDPI 2×") }
        if mode.refreshRate > 0 { parts.append(L("refresh.hz", Int(mode.refreshRate.rounded()))) }
        return parts.joined(separator: " · ")
    }

    // MARK: - Banners

    private var sizeAskBanner: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "ruler")
                .font(.system(size: 12))
                .foregroundColor(.accentColor)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 6) {
                Text(L("size.unknown.title"))
                    .font(.system(size: 12, weight: .semibold))
                Text(L("size.unknown.desc"))
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 5) {
                    ForEach(Self.inchChoices.prefix(6), id: \.self) { inch in
                        Button(inchText(inch)) {
                            profiles.setManualDiagonal(inch, for: display.persistentKey)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.accentColor.opacity(0.07)))
    }

    private var virtualBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 11))
                .foregroundColor(.purple)
            Text(L("enable.virtual.running"))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.purple)
            Spacer()
            Button(L("enable.virtual.stop")) {
                VirtualDisplayController.shared.disableHiDPI(for: display)
                manager.refreshSoon()
            }
            .buttonStyle(.borderless)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.purple.opacity(0.08)))
    }

    private var enableBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
                Text(L("enable.banner.title"))
                    .font(.system(size: 12, weight: .semibold))
            }
            Text(L("enable.banner.desc"))
                .font(.system(size: 10.5))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                showEnableSheet = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "wand.and.stars")
                    Text(L("enable.button"))
                }
                .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.orange.opacity(0.08)))
    }

    private var persistBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "externaldrive.badge.exclamationmark")
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
                Text(L("persist.title"))
                    .font(.system(size: 12, weight: .semibold))
            }
            Text(L("persist.desc"))
                .font(.system(size: 10.5))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                saveOverride()
            } label: {
                HStack(spacing: 4) {
                    if isWorking { ProgressView().controlSize(.mini) }
                    Image(systemName: "square.and.arrow.down")
                    Text(L("persist.save"))
                }
                .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(isWorking)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.orange.opacity(0.08)))
    }

    private func saveOverride() {
        guard !isWorking else { return }
        isWorking = true
        let disp = display
        var sizes = disp.uniqueHiDPIModes
            .filter { disp.fitsPanelAspect(width: $0.width, height: $0.height) }
            .map { (w: $0.width, h: $0.height) }
        for c in RecommendationEngine.candidateLooksLikeSizes(for: disp)
        where !sizes.contains(where: { $0.w == c.w && $0.h == c.h }) {
            sizes.append(c)
        }
        // What to switch to once the Mac is back: keep today's HiDPI size if
        // it fits, otherwise the best candidate for this panel.
        let wish: (w: Int, h: Int)? = {
            if let cur = disp.currentMode, cur.isHiDPI, disp.fitsPanelAspect(width: cur.width, height: cur.height) {
                return (cur.width, cur.height)
            }
            return RecommendationEngine.bestCandidate(for: disp)
        }()
        DispatchQueue.global().async {
            do {
                try EDIDOverrideInstaller.install(for: disp, looksLikeSizes: sizes)
                DispatchQueue.main.async {
                    isWorking = false
                    manager.refresh()
                    let decision = Alerts.askReboot()
                    if decision.autoApplyAfterReboot, let wish {
                        ProfileStore.shared.setPendingLooksLike(
                            .init(width: wish.w, height: wish.h), for: disp.persistentKey)
                        if ProfileStore.shared.supportsLaunchAtLogin {
                            ProfileStore.shared.launchAtLogin = true
                        }
                    }
                    if decision.rebootNow {
                        let script = NSAppleScript(source: "tell application \"System Events\" to restart")
                        var err: NSDictionary?
                        script?.executeAndReturnError(&err)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    isWorking = false
                    Alerts.error(L("enable.error"), error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Recommendation

    private func recommendationBlock(_ reco: Recommendation) -> some View {
        let isCurrent = display.currentMode?.resolutionKey == reco.mode?.resolutionKey
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.yellow)
                Text(L("reco.title"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                if !isCurrent { sizePreview(reco) }
            }
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    if isSimple, let mode = reco.mode {
                        Text(L(RecommendationEngine.sizeLevelKey(for: display, mode: mode)) + L("size.crispSuffix"))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .help(modeTooltip(mode))
                    } else {
                        Text(L("reco.looksLike", reco.looksLikeWidth, reco.looksLikeHeight))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    Text(reasonText(reco))
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if isCurrent {
                    Label(L("reco.applied"), systemImage: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.green)
                } else if let mode = reco.mode {
                    Button {
                        applyMode(display.variantKeepingRefresh(of: mode))
                    } label: {
                        Text(L("reco.apply"))
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            preferenceRow
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color.blue.opacity(0.08), Color.purple.opacity(0.06)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
        )
    }

    /// "I prefer: bigger text / balanced / more space" — shifts what counts as just right.
    private var preferenceRow: some View {
        HStack(spacing: 6) {
            Text(L("pref.title"))
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Picker("", selection: $profiles.sizePreference) {
                ForEach(ProfileStore.SizePreference.allCases) { pref in
                    Text(L(pref.labelKey)).tag(pref)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.mini)
            .frame(maxWidth: 190)
            Spacer()
        }
        .help(L("pref.help"))
    }

    /// Tiny "Aa" preview comparing current vs recommended UI size.
    private func sizePreview(_ reco: Recommendation) -> some View {
        let base: CGFloat = 11
        let currentW = CGFloat(display.currentMode?.width ?? display.nativePixelWidth)
        let ratio = currentW > 0 ? CGFloat(reco.looksLikeWidth) / currentW : 1
        let newSize = min(max(base / ratio, 7), 17)
        return HStack(spacing: 4) {
            Text("Aa").font(.system(size: base, weight: .medium))
                .foregroundColor(Color.secondary.opacity(0.55))
            Image(systemName: "arrow.right")
                .font(.system(size: 7))
                .foregroundColor(Color.secondary.opacity(0.5))
            Text("Aa").font(.system(size: newSize, weight: .medium))
                .foregroundColor(.primary.opacity(0.8))
        }
        .help(L("reco.preview.help"))
    }

    private func reasonText(_ reco: Recommendation) -> String {
        reco.reasonKeys.map { L($0) }.joined(separator: L("reco.reasonSeparator"))
    }

    // MARK: - Modes

    private var visibleModes: [ModeInfo] {
        let hidpi = display.uniqueHiDPIModes
        if showAllModes || hidpi.isEmpty { return display.uniqueResolutionModes }
        return hidpi
    }

    @ViewBuilder
    private var modesSection: some View {
        if isSimple {
            if sortedHiDPIModes.count > 1 {
                sizeSliderSection
            }
        } else {
            advancedModesSection
        }
    }

    private var advancedModesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(L("modes.title"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                quickSizeButtons
                if !display.hiDPIModes.isEmpty {
                    Toggle(isOn: $showAllModes.animation(.easeInOut(duration: 0.15))) {
                        Text(L("modes.showAll"))
                            .font(.system(size: 10))
                    }
                    .toggleStyle(.checkbox)
                    .controlSize(.mini)
                }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 6)], spacing: 6) {
                ForEach(visibleModes) { mode in
                    modeChip(mode)
                }
            }
        }
    }

    // MARK: - Simple mode: friendly size slider

    /// Index 0 = biggest text (smallest looks-like), last = most space.
    private var sortedHiDPIModes: [ModeInfo] {
        display.uniqueHiDPIModes
            .filter { display.fitsPanelAspect(width: $0.width, height: $0.height) }
            .sorted { $0.width < $1.width }
    }

    private var currentSliderIndex: Int {
        let sorted = sortedHiDPIModes
        if let i = sorted.firstIndex(where: { $0.resolutionKey == display.currentMode?.resolutionKey }) { return i }
        guard let cur = display.currentMode else { return 0 }
        return sorted.enumerated().min {
            abs($0.element.width - cur.width) < abs($1.element.width - cur.width)
        }?.offset ?? 0
    }

    private var sizeSliderSection: some View {
        let sorted = sortedHiDPIModes
        let idx = min(max(Int(sliderIndex.rounded()), 0), sorted.count - 1)
        let previewMode = sorted[idx]
        let levelText = L(RecommendationEngine.sizeLevelKey(for: display, mode: previewMode))
        let isReco = topReco?.mode?.resolutionKey == previewMode.resolutionKey

        return VStack(alignment: .leading, spacing: 6) {
            Text(L("size.title"))
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
            HStack(spacing: 10) {
                VStack(spacing: 1) {
                    Text("Aa")
                        .font(.system(size: 17, weight: .semibold))
                    Text(L("size.end.larger"))
                        .font(.system(size: 8.5))
                        .foregroundColor(.secondary)
                }
                Slider(
                    value: $sliderIndex,
                    in: 0...Double(sorted.count - 1),
                    step: 1
                ) { editing in
                    if !editing {
                        let i = min(max(Int(sliderIndex.rounded()), 0), sorted.count - 1)
                        if sorted[i].resolutionKey != display.currentMode?.resolutionKey {
                            applyMode(display.variantKeepingRefresh(of: sorted[i]))
                        }
                    }
                }
                .help(modeTooltip(previewMode))
                VStack(spacing: 1) {
                    Text("Aa")
                        .font(.system(size: 11, weight: .semibold))
                    Text(L("size.end.smaller"))
                        .font(.system(size: 8.5))
                        .foregroundColor(.secondary)
                }
            }
            HStack(spacing: 4) {
                Spacer()
                Text(levelText)
                    .font(.system(size: 11, weight: .semibold))
                if isReco {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 7))
                            .foregroundColor(.yellow)
                        Text(L("size.recommended.mark"))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            .help(modeTooltip(previewMode))
        }
        .onAppear { sliderIndex = Double(currentSliderIndex) }
        .onChange(of: display.currentMode?.id) { _ in
            sliderIndex = Double(currentSliderIndex)
        }
    }

    /// A- / A+ quick actions: larger text ↔ more space along HiDPI modes.
    private var quickSizeButtons: some View {
        let sorted = sortedHiDPIModes
        let currentIdx = sorted.firstIndex { $0.resolutionKey == display.currentMode?.resolutionKey }
        return HStack(spacing: 2) {
            Button {
                if let i = currentIdx, i > 0 { applyMode(display.variantKeepingRefresh(of: sorted[i - 1])) }
            } label: {
                Image(systemName: "textformat.size.larger")
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderless)
            .disabled(currentIdx == nil || currentIdx == 0)
            .help(L("action.largerText"))
            Button {
                if let i = currentIdx, i < sorted.count - 1 { applyMode(display.variantKeepingRefresh(of: sorted[i + 1])) }
            } label: {
                Image(systemName: "textformat.size.smaller")
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderless)
            .disabled(currentIdx == nil || currentIdx == sorted.count - 1)
            .help(L("action.moreSpace"))
        }
    }

    private func modeChip(_ mode: ModeInfo) -> some View {
        let isCurrent = display.currentMode?.resolutionKey == mode.resolutionKey
        let isRecommended = topReco?.mode?.resolutionKey == mode.resolutionKey
        let fits = display.fitsPanelAspect(width: mode.width, height: mode.height)
        return Button {
            applyMode(display.variantKeepingRefresh(of: mode))
        } label: {
            HStack(spacing: 3) {
                if isRecommended {
                    Image(systemName: "star.fill")
                        .font(.system(size: 7))
                        .foregroundColor(isCurrent ? .white : .yellow)
                }
                if !fits {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 7))
                        .foregroundColor(isCurrent ? .white : .orange)
                }
                Text(verbatim: "\(mode.width)×\(mode.height)")
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                if mode.isHiDPI {
                    Text("2×")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(isCurrent ? .white.opacity(0.85) : .accentColor)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isCurrent ? Color.accentColor : Color.primary.opacity(0.05))
            )
            .foregroundColor(isCurrent ? .white : .primary)
        }
        .buttonStyle(.plain)
        .help(fits ? L(RecommendationEngine.sizeLevelKey(for: display, mode: mode)) : L("badge.aspectMismatch"))
    }

    // MARK: - Refresh rate (Hz)

    @ViewBuilder
    private var refreshSection: some View {
        if let cur = display.currentMode {
            let variants = display.refreshVariants(of: cur).filter { $0.refreshRate > 0 }
            if variants.count > 1 {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("refresh.title"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                    HStack(spacing: 6) {
                        ForEach(variants) { v in
                            refreshChip(v, isCurrent: abs(v.refreshRate - cur.refreshRate) < 0.5)
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    private func refreshChip(_ v: ModeInfo, isCurrent: Bool) -> some View {
        Button {
            if !isCurrent { applyMode(v) }
        } label: {
            Text(L("refresh.hz", Int(v.refreshRate.rounded())))
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(isCurrent ? Color.accentColor : Color.primary.opacity(0.05))
                )
                .foregroundColor(isCurrent ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    private var addMoreButton: some View {
        Button {
            showEnableSheet = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 10))
                Text(L("modes.addMore"))
                    .font(.system(size: 10.5, weight: .medium))
            }
            .foregroundColor(.secondary)
        }
        .buttonStyle(.borderless)
    }

    // MARK: - Apply

    private func applyMode(_ mode: ModeInfo) {
        guard !isWorking else { return }
        isWorking = true
        let disp = display
        DispatchQueue.main.async {
            DisplayManager.shared.applySafely(mode: mode, to: disp)
            isWorking = false
        }
    }
}

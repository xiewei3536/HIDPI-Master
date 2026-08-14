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

    private var isSimple: Bool { !profiles.advancedMode }

    private var recommendations: [Recommendation] {
        RecommendationEngine.recommend(for: display)
    }

    private var topReco: Recommendation? { recommendations.first }

    private var isVirtualActive: Bool {
        VirtualDisplayController.shared.isVirtualDisplay(display.mirrorsDisplayID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            titleRow
            specRow
            if isVirtualActive {
                virtualBadge
            }
            if let reco = topReco, !display.isBuiltin {
                recommendationBlock(reco)
            }
            if !display.hasHiDPIModes && !display.isBuiltin && !isVirtualActive {
                enableBanner
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

    // MARK: - Rows

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
            }
        }
    }

    private var specRow: some View {
        HStack(spacing: 6) {
            if display.diagonalInches > 1 {
                specChip(String(format: "%.1f\u{2033}", display.diagonalInches))
                if !isSimple {
                    specChip(L("spec.ppi", Int(display.ppi.rounded())))
                }
            }
            if !isSimple {
                specChip("\(display.nativePixelWidth) × \(display.nativePixelHeight)")
                if let mode = display.currentMode {
                    specChip(L("spec.current", mode.width, mode.height))
                }
            } else if let mode = display.currentMode, display.hasHiDPIModes {
                specChip(L("size.current", L(RecommendationEngine.sizeLevelKey(for: display, mode: mode))))
            }
            Spacer()
        }
    }

    private func specChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .foregroundColor(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.primary.opacity(0.05)))
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
                sizePreview(reco)
            }
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    if isSimple, let mode = reco.mode {
                        Text(L(RecommendationEngine.sizeLevelKey(for: display, mode: mode)) + L("size.crispSuffix"))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
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
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color.blue.opacity(0.08), Color.purple.opacity(0.06)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
        )
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
    }

    private func reasonText(_ reco: Recommendation) -> String {
        reco.reasonKeys.map { L($0) }.joined(separator: L("reco.reasonSeparator"))
    }

    // MARK: - Enable banner

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
        // Current mode not HiDPI: point at the nearest looks-like width
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
        return Button {
            applyMode(display.variantKeepingRefresh(of: mode))
        } label: {
            HStack(spacing: 3) {
                if isRecommended {
                    Image(systemName: "star.fill")
                        .font(.system(size: 7))
                        .foregroundColor(isCurrent ? .white : .yellow)
                }
                if !display.fitsPanelAspect(width: mode.width, height: mode.height) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 7))
                        .foregroundColor(isCurrent ? .white : .orange)
                }
                Text("\(mode.width)×\(mode.height)")
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

    private func applyMode(_ mode: ModeInfo) {
        guard !isWorking else { return }
        if !display.fitsPanelAspect(width: mode.width, height: mode.height),
           !Alerts.confirmAspectMismatch() {
            return
        }
        isWorking = true
        DispatchQueue.global().async {
            let ok = DisplayManager.shared.apply(mode: mode, to: display)
            DispatchQueue.main.async {
                isWorking = false
                if !ok {
                    Alerts.error(L("err.applyFailed"), L("err.applyFailedMsg"))
                }
            }
        }
    }
}

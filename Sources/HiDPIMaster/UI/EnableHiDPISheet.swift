import SwiftUI

/// Guided flow to enable HiDPI (or add more HiDPI sizes) for a panel.
/// Intel: EDID override (native after reboot). Apple Silicon: virtual display.
struct EnableHiDPISheet: View {
    let display: DisplayInfo
    @Binding var isPresented: Bool
    @ObservedObject var l10n = L10n.shared

    enum Method: String, CaseIterable {
        case override   // Intel, needs reboot
        case virtual    // no reboot, app must keep running
    }

    @State private var method: Method = SystemInfo.isAppleSilicon ? .virtual : .override
    @State private var selectedSize: String = ""
    @State private var isWorking = false
    @State private var showMismatched = false

    private var candidates: [RecommendationEngine.SizeCandidate] {
        RecommendationEngine.extendedCandidates(for: display)
    }

    private var fitting: [RecommendationEngine.SizeCandidate] { candidates.filter { $0.fits } }
    private var mismatched: [RecommendationEngine.SizeCandidate] { candidates.filter { !$0.fits } }

    private var bestCandidate: (w: Int, h: Int)? {
        RecommendationEngine.bestCandidate(for: display)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.purple)
                Text(display.hasHiDPIModes ? L("enable.sheet.titleMore") : L("enable.sheet.title"))
                    .font(.system(size: 15, weight: .bold))
                Spacer()
            }

            Text(L("enable.sheet.for", display.name))
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            if !SystemInfo.isAppleSilicon {
                Picker("", selection: $method) {
                    Text(L("enable.method.override")).tag(Method.override)
                    Text(L("enable.method.virtual")).tag(Method.virtual)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            methodNote

            VStack(alignment: .leading, spacing: 6) {
                Text(L("enable.pickSize"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 6)], spacing: 6) {
                            ForEach(fitting) { c in sizeChip(c) }
                        }
                        if !mismatched.isEmpty {
                            DisclosureGroup(isExpanded: $showMismatched) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(L("enable.aspectNote"))
                                        .font(.system(size: 10))
                                        .foregroundColor(.orange)
                                        .fixedSize(horizontal: false, vertical: true)
                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 6)], spacing: 6) {
                                        ForEach(mismatched) { c in sizeChip(c) }
                                    }
                                }
                                .padding(.top, 4)
                            } label: {
                                Text(L("enable.mismatchGroup", mismatched.count))
                                    .font(.system(size: 10.5, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.trailing, 2)
                }
                .frame(maxHeight: 170)
                if method == .override {
                    Text(L("enable.override.allNote"))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)

            HStack {
                Button(L("alert.cancel")) { isPresented = false }
                    .controlSize(.large)
                Spacer()
                Button {
                    run()
                } label: {
                    HStack(spacing: 6) {
                        if isWorking {
                            ProgressView().controlSize(.small)
                        }
                        Text(method == .override ? L("enable.run.override") : L("enable.run.virtual"))
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isWorking || selectedSize.isEmpty)
            }
        }
        .padding(18)
        .frame(width: 400, height: 470)
        .onAppear {
            if let best = bestCandidate {
                selectedSize = "\(best.w)x\(best.h)"
            } else if let first = fitting.first ?? candidates.first {
                selectedSize = "\(first.w)x\(first.h)"
            }
        }
    }

    private var methodNote: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: method == .override ? "arrow.triangle.2.circlepath" : "bolt.fill")
                .font(.system(size: 10))
                .foregroundColor(.accentColor)
                .padding(.top, 2)
            Text(method == .override ? L("enable.intel.note") : L("enable.as.note"))
                .font(.system(size: 10.5))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.accentColor.opacity(0.07)))
    }

    private func sizeChip(_ c: RecommendationEngine.SizeCandidate) -> some View {
        let key = "\(c.w)x\(c.h)"
        let isSelected = selectedSize == key
        let isBest = bestCandidate.map { "\($0.w)x\($0.h)" } == key
        let simple = !ProfileStore.shared.advancedMode
        let levelText = L(RecommendationEngine.sizeLevelKey(for: display, looksLikeWidth: c.w, looksLikeHeight: c.h))
        let alreadyHave = display.uniqueHiDPIModes.contains { $0.width == c.w && $0.height == c.h }
        return Button {
            selectedSize = key
        } label: {
            VStack(spacing: 1) {
                HStack(spacing: 3) {
                    if isBest {
                        Image(systemName: "star.fill")
                            .font(.system(size: 7))
                            .foregroundColor(isSelected ? .white : .yellow)
                    }
                    if !c.fits {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 7))
                            .foregroundColor(isSelected ? .white : .orange)
                    }
                    Text(simple ? levelText : "\(c.w)×\(c.h)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
                Text(!c.fits ? L("badge.aspectMismatch")
                     : alreadyHave ? L("enable.alreadyHave")
                     : (simple ? "\(c.w)×\(c.h)" : levelText))
                    .font(.system(size: 8))
                    .foregroundColor(!c.fits ? (isSelected ? .white.opacity(0.9) : .orange)
                                             : (isSelected ? .white.opacity(0.75) : .secondary))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? (c.fits ? Color.accentColor : Color.orange)
                                     : Color.primary.opacity(0.05))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .help("\(c.w) × \(c.h) · HiDPI 2×")
    }

    private var selectedCandidate: (w: Int, h: Int)? {
        let parts = selectedSize.split(separator: "x")
        guard parts.count == 2, let w = Int(parts[0]), let h = Int(parts[1]) else { return nil }
        return (w, h)
    }

    private func run() {
        guard let chosen = selectedCandidate else { return }
        if !display.fitsPanelAspect(width: chosen.w, height: chosen.h),
           !Alerts.confirmAspectMismatch() {
            return
        }
        isWorking = true
        // Install every size that fits the panel, plus the explicit pick.
        var sizes = fitting.map { (w: $0.w, h: $0.h) }
        if !sizes.contains(where: { $0.w == chosen.w && $0.h == chosen.h }) {
            sizes.append(chosen)
        }
        let allSizes = sizes
        let disp = display
        let chosenMethod = method
        DispatchQueue.global().async {
            do {
                switch chosenMethod {
                case .override:
                    try EDIDOverrideInstaller.install(for: disp, looksLikeSizes: allSizes)
                    DispatchQueue.main.async {
                        isWorking = false
                        isPresented = false
                        let decision = Alerts.askReboot()
                        if decision.autoApplyAfterReboot {
                            ProfileStore.shared.setPendingLooksLike(
                                .init(width: chosen.w, height: chosen.h), for: disp.persistentKey)
                            if ProfileStore.shared.supportsLaunchAtLogin {
                                ProfileStore.shared.launchAtLogin = true
                            }
                        }
                        if decision.rebootNow {
                            restartMac()
                        }
                    }
                case .virtual:
                    try VirtualDisplayController.shared.enableHiDPI(for: disp, primaryLooksLike: chosen)
                    DispatchQueue.main.async {
                        isWorking = false
                        isPresented = false
                        DisplayManager.shared.refreshSoon()
                        Alerts.info(L("enable.virtual.doneTitle"), L("enable.virtual.doneMsg"))
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

    private func restartMac() {
        let src = "tell application \"System Events\" to restart"
        let script = NSAppleScript(source: src)
        var err: NSDictionary?
        script?.executeAndReturnError(&err)
    }
}

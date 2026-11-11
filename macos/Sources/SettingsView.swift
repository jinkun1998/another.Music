import SwiftUI
import AppKit

public enum SettingsCategory: String, CaseIterable, Identifiable {
    case customisation = "Customisation"
    case playback = "App Behaviour"
    case audioLab = "Audio Lab"
    case storage = "Storage & iCloud"
    case about = "About"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .customisation: return "paintpalette.fill"
        case .playback: return "gearshape.2.fill"
        case .audioLab: return "waveform.path.ecg"
        case .storage: return "icloud.fill"
        case .about: return "info.circle.fill"
        }
    }
}

@MainActor public struct SettingsView: View {
    @State private var selectedCategory: SettingsCategory = .customisation
    @Namespace private var catNamespace

    // Customisation
    @AppStorage("defaultPlayerStyle") private var defaultPlayerStyle: String = "Vinyl"
    @AppStorage("discRotatingAnimation") private var discRotatingAnimation: Bool = true
    @AppStorage("backgroundGlow") private var backgroundGlow: Bool = true
    @AppStorage("tonearmInteractive") private var tonearmInteractive: Bool = true
    @AppStorage("lyricsFontSize") private var lyricsFontSize: String = "Regular"

    // App Behaviour
    @AppStorage("restoreLastState") private var restoreLastState: Bool = true

    // Audio Lab (Equalizer, Crossfade, AutoMix)
    @AppStorage("eqEnabled") private var eqEnabled: Bool = false
    @AppStorage("eqPreset") private var eqPreset: String = "Flat"
    @AppStorage("eqBand60") private var eqBand60: Double = 0.0
    @AppStorage("eqBand230") private var eqBand230: Double = 0.0
    @AppStorage("eqBand910") private var eqBand910: Double = 0.0
    @AppStorage("eqBand3600") private var eqBand3600: Double = 0.0
    @AppStorage("eqBand14000") private var eqBand14000: Double = 0.0
    @AppStorage("crossfadeEnabled") private var crossfadeEnabled: Bool = false
    @AppStorage("crossfadeDuration") private var crossfadeDuration: Double = 5.0
    @AppStorage("automixEnabled") private var automixEnabled: Bool = true
    @AppStorage("audioQuality") private var audioQuality: String = "High"

    @ObservedObject private var player = AudioPlayerService.shared
    @ObservedObject private var library = LibraryStore.shared

    @State private var showingClearAlert: Bool = false

    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            // Left Navigation Sidebar
            VStack(alignment: .leading, spacing: 4) {
                Text("Settings")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 12)

                ForEach(SettingsCategory.allCases) { cat in
                    let isSelected = selectedCategory == cat
                    Button(action: {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            selectedCategory = cat
                        }
                    }) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isSelected ? Color.white.opacity(0.22) : Color.white.opacity(0.08))
                                    .frame(width: 28, height: 28)

                                Image(systemName: cat.icon)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                            }

                            Text(cat.rawValue)
                                .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                                .foregroundColor(isSelected ? .white : .white.opacity(0.72))

                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white.opacity(0.12))
                                    .matchedGeometryEffect(id: "cat_pill", in: catNamespace)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .frame(width: 200)
            .padding(10)
            .background(Color(red: 14/255, green: 14/255, blue: 16/255))

            Divider()
                .background(Color.white.opacity(0.08))

            // Right Detail Area with Spring Slide & Fade Animation
            ScrollView(.vertical, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    switch selectedCategory {
                    case .customisation:
                        customisationSection
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .trailing)),
                                removal: .opacity.combined(with: .move(edge: .leading))
                            ))
                    case .playback:
                        playbackSection
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .trailing)),
                                removal: .opacity.combined(with: .move(edge: .leading))
                            ))
                    case .audioLab:
                        audioLabSection
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .trailing)),
                                removal: .opacity.combined(with: .move(edge: .leading))
                            ))
                    case .storage:
                        storageSection
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .trailing)),
                                removal: .opacity.combined(with: .move(edge: .leading))
                            ))
                    case .about:
                        aboutSection
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .trailing)),
                                removal: .opacity.combined(with: .move(edge: .leading))
                            ))
                    }
                }
                .padding(22)
                .animation(.spring(response: 0.35, dampingFraction: 0.84), value: selectedCategory)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 10/255, green: 10/255, blue: 12/255))
        }
        .frame(width: 780, height: 530)
        .alert("Clear Playback History?", isPresented: $showingClearAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) { library.clearHistory() }
        }
    }

    // MARK: - Customisation
    private var customisationSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader(title: "Customisation", subtitle: "Turntable player, vinyl animation, and visual styles")

            SettingsGroupCard {
                SettingsRow(icon: "record.circle", title: "Default Player Style", subtitle: "Initial view when maximizing song deck") {
                    AppSegmentedPicker(
                        options: [
                            ("Turntable", "Vinyl"),
                            ("Cover", "Cover")
                        ],
                        selection: $defaultPlayerStyle
                    )
                }

                Divider().background(Color.white.opacity(0.06))

                SettingsRow(icon: "arrow.triangle.2.circlepath", title: "Disc Rotating Animation", subtitle: "26 deg/sec turntable rotation matching Android") {
                    Toggle("", isOn: $discRotatingAnimation)
                        .toggleStyle(.switch)
                }

                Divider().background(Color.white.opacity(0.06))

                SettingsRow(icon: "hand.draw.fill", title: "Interactive Tonearm", subtitle: "Drag turntable stylus to seek audio position") {
                    Toggle("", isOn: $tonearmInteractive)
                        .toggleStyle(.switch)
                }

                Divider().background(Color.white.opacity(0.06))

                SettingsRow(icon: "sun.max.fill", title: "Backdrop Cover Glow", subtitle: "Ambient dark blur wash above album art") {
                    Toggle("", isOn: $backgroundGlow)
                        .toggleStyle(.switch)
                }
            }

            SettingsGroupCard {
                SettingsRow(icon: "text.quote", title: "Lyrics Font Size", subtitle: "Synced lyrics line typography") {
                    AppSegmentedPicker(
                        options: [
                            ("Regular", "Regular"),
                            ("Large", "Large")
                        ],
                        selection: $lyricsFontSize
                    )
                }
            }
        }
    }

    // MARK: - App Behaviour
    private var playbackSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader(title: "App Behaviour", subtitle: "Autoplay, persistence, and queue automation")

            SettingsGroupCard {
                SettingsRow(icon: "infinity", title: "Autoplay Radio", subtitle: "Appends 50-song YouTube Automix station when queue ends") {
                    Toggle("", isOn: Binding(
                        get: { player.isAutoplay },
                        set: { _ in player.toggleAutoplay() }
                    ))
                    .toggleStyle(.switch)
                }

                Divider().background(Color.white.opacity(0.06))

                SettingsRow(icon: "clock.arrow.circlepath", title: "Restore Last Track", subtitle: "Prepares last played history item on startup") {
                    Toggle("", isOn: $restoreLastState)
                        .toggleStyle(.switch)
                }

                Divider().background(Color.white.opacity(0.06))

                SettingsRow(icon: "moon.stars.fill", title: "Sleep Timer", subtitle: "Automatically pauses audio playback") {
                    AppMenuPicker(
                        options: SleepTimerOption.allCases.map { ($0.rawValue, $0) },
                        selection: Binding(
                            get: { player.sleepTimerOption },
                            set: { player.setSleepTimer($0) }
                        )
                    )
                }
            }
        }
    }

    // MARK: - Audio Lab (Equalizer, Crossfade, AutoMix)
    private var audioLabSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader(title: "Audio Lab", subtitle: "Equalizer, Crossfade transitions, and AutoMix")

            // Equalizer Group
            SettingsGroupCard {
                SettingsRow(icon: "slider.vertical.3", title: "Equalizer", subtitle: "Pro-grade acoustic frequency tuning") {
                    Toggle("", isOn: Binding(
                        get: { player.isEqEnabled },
                        set: { _ in
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                player.toggleEqualizer()
                            }
                        }
                    ))
                    .toggleStyle(.switch)
                }

                if player.isEqEnabled {
                    Divider().background(Color.white.opacity(0.06))

                    SettingsRow(icon: "waveform", title: "Equalizer Preset", subtitle: "Tune sound profile to your headphones or speakers") {
                        AppMenuPicker(
                            options: ["Flat", "Bass Boost", "Treble Boost", "Vocal", "Electronic", "Rock", "Acoustic"].map { ($0, $0) },
                            selection: $eqPreset,
                            onChange: { applyPreset($0) }
                        )
                    }

                    Divider().background(Color.white.opacity(0.06))

                    // Animated Equalizer Visualizer Bars
                    VStack(spacing: 12) {
                        HStack(spacing: 16) {
                            eqSlider(label: "60Hz", value: $eqBand60)
                            eqSlider(label: "230Hz", value: $eqBand230)
                            eqSlider(label: "910Hz", value: $eqBand910)
                            eqSlider(label: "3.6kHz", value: $eqBand3600)
                            eqSlider(label: "14kHz", value: $eqBand14000)
                        }
                        .padding(.vertical, 8)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            // Crossfade & AutoMix Group
            SettingsGroupCard {
                SettingsRow(icon: "wand.and.stars", title: "Transition Mode", subtitle: "") {
                    AppSegmentedPicker(
                        options: [
                            ("Auto Mix", TransitionMode.automix),
                            ("Cross Fade", TransitionMode.crossfade),
                            ("Off", TransitionMode.off)
                        ],
                        selection: Binding(
                            get: { player.transitionMode },
                            set: { player.setTransitionMode($0) }
                        )
                    )
                }

                if player.transitionMode != .off {
                    Divider().background(Color.white.opacity(0.06))

                    SettingsRow(icon: "timer", title: "Blend Duration", subtitle: String(format: "%.1f seconds", crossfadeDuration)) {
                        HStack(spacing: 8) {
                            Slider(value: $crossfadeDuration, in: 2...12, step: 0.5)
                                .frame(width: 120)
                                .accentColor(.white)
                            Text(String(format: "%.1fs", crossfadeDuration))
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.75))
                                .frame(width: 36, alignment: .trailing)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            // Streaming Bitrate
            SettingsGroupCard {
                SettingsRow(icon: "hifispeaker.and.homepodmini.fill", title: "Streaming Quality", subtitle: "YouTube Music adaptive AAC bitrate") {
                    AppSegmentedPicker(
                        options: [
                            ("High 256k", "High"),
                            ("Normal 128k", "Normal"),
                            ("Saver 64k", "Saver")
                        ],
                        selection: $audioQuality
                    )
                }
            }
        }
    }

    // MARK: - Storage & iCloud
    private var storageSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader(title: "Storage & iCloud", subtitle: "Cloud synchronization and local database")

            SettingsGroupCard {
                SettingsRow(icon: "icloud.fill", title: "iCloud Sync", subtitle: library.isSyncEnabled ? "Syncing liked songs, history, and profile via iCloud Drive" : "Sync disabled (using local storage only)") {
                    Toggle("", isOn: $library.isSyncEnabled)
                        .toggleStyle(.switch)
                }
            }

            SettingsGroupCard {
                SettingsRow(icon: "music.note.list", title: "Favorites Cached", subtitle: "\(library.likedSongs.count) songs saved") {
                    EmptyView()
                }

                Divider().background(Color.white.opacity(0.06))

                SettingsRow(icon: "clock.fill", title: "History Entries", subtitle: "\(library.history.count) songs logged") {
                    Button("Clear History", role: .destructive) {
                        showingClearAlert = true
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    // MARK: - About (Clean, Minimal, using App Icon)
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(title: "About", subtitle: "another.Music")

            SettingsGroupCard {
                HStack(spacing: 20) {
                    if let icon = loadAppIcon() {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 76, height: 76)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
                    } else {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(LinearGradient(colors: [.black, Color(white: 0.15)], startPoint: .top, endPoint: .bottom))
                            .frame(width: 76, height: 76)
                            .overlay(Image(systemName: "record.circle").font(.system(size: 38)).foregroundColor(.white))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("another.Music")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("Version 1.0.0")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.55))

                        Text("Compatible with Mochy Music & YouTube InnerTube")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.45))
                            .padding(.top, 2)
                    }

                    Spacer()
                }
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Helpers
    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.bottom, 2)
    }

    private func eqSlider(label: String, value: Binding<Double>) -> some View {
        VStack(spacing: 6) {
            Text(String(format: "%+.0fdB", value.wrappedValue))
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))

            Slider(value: value, in: -12...12, step: 1)
                .frame(width: 80)
                .rotationEffect(.degrees(-90))
                .frame(width: 40, height: 90)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    private func applyPreset(_ preset: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            switch preset {
            case "Bass Boost":
                eqBand60 = 7; eqBand230 = 5; eqBand910 = 1; eqBand3600 = 0; eqBand14000 = 0
            case "Treble Boost":
                eqBand60 = 0; eqBand230 = 1; eqBand910 = 3; eqBand3600 = 6; eqBand14000 = 8
            case "Vocal":
                eqBand60 = -2; eqBand230 = 2; eqBand910 = 6; eqBand3600 = 4; eqBand14000 = 1
            case "Electronic":
                eqBand60 = 6; eqBand230 = 4; eqBand910 = -1; eqBand3600 = 3; eqBand14000 = 5
            case "Rock":
                eqBand60 = 5; eqBand230 = 3; eqBand910 = -2; eqBand3600 = 4; eqBand14000 = 6
            case "Acoustic":
                eqBand60 = 3; eqBand230 = 2; eqBand910 = 2; eqBand3600 = 4; eqBand14000 = 3
            default: // Flat
                eqBand60 = 0; eqBand230 = 0; eqBand910 = 0; eqBand3600 = 0; eqBand14000 = 0
            }
        }
    }

    private func loadAppIcon() -> NSImage? {
        if let icon = NSImage(named: NSImage.applicationIconName), icon.isValid {
            return icon
        }
        if let path = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
           let icon = NSImage(contentsOfFile: path) {
            return icon
        }
        // Fallback to Resources/icon.png
        let iconPng = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/icon.png")
        if let icon = NSImage(contentsOf: iconPng) {
            return icon
        }
        return nil
    }
}

// Android-matched Card Container (SearchColors.Field / Grouped Card)
private struct SettingsGroupCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(red: 22/255, green: 22/255, blue: 25/255))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
}

// Android-matched SettingsItemRow with flexible label constraints
private struct SettingsRow<Trailing: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 34, height: 34)

                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.85))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing()
        }
        .padding(.vertical, 10)
    }
}

// Sleek capsule-styled segmented control matching player UI
private struct AppSegmentedPicker<T: Hashable>: View {
    let options: [(label: String, value: T)]
    @Binding var selection: T

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.value) { opt in
                let isSelected = selection == opt.value
                Button(action: {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        selection = opt.value
                    }
                }) {
                    Text(opt.label)
                        .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                        .foregroundColor(isSelected ? .white : .white.opacity(0.60))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(Color.white.opacity(0.20))
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.white.opacity(0.08))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
    }
}

// Sleek capsule-styled menu picker matching player UI
private struct AppMenuPicker<T: Hashable>: View {
    let options: [(label: String, value: T)]
    @Binding var selection: T
    var onChange: ((T) -> Void)? = nil

    private var currentLabel: String {
        options.first(where: { $0.value == selection })?.label ?? "\(selection)"
    }

    var body: some View {
        Menu {
            ForEach(options, id: \.value) { opt in
                Button(action: {
                    selection = opt.value
                    onChange?(opt.value)
                }) {
                    HStack {
                        Text(opt.label)
                        if selection == opt.value {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(currentLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white.opacity(0.55))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.10))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}

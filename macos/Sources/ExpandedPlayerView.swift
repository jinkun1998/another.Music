import SwiftUI
import AppKit

@MainActor public struct ExpandedPlayerView: View {
    let track: SongItem
    @ObservedObject var player: AudioPlayerService
    let onClose: () -> Void

    @ObservedObject private var library = LibraryStore.shared
    @State private var lyrics: [LyricLine] = []
    @State private var isLoadingLyrics: Bool = false
    @State private var useVinyl: Bool = true
    @State private var swipeMonitor = SwipeDismissMonitor()
    @State private var isSeeking: Bool = false
    @State private var seekProgress: Double = 0.0
    @State private var showQueue: Bool = false
    @State private var dragOffset: CGFloat = 0.0

    private var activeTrack: SongItem {
        player.currentTrack ?? track
    }

    public var body: some View {
        ZStack {
            // Solid hit-testable base: blocks clicks reaching screens underneath
            Color.black.ignoresSafeArea()

            // Android Turntable dim room backdrop with persistent image stack (never flashes black)
            CrossfadingBackdrop(
                currentThumbnail: activeTrack.thumbnail,
                incomingThumbnail: player.isTransitioning ? player.incomingTrack?.thumbnail : nil,
                transitionProgress: player.uiTransitionProgress
            )

            VStack(spacing: 0) {
                // Top header bar (inset from left traffic lights so macOS window buttons never overlap)
                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .bold))
                        Text("Hide")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1))
                    .contentShape(Capsule())
                    .onTapGesture { onClose() }
                    .keyboardShortcut(.escape, modifiers: [])

                    Spacer()

                    // Cover mode / Vinyl mode switcher
                    HStack(spacing: 6) {
                        Image(systemName: useVinyl ? "record.circle" : "square.stack.fill")
                            .font(.system(size: 13))
                        Text(useVinyl ? "Vinyl" : "Cover")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.10))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                    .contentShape(Capsule())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            useVinyl.toggle()
                        }
                    }

                    // Transition Mode Selector (AutoMix, Crossfade, Off)
                    HStack(spacing: 6) {
                        if player.isTransitioning {
                            AnimatedTransitionIcon(mode: player.transitionMode, isTransitioning: true)
                        } else {
                            Image(systemName: player.transitionMode == .automix ? "wand.and.stars" : (player.transitionMode == .crossfade ? "waveform.badge.magnifyingglass" : "circle.slash"))
                                .font(.system(size: 13, weight: .semibold))
                        }
                        Text(player.transitionMode.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(player.transitionMode != .off ? .white : .white.opacity(0.60))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        player.transitionMode != .off ? Color.white.opacity(0.22) : Color.white.opacity(0.10)
                    )
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(
                            player.transitionMode != .off ? Color.white.opacity(0.25) : Color.white.opacity(0.15),
                            lineWidth: 1
                        )
                    )
                    .contentShape(Capsule())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            switch player.transitionMode {
                            case .automix: player.setTransitionMode(.crossfade)
                            case .crossfade: player.setTransitionMode(.off)
                            case .off: player.setTransitionMode(.automix)
                            }
                        }
                    }

                    // Queue drawer toggle
                    HStack(spacing: 6) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Queue")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(showQueue ? Color.white.opacity(0.22) : Color.white.opacity(0.10))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                    .contentShape(Capsule())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            showQueue.toggle()
                        }
                    }

                    // Sleep Timer
                    HStack(spacing: 6) {
                        Image(systemName: player.sleepTimerOption != .off ? "moon.stars.fill" : "moon.stars")
                            .font(.system(size: 13, weight: .semibold))
                        Text(player.sleepTimerOption == .off ? "Timer" : player.sleepTimerOption.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(player.sleepTimerOption != .off ? Color.white.opacity(0.20) : Color.white.opacity(0.10))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                    .contentShape(Capsule())
                    .onTapGesture {
                        let all = SleepTimerOption.allCases
                        let idx = all.firstIndex(of: player.sleepTimerOption) ?? 0
                        let next = all[(idx + 1) % all.count]
                        player.setSleepTimer(next)
                    }


                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .contentShape(Rectangle())
                .gesture(dismissDragGesture)

                // Main two-column content
                HStack(spacing: 24) {
                    // Left Column: Integrated Vinyl/Cover Player Deck
                    GeometryReader { geo in
                    let deckW = min(geo.size.width, max(320, geo.size.height - 250), 520)
                    VStack(spacing: 14) {
                        Spacer(minLength: 0)

                        // Artwork / Vinyl Deck
                        ZStack {
                            if useVinyl {
                                TurntableCanvas(
                                    thumbnail: activeTrack.thumbnail,
                                    title: activeTrack.title,
                                    isPlaying: player.isPlaying,
                                    progress: player.progress,
                                    incomingThumbnail: player.isTransitioning ? player.incomingTrack?.thumbnail : nil,
                                    incomingTitle: player.isTransitioning ? player.incomingTrack?.title : nil,
                                    transitionProgress: player.uiTransitionProgress,
                                    onSeek: { player.seek(to: $0) }
                                )
                                .frame(width: deckW, height: deckW)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.88).combined(with: .opacity),
                                    removal: .scale(scale: 0.88).combined(with: .opacity)
                                ))
                            } else {
                                ZStack {
                                    if let thumb = activeTrack.thumbnail {
                                        CachedAsyncImage(urlString: thumb) { img in
                                            img.resizable().aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Color.gray.opacity(0.3)
                                        }
                                        .frame(width: deckW * 0.94, height: deckW * 0.94)
                                        .clipShape(RoundedRectangle(cornerRadius: 24))
                                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.15), lineWidth: 1))
                                        .shadow(color: .black.opacity(0.4), radius: 25, y: 12)
                                    }

                                    if player.isTransitioning, let incoming = player.incomingTrack, let thumb = incoming.thumbnail {
                                        CachedAsyncImage(urlString: thumb) { img in
                                            img.resizable().aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Color.clear
                                        }
                                        .frame(width: deckW * 0.94, height: deckW * 0.94)
                                        .clipShape(RoundedRectangle(cornerRadius: 24))
                                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.15), lineWidth: 1))
                                        .shadow(color: .black.opacity(0.4), radius: 25, y: 12)
                                        .opacity(player.uiTransitionProgress)
                                    }
                                }
                                .scaleEffect(player.isPlaying ? 1.0 : 0.94)
                                .animation(.easeInOut(duration: 0.4), value: player.isPlaying)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.88).combined(with: .opacity),
                                    removal: .scale(scale: 0.88).combined(with: .opacity)
                                ))
                            }
                        }

                        // Track Title, Artist & Like Button
                        HStack(spacing: 14) {
                            ZStack(alignment: .leading) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(activeTrack.title)
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    Text(activeTrack.artist)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                        .lineLimit(1)
                                }
                                .opacity(player.isTransitioning ? (1.0 - player.uiTransitionProgress) : 1.0)

                                if let incoming = player.incomingTrack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(incoming.title)
                                            .font(.system(size: 22, weight: .bold))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                        Text(incoming.artist)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(.white.opacity(0.7))
                                            .lineLimit(1)
                                    }
                                    .opacity(player.uiTransitionProgress)
                                }
                            }

                            Spacer()

                            let targetTrack = (player.isTransitioning && player.uiTransitionProgress >= 0.5) ? (player.incomingTrack ?? activeTrack) : activeTrack
                            Image(systemName: library.isLiked(targetTrack) ? "heart.fill" : "heart")
                                .font(.system(size: 20))
                                .foregroundColor(library.isLiked(targetTrack) ? .white : .white.opacity(0.7))
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                                .onTapGesture { library.toggleLike(targetTrack) }
                        }
                        .frame(width: deckW)
                        .padding(.top, 4)

                        // Scrubber Slider
                        VStack(spacing: 6) {
                            GeometryReader { geo in
                                let activeVal = isSeeking ? seekProgress : player.progress
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.15))
                                        .frame(height: 5)

                                    Capsule()
                                        .fill(.white)
                                        .frame(width: max(geo.size.width * activeVal, 0), height: 5)

                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 13, height: 13)
                                        .shadow(radius: 4)
                                        .offset(x: max(geo.size.width * activeVal - 6.5, 0))
                                }
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            isSeeking = true
                                            seekProgress = min(max(value.location.x / geo.size.width, 0.0), 1.0)
                                        }
                                        .onEnded { value in
                                            let finalVal = min(max(value.location.x / geo.size.width, 0.0), 1.0)
                                            isSeeking = false
                                            player.seek(to: finalVal)
                                        }
                                )
                            }
                            .frame(height: 14)

                            HStack {
                                let curSec = isSeeking ? (seekProgress * player.durationSec) : player.positionSec
                                Text(formatTime(curSec))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.55))

                                Spacer()

                                Text(formatTime(player.durationSec))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.55))
                            }
                        }
                        .frame(width: deckW)
                        .onChange(of: player.positionSec) { _, _ in
                            if isSeeking { isSeeking = false }
                        }

                        // Transport Controls directly below Turntable
                        HStack(spacing: 24) {
                            Image(systemName: "shuffle")
                                .font(.system(size: 16, weight: player.isShuffle ? .bold : .regular))
                                .foregroundColor(player.isShuffle ? .white : .white.opacity(0.6))
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                                .onTapGesture { player.toggleShuffle() }

                            Image(systemName: "backward.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                                .onTapGesture { player.previous() }

                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.14))
                                    .frame(width: 56, height: 56)

                                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .contentShape(Circle())
                            .onTapGesture { player.togglePlayPause() }

                            Image(systemName: "forward.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                                .onTapGesture { player.next() }

                            Image(systemName: player.repeatMode == .one ? "repeat.1" : "repeat")
                                .font(.system(size: 16, weight: player.repeatMode != .off ? .bold : .regular))
                                .foregroundColor(player.repeatMode != .off ? .white : .white.opacity(0.6))
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                                .onTapGesture { player.cycleRepeatMode() }
                        }
                        .frame(width: deckW)

                        // Volume Slider
                        HStack(spacing: 10) {
                            Image(systemName: "speaker.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.4))
                            // ponytail: pure SwiftUI slider; NSSlider-backed Slider crashed hit-testing
                            GeometryReader { g in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.white.opacity(0.15)).frame(height: 4)
                                    Capsule().fill(Color.white).frame(width: g.size.width * CGFloat(player.volume), height: 4)
                                }
                                .frame(maxHeight: .infinity)
                                .contentShape(Rectangle())
                                .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                                    player.setVolume(Float(min(max(v.location.x / g.size.width, 0), 1)))
                                })
                            }
                            .frame(width: 140, height: 16)
                            Image(systemName: "speaker.wave.3.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .padding(.top, 2)

                        Spacer(minLength: 0)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    }
                    .frame(maxWidth: .infinity)

                    // Right Column: Synced Lyrics panel OR Queue Drawer
                    ZStack {
                        if showQueue {
                            QueueDrawerView(player: player)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                                    removal: .opacity.combined(with: .move(edge: .trailing))
                                ))
                        } else {
                            SyncedLyricsView(
                                lyrics: lyrics,
                                isLoading: isLoadingLyrics,
                                currentTimeMs: Int64(player.positionSec * 1000),
                                durationMs: Int64(player.durationSec * 1000),
                                onSeek: { player.seek(to: $0) }
                            )
                            .opacity(player.isTransitioning ? max(0.18, 1.0 - player.uiTransitionProgress) : 1.0)
                            .background(Color.white.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.08), lineWidth: 1))
                            .transition(.asymmetric(
                                insertion: .opacity,
                                removal: .opacity
                            ))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
        }
        .offset(y: dragOffset)
        .onAppear { swipeMonitor.start(onDismiss: onClose) }
        .onDisappear { swipeMonitor.stop() }
        .task(id: activeTrack.id) {
            self.lyrics = []
            self.isLoadingLyrics = true
            let fetched = await LyricsService.shared.fetchLyrics(
                videoId: activeTrack.id,
                title: activeTrack.title,
                artist: activeTrack.artist,
                durationSec: Int(player.durationSec)
            )
            if !Task.isCancelled {
                self.lyrics = fetched
                self.isLoadingLyrics = false
            }
        }
    }

    private var dismissDragGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                if value.translation.height > 0 && abs(value.translation.height) > abs(value.translation.width) {
                    dragOffset = value.translation.height * 0.75
                }
            }
            .onEnded { value in
                if value.translation.height > 55 || value.predictedEndTranslation.height > 120 {
                    dragOffset = 0
                    onClose()
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        dragOffset = 0
                    }
                }
            }
    }

    private func formatTime(_ sec: Double) -> String {
        guard sec.isFinite && sec >= 0 else { return "0:00" }
        let total = Int(sec)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}

/// ponytail: plain NSEvent monitor; NSViewRepresentable background crashed SwiftUI hit-testing during track swaps.
@MainActor
private final class SwipeDismissMonitor {
    private var monitor: Any?
    private var accumulatedDeltaY: CGFloat = 0

    func start(onDismiss: @escaping () -> Void) {
        stop()
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .keyDown]) { [weak self] event in
            guard let self else { return event }
            if event.type == .keyDown && event.keyCode == 53 {
                DispatchQueue.main.async { onDismiss() }
                return nil
            }
            guard event.type == .scrollWheel, let window = event.window else { return event }
            let loc = event.locationInWindow
            guard loc.y > (window.frame.height - 95) || loc.x < (window.frame.width * 0.50) else { return event }
            if event.phase == .began { self.accumulatedDeltaY = 0 }
            let dy = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.deltaY * 10
            if abs(dy) > abs(event.scrollingDeltaX) {
                self.accumulatedDeltaY += abs(dy)
                if self.accumulatedDeltaY > 95 {
                    self.accumulatedDeltaY = 0
                    DispatchQueue.main.async { onDismiss() }
                }
            }
            return event
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}


@MainActor
private struct CrossfadingBackdrop: View {
    let currentThumbnail: String?
    let incomingThumbnail: String?
    let transitionProgress: Double

    @State private var currentImage: NSImage?
    @State private var incomingImage: NSImage?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black

                if let img = currentImage {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .saturation(0.7)
                        .blur(radius: 80)
                        .overlay(Color.black.opacity(0.50))
                }

                if let inImg = incomingImage {
                    Image(nsImage: inImg)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .saturation(0.7)
                        .blur(radius: 80)
                        .overlay(Color.black.opacity(0.50))
                        .opacity(transitionProgress)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            loadCurrent(url: currentThumbnail)
            loadIncoming(url: incomingThumbnail)
        }
        .onChange(of: currentThumbnail) { _, newUrl in
            loadCurrent(url: newUrl)
        }
        .onChange(of: incomingThumbnail) { _, newUrl in
            loadIncoming(url: newUrl)
        }
    }

    private func loadCurrent(url: String?) {
        guard let url, !url.isEmpty else { return }
        if let cached = ImageCache.shared.image(for: url) {
            currentImage = cached
            return
        }
        guard let u = URL(string: url) else { return }
        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: u),
                  let img = NSImage(data: data) else { return }
            await MainActor.run {
                ImageCache.shared.insert(img, for: url)
                if currentThumbnail == url {
                    currentImage = img
                }
            }
        }
    }

    private func loadIncoming(url: String?) {
        guard let url, !url.isEmpty else {
            incomingImage = nil
            return
        }
        if let cached = ImageCache.shared.image(for: url) {
            incomingImage = cached
            return
        }
        guard let u = URL(string: url) else { return }
        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: u),
                  let img = NSImage(data: data) else { return }
            await MainActor.run {
                ImageCache.shared.insert(img, for: url)
                if incomingThumbnail == url {
                    incomingImage = img
                }
            }
        }
    }
}


private struct AnimatedTransitionIcon: View {
    let mode: TransitionMode
    let isTransitioning: Bool

    @State private var pulse = false

    var body: some View {
        Image(systemName: mode == .automix ? "wand.and.stars" : (mode == .crossfade ? "waveform.badge.magnifyingglass" : "circle.slash"))
            .font(.system(size: 13, weight: .semibold))
            .symbolEffect(.variableColor.iterative, isActive: isTransitioning)
            .symbolEffect(.pulse, isActive: isTransitioning)
            .scaleEffect(isTransitioning ? (pulse ? 1.18 : 0.95) : 1.0)
            .rotationEffect(.degrees(isTransitioning ? (pulse ? -8 : 6) : 0))
            .animation(
                isTransitioning
                    ? .easeInOut(duration: 0.65).repeatForever(autoreverses: true)
                    : .spring(response: 0.35, dampingFraction: 0.8),
                value: pulse
            )
            .onAppear {
                if isTransitioning { pulse = true }
            }
            .onChange(of: isTransitioning) { _, mixing in
                pulse = mixing
            }
    }
}

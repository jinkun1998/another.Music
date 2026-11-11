import SwiftUI
import AppKit

public struct ExpandedPlayerView: View {
    let track: SongItem
    @ObservedObject var player: AudioPlayerService
    let onClose: () -> Void

    @ObservedObject private var library = LibraryStore.shared
    @State private var lyrics: [LyricLine] = []
    @State private var isLoadingLyrics: Bool = false
    @State private var useVinyl: Bool = true
    @State private var isSeeking: Bool = false
    @State private var seekProgress: Double = 0.0
    @State private var showQueue: Bool = false
    @State private var dragOffset: CGFloat = 0.0

    public var body: some View {
        ZStack {
            // Solid hit-testable base: blocks clicks reaching screens underneath
            Color.black.ignoresSafeArea()

            // Android Turntable dim room backdrop (cover glow + 0.58 black dim)
            // Clipped + hit-testing disabled so overflowing .fill image never blocks header buttons
            GeometryReader { geo in
                ZStack {
                    Color.black
                    if let thumb = track.thumbnail, let url = URL(string: thumb) {
                        AsyncImage(url: url) { phase in
                            if let img = phase.image {
                                img.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                Color.black
                            }
                        }
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .saturation(0.6)
                        .blur(radius: 90)
                        .overlay(Color.black.opacity(0.58))
                    }
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                // Top header bar (inset from left traffic lights so macOS window buttons never overlap)
                HStack(spacing: 12) {
                    Button(action: onClose) {
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
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.escape, modifiers: [])

                    Spacer()

                    // Cover mode / Vinyl mode switcher
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            useVinyl.toggle()
                        }
                    }) {
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
                    }
                    .buttonStyle(.plain)

                    // Transition Mode Selector (AutoMix, Crossfade, Off)
                    Menu {
                        Button(action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                player.setTransitionMode(.automix)
                            }
                        }) {
                            HStack {
                                Text("Auto Mix")
                                if player.transitionMode == .automix {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }

                        Button(action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                player.setTransitionMode(.crossfade)
                            }
                        }) {
                            HStack {
                                Text("Cross Fade")
                                if player.transitionMode == .crossfade {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }

                        Divider()

                        Button(action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                player.setTransitionMode(.off)
                            }
                        }) {
                            HStack {
                                Text("Off")
                                if player.transitionMode == .off {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: player.transitionMode == .automix ? "wand.and.stars" : (player.transitionMode == .crossfade ? "waveform.badge.magnifyingglass" : "circle.slash"))
                                .font(.system(size: 13, weight: .semibold))
                            Text(player.isTransitioning ? "Mixing..." : player.transitionMode.rawValue)
                                .font(.system(size: 12, weight: .semibold))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.white.opacity(0.55))
                        }
                        .foregroundColor(player.transitionMode != .off ? .white : .white.opacity(0.60))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            player.transitionMode != .off
                                ? (player.isTransitioning ? Color.purple.opacity(0.40) : Color.white.opacity(0.22))
                                : Color.white.opacity(0.10)
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(
                                player.transitionMode != .off
                                    ? (player.isTransitioning ? Color.purple.opacity(0.65) : Color.white.opacity(0.25))
                                    : Color.white.opacity(0.15),
                                lineWidth: 1
                            )
                        )
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()

                    // Queue drawer toggle
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            showQueue.toggle()
                        }
                    }) {
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
                    }
                    .buttonStyle(.plain)

                    // Sleep Timer Menu
                    Menu {
                        ForEach(SleepTimerOption.allCases, id: \.self) { opt in
                            Button(opt.rawValue) {
                                player.setSleepTimer(opt)
                            }
                        }
                    } label: {
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
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()


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
                                    thumbnail: track.thumbnail,
                                    title: track.title,
                                    isPlaying: player.isPlaying,
                                    progress: player.progress,
                                    onSeek: { player.seek(to: $0) }
                                )
                                .frame(width: deckW, height: deckW)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.88).combined(with: .opacity),
                                    removal: .scale(scale: 0.88).combined(with: .opacity)
                                ))
                            } else {
                                if let thumb = track.thumbnail, let url = URL(string: thumb) {
                                    AsyncImage(url: url) { phase in
                                        if let img = phase.image {
                                            img.resizable().aspectRatio(contentMode: .fill)
                                        } else {
                                            Color.gray.opacity(0.3)
                                        }
                                    }
                                    .frame(width: deckW * 0.94, height: deckW * 0.94)
                                    .clipShape(RoundedRectangle(cornerRadius: 24))
                                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.15), lineWidth: 1))
                                    .shadow(color: .black.opacity(0.4), radius: 25, y: 12)
                                    .scaleEffect(player.isPlaying ? 1.0 : 0.94)
                                    .animation(.easeInOut(duration: 0.4), value: player.isPlaying)
                                    .transition(.asymmetric(
                                        insertion: .scale(scale: 0.88).combined(with: .opacity),
                                        removal: .scale(scale: 0.88).combined(with: .opacity)
                                    ))
                                }
                            }
                        }

                        // Track Title, Artist & Like Button
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(track.title)
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Text(track.artist)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                    .lineLimit(1)
                            }

                            Spacer()

                            Button(action: { library.toggleLike(track) }) {
                                Image(systemName: library.isLiked(track) ? "heart.fill" : "heart")
                                    .font(.system(size: 20))
                                    .foregroundColor(library.isLiked(track) ? .white : .white.opacity(0.7))
                                    .frame(width: 36, height: 36)
                            }
                            .buttonStyle(.plain)
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
                                            player.seek(to: finalVal)
                                            isSeeking = false
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

                        // Transport Controls directly below Turntable
                        HStack(spacing: 24) {
                            Button(action: { player.toggleShuffle() }) {
                                Image(systemName: "shuffle")
                                    .font(.system(size: 16, weight: player.isShuffle ? .bold : .regular))
                                    .foregroundColor(player.isShuffle ? .white : .white.opacity(0.6))
                            }
                            .buttonStyle(.plain)

                            Button(action: { player.previous() }) {
                                Image(systemName: "backward.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.white)
                            }
                            .buttonStyle(.plain)

                            Button(action: { player.togglePlayPause() }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.14))
                                        .frame(width: 56, height: 56)

                                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            .buttonStyle(.plain)

                            Button(action: { player.next() }) {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.white)
                            }
                            .buttonStyle(.plain)

                            Button(action: { player.cycleRepeatMode() }) {
                                Image(systemName: player.repeatMode == .one ? "repeat.1" : "repeat")
                                    .font(.system(size: 16, weight: player.repeatMode != .off ? .bold : .regular))
                                    .foregroundColor(player.repeatMode != .off ? .white : .white.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(width: deckW)

                        // Volume Slider
                        HStack(spacing: 10) {
                            Image(systemName: "speaker.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.4))
                            Slider(value: Binding(
                                get: { Double(player.volume) },
                                set: { player.setVolume(Float($0)) }
                            ), in: 0...1)
                            .frame(width: 140)
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
                    .contentShape(Rectangle())
                    .gesture(dismissDragGesture)

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
        .background(
            TrackpadSwipeDismissView(onDismiss: onClose)
        )
        .task(id: track.id) {
            self.lyrics = []
            self.isLoadingLyrics = true
            let fetched = await LyricsService.shared.fetchLyrics(
                videoId: track.id,
                title: track.title,
                artist: track.artist,
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

private struct TrackpadSwipeDismissView: NSViewRepresentable {
    let onDismiss: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.startMonitoring(in: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onDismiss = onDismiss
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.stopMonitoring()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }

    final class Coordinator {
        var onDismiss: () -> Void
        private var monitor: Any?
        private var accumulatedDeltaY: CGFloat = 0

        init(onDismiss: @escaping () -> Void) {
            self.onDismiss = onDismiss
        }

        func startMonitoring(in view: NSView) {
            stopMonitoring()
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .keyDown]) { [weak self, weak view] event in
                guard let self else { return event }
                if event.type == .keyDown && event.keyCode == 53 { // Escape key
                    DispatchQueue.main.async { self.onDismiss() }
                    return nil
                }
                guard event.type == .scrollWheel,
                      let window = view?.window,
                      event.window === window else {
                    return event
                }
                // Only trigger swipe-down dismiss when cursor is on left half (turntable deck) or top header (top 90pt)
                let loc = event.locationInWindow
                let inHeader = loc.y > (window.frame.height - 95)
                let inLeftDeck = loc.x < (window.frame.width * 0.50)
                guard inHeader || inLeftDeck else { return event }

                if event.phase == .began {
                    self.accumulatedDeltaY = 0
                }
                // On macOS natural scrolling, swiping two fingers DOWN produces negative scrollingDeltaY (or positive when non-natural)
                let dy = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.deltaY * 10
                if abs(dy) > abs(event.scrollingDeltaX) {
                    self.accumulatedDeltaY += abs(dy)
                    if self.accumulatedDeltaY > 95 {
                        self.accumulatedDeltaY = 0
                        DispatchQueue.main.async { self.onDismiss() }
                    }
                }
                return event
            }
        }

        func stopMonitoring() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        deinit {
            stopMonitoring()
        }
    }
}

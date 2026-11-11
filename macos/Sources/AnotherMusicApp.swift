import SwiftUI
import AppKit

@main
struct AnotherMusicApp: App {
    @StateObject private var player = AudioPlayerService.shared

    var body: some Scene {
        WindowGroup {
            MainContentView()
                .environmentObject(player)
                .preferredColorScheme(.dark)
                .frame(minWidth: 1040, minHeight: 720)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandMenu("Playback") {
                Button("Play/Pause") { player.togglePlayPause() }.keyboardShortcut("p", modifiers: .command)
                Button("Seek Back 5s") { player.seekBy(seconds: -5) }.keyboardShortcut(.leftArrow, modifiers: .command)
                Button("Seek Forward 5s") { player.seekBy(seconds: 5) }.keyboardShortcut(.rightArrow, modifiers: .command)
                Button("Volume Up") { player.setVolume(player.volume + 0.1) }.keyboardShortcut(.upArrow, modifiers: .command)
                Button("Volume Down") { player.setVolume(player.volume - 0.1) }.keyboardShortcut(.downArrow, modifiers: .command)
                Button("Shuffle") { player.toggleShuffle() }.keyboardShortcut("s", modifiers: [.command, .shift])
                Button("Repeat") { player.cycleRepeatMode() }.keyboardShortcut("r", modifiers: [.command, .shift])
                Button("Search") { NotificationCenter.default.post(name: .gotoSearch, object: nil) }.keyboardShortcut("f", modifiers: .command)
                Divider()
                Menu("Sleep Timer") {
                    ForEach(SleepTimerOption.allCases, id: \.self) { opt in
                        Button(opt.rawValue) { player.setSleepTimer(opt) }
                    }
                }
            }
        }

        Settings {
            SettingsView()
                .preferredColorScheme(.dark)
        }

        MenuBarExtra("anotherMusic", systemImage: player.isPlaying ? "play.circle.fill" : "music.note") {
            MenuBarController(player: player)
        }
        .menuBarExtraStyle(.window)
    }
}

extension Notification.Name { static let gotoSearch = Notification.Name("gotoSearch") }

struct MainContentView: View {
    @EnvironmentObject var player: AudioPlayerService
    @State private var selectedTab: String = "Home"
    @State private var isPlayerExpanded: Bool = false
    @State private var collection: SongItem?

    private func handle(_ song: SongItem, _ queue: [SongItem]) {
        if song.kind == .song {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                player.play(song: song, newQueue: queue)
            }
        } else {
            collection = song
        }
    }

    var body: some View {
        ZStack {
            // Base black surface matching Android MochyTheme
            Color.black
                .ignoresSafeArea()

            // Muted top wash matching Android HomeTopGlow (saturation <= 0.55, dim luminance)
            if let thumb = player.currentTrack?.thumbnail, let url = URL(string: thumb) {
                VStack {
                    AsyncImage(url: url) { phase in
                        if let img = phase.image {
                            img.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Color.clear
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: 260)
                    .saturation(0.50)
                    .blur(radius: 90)
                    .opacity(0.24)
                    .mask(
                        LinearGradient(
                            colors: [.black, .black.opacity(0.55), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    Spacer()
                }
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.6), value: thumb)
            }

            // Main Content Area with Spring Recede Animation
            VStack(spacing: 0) {
                // Screen Switcher
                ZStack {
                    switch selectedTab {
                    case "Home":
                        HomeScreen(onPlay: { song, queue in
                            handle(song, queue)
                        })
                    case "Search":
                        SearchScreen(onPlay: { song, queue in
                            handle(song, queue)
                        })
                    case "Library":
                        LibraryScreen(onPlay: { song, queue in
                            handle(song, queue)
                        })
                    case "Account":
                        AccountScreen(onPlay: { song, queue in
                            handle(song, queue)
                        })
                    default:
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onReceive(NotificationCenter.default.publisher(for: .gotoSearch)) { _ in selectedTab = "Search" }
            }
            .overlay {
                if let c = collection {
                    AlbumDetailView(item: c, onPlay: { s, q in player.play(song: s, newQueue: q) }, onClose: { collection = nil })
                        .transition(.opacity)
                }
            }
            .scaleEffect(isPlayerExpanded ? 0.94 : 1.0)
            .opacity(isPlayerExpanded ? 0.35 : 1.0)
            .clipShape(RoundedRectangle(cornerRadius: isPlayerExpanded ? 24 : 0))
            .animation(.spring(response: 0.45, dampingFraction: 0.86), value: isPlayerExpanded)

            // Floating WideBar at Bottom
            VStack {
                Spacer()
                FloatingWideBar(
                    selectedTab: $selectedTab,
                    currentTrack: player.currentTrack,
                    incomingTrack: player.incomingTrack,
                    transitionProgress: player.uiTransitionProgress,
                    isPlaying: player.isPlaying,
                    progress: player.progress,
                    onTogglePlay: { player.togglePlayPause() },
                    onNext: { player.next() },
                    onPrevious: { player.previous() },
                    onExpandPlayer: {
                        if player.currentTrack != nil {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                                isPlayerExpanded = true
                            }
                        }
                    }
                )
                .offset(y: isPlayerExpanded ? 80 : 0)
                .opacity(isPlayerExpanded ? 0.0 : 1.0)
                .animation(.spring(response: 0.4, dampingFraction: 0.84), value: isPlayerExpanded)
                .padding(.bottom, 24)
            }

            // Expanded Full Player Overlay
            if isPlayerExpanded, let track = player.currentTrack {
                ExpandedPlayerView(
                    track: track,
                    player: player,
                    onClose: {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                            isPlayerExpanded = false
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .scale(scale: 0.90)).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .scale(scale: 0.90)).combined(with: .opacity)
                ))
                .zIndex(10)
            }
        }
    }
}

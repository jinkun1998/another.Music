import SwiftUI
import AppKit

@main
@MainActor struct AnotherMusicApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var player = AudioPlayerService.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                MainContentView()
                    .environmentObject(player)

                if !hasCompletedOnboarding {
                    OnboardingView(onComplete: {
                        withAnimation(.spring(response: 0.55, dampingFraction: 0.86)) {
                            hasCompletedOnboarding = true
                        }
                    })
                    .transition(.opacity.combined(with: .scale(scale: 1.03)))
                    .zIndex(100)
                }
            }
            .preferredColorScheme(.dark)
            .frame(minWidth: 1040, minHeight: 720)
            .background(
                WindowAccessor { window in
                    AppDelegate.shared.configureMainWindow(window)
                }
            )
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Window") {
                    AppDelegate.shared.reopenMainWindow()
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandGroup(after: .windowArrangement) {
                Button("anotherMusic") {
                    AppDelegate.shared.reopenMainWindow()
                }
                .keyboardShortcut("0", modifiers: .command)
            }

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
    }
}

extension Notification.Name { static let gotoSearch = Notification.Name("gotoSearch") }

@MainActor struct MainContentView: View {
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
                        HomeScreen(
                            onPlay: { song, queue in
                                handle(song, queue)
                            },
                            onNavigate: { item in
                                handle(item, [])
                            }
                        )
                    case "Search":
                        SearchScreen(
                            onPlay: { song, queue in
                                handle(song, queue)
                            },
                            onNavigateAlbum: { browseId in
                                Task {
                                    if let album = await InnerTubeService.shared.fetchBrowseAlbumOrPlaylist(browseId: browseId) {
                                        await MainActor.run {
                                            collection = SongItem(
                                                id: album.tracks.first?.id ?? browseId,
                                                title: album.title,
                                                artist: album.artist,
                                                album: album.title,
                                                thumbnail: album.thumbnail,
                                                kind: .album,
                                                browseId: browseId
                                            )
                                        }
                                    }
                                }
                            },
                            onNavigateArtist: { browseId in
                                // Navigate to artist page
                            },
                            onNavigatePlaylist: { browseId in
                                Task {
                                    if let playlist = await InnerTubeService.shared.fetchBrowseAlbumOrPlaylist(browseId: browseId) {
                                        await MainActor.run {
                                            collection = SongItem(
                                                id: playlist.tracks.first?.id ?? browseId,
                                                title: playlist.title,
                                                artist: playlist.artist,
                                                album: playlist.title,
                                                thumbnail: playlist.thumbnail,
                                                kind: .playlist,
                                                browseId: browseId
                                            )
                                        }
                                    }
                                }
                            }
                        )
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

// MARK: - App Delegate & Window Lifecycle Management
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static private(set) var shared: AppDelegate!
    var mainWindow: NSWindow?
    private var isTerminating = false

    override init() {
        super.init()
        AppDelegate.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            reopenMainWindow()
            return false
        }
        return true
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        let hasVisible = NSApp.windows.contains(where: { $0.isVisible && !($0 is NSPanel) })
        if !hasVisible {
            reopenMainWindow()
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        isTerminating = true
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        isTerminating = true
    }

    func configureMainWindow(_ window: NSWindow) {
        self.mainWindow = window
        window.delegate = self
        window.isReleasedWhenClosed = false

        // Intercept close button to hide (orderOut) instead of destroy
        if let closeBtn = window.standardWindowButton(.closeButton) {
            closeBtn.target = self
            closeBtn.action = #selector(handleCloseButton)
        }
    }

    @objc func handleCloseButton() {
        mainWindow?.orderOut(nil)
    }

    func closeMainWindow() {
        mainWindow?.orderOut(nil)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if isTerminating {
            return true
        }
        if sender === mainWindow {
            sender.orderOut(nil)
            return false
        }
        return true
    }

    func reopenMainWindow() {
        if let window = mainWindow {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        for candidate in NSApp.windows where candidate.canBecomeMain && !(candidate is NSPanel) {
            configureMainWindow(candidate)
            if candidate.isMiniaturized {
                candidate.deminiaturize(nil)
            }
            candidate.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Trigger system menu item to create a fresh window if none exists
        if let mainMenu = NSApp.mainMenu {
            for item in mainMenu.items {
                if let submenu = item.submenu {
                    for subitem in submenu.items {
                        if subitem.title == "New Window" || subitem.title == "New" || (subitem.keyEquivalent == "n" && subitem.keyEquivalentModifierMask == .command) {
                            if let action = subitem.action {
                                NSApp.sendAction(action, to: subitem.target, from: subitem)
                                NSApp.activate(ignoringOtherApps: true)
                                return
                            }
                        }
                    }
                }
            }
        }

        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Window Accessor
private struct WindowAccessor: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> WindowAccessorView {
        let view = WindowAccessorView()
        view.onWindow = onWindow
        return view
    }

    func updateNSView(_ nsView: WindowAccessorView, context: Context) {
        nsView.onWindow = onWindow
        if let window = nsView.window {
            onWindow(window)
        }
    }
}

private final class WindowAccessorView: NSView {
    var onWindow: ((NSWindow) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window = self.window {
            onWindow?(window)
        }
    }
}

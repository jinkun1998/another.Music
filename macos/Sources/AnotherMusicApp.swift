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
    }
}

struct MainContentView: View {
    @EnvironmentObject var player: AudioPlayerService
    @State private var selectedTab: String = "Home"
    @State private var isPlayerExpanded: Bool = false

    private let brandRed = Color(red: 1.0, green: 0.18, blue: 0.34)

    var body: some View {
        ZStack {
            // Main app dark background
            Color(red: 0.04, green: 0.035, blue: 0.05)
                .ignoresSafeArea()

            // Dynamic Ambient Glow from Track Artwork
            if let thumb = player.currentTrack?.thumbnail, let url = URL(string: thumb) {
                AsyncImage(url: url) { phase in
                    if let img = phase.image {
                        img.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Color.clear
                    }
                }
                .frame(height: 480)
                .blur(radius: 90)
                .opacity(0.35)
                .mask(
                    LinearGradient(
                        colors: [.black, .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .ignoresSafeArea()
            }

            // Main Content Area with Spring Recede Animation
            VStack(spacing: 0) {
                // Top Brand Bar
                HStack {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(brandRed)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Image(systemName: "play.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                            )
                        Text("another.Music")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 8)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedTab = "Home" }

                    Spacer()
                }
                .padding(.leading, 84)
                .padding(.trailing, 36)
                .padding(.top, 16)
                .padding(.bottom, 8)

                // Screen Switcher
                ZStack {
                    switch selectedTab {
                    case "Home":
                        HomeScreen(onPlay: { song, queue in
                            player.play(song: song, newQueue: queue)
                        })
                    case "Search":
                        SearchScreen(onPlay: { song, queue in
                            player.play(song: song, newQueue: queue)
                        })
                    case "Library":
                        LibraryScreen(onPlay: { song, queue in
                            player.play(song: song, newQueue: queue)
                        })
                    case "Account":
                        AccountScreen()
                    default:
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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

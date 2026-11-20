import SwiftUI

@MainActor public struct FloatingWideBar: View {
    @Binding var selectedTab: String
    let currentTrack: SongItem?
    var incomingTrack: SongItem? = nil
    var transitionProgress: Double = 0.0
    let isPlaying: Bool
    let progress: Double
    let onTogglePlay: () -> Void
    let onNext: () -> Void
    let onPrevious: () -> Void
    let onExpandPlayer: () -> Void
    var onSeek: ((Double) -> Void)? = nil

    private let tabs = [
        ("Home", "house.fill"),
        ("Search", "magnifyingglass"),
        ("Library", "books.vertical.fill"),
        ("Account", "person.crop.circle")
    ]

    @State private var isBarHovered: Bool = false
    @State private var isSwipingProgress: Bool = false
    @State private var swipedProgress: Double = 0.0
    @StateObject private var swipeHandler = TwoFingerSwipeHandler()

    public var body: some View {
        HStack(spacing: 0) {
            // Left: Integrated Mini Player (animated expand/collapse)
            if let track = currentTrack {
                HStack(spacing: 12) {
                    HStack(spacing: 10) {
                        ZStack {
                            if let thumb = track.thumbnail {
                                CachedAsyncImage(urlString: thumb) { img in
                                    img.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Color.gray.opacity(0.3)
                                }
                                .opacity(transitionProgress > 0 ? (1.0 - transitionProgress) : 1.0)
                            }

                            if transitionProgress > 0, let incThumb = incomingTrack?.thumbnail {
                                CachedAsyncImage(urlString: incThumb) { img in
                                    img.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Color.clear
                                }
                                .opacity(transitionProgress)
                            }
                        }
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))

                        ZStack(alignment: .leading) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Text(track.artist)
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.65))
                                    .lineLimit(1)
                            }
                            .opacity(transitionProgress > 0 ? (1.0 - transitionProgress) : 1.0)

                            if let incoming = incomingTrack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(incoming.title)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    Text(incoming.artist)
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.65))
                                        .lineLimit(1)
                                }
                                .opacity(transitionProgress)
                            }
                        }
                        .frame(minWidth: 110, maxWidth: 180, alignment: .leading)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onExpandPlayer)

                    // Transport controls
                    HStack(spacing: 4) {
                        AppleMusicSkipButton(
                            direction: .previous,
                            iconSize: 13,
                            plateSize: 32,
                            onAction: onPrevious
                        )

                        AppleMusicPlayPauseButton(
                            isPlaying: isPlaying,
                            size: 36,
                            iconSize: 14,
                            onToggle: onTogglePlay
                        )

                        AppleMusicSkipButton(
                            direction: .next,
                            iconSize: 13,
                            plateSize: 32,
                            onAction: onNext
                        )
                    }

                    // 1px divider
                    Rectangle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 1, height: 26)
                        .padding(.horizontal, 6)
                }
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity).combined(with: .scale(scale: 0.9, anchor: .leading)),
                        removal: .move(edge: .leading).combined(with: .opacity).combined(with: .scale(scale: 0.9, anchor: .leading))
                    )
                )
            }

            // Right: 4 Navigation Tabs
            HStack(spacing: 4) {
                ForEach(tabs, id: \.0) { tab in
                    let isSelected = selectedTab == tab.0
                    ZStack {
                        if isSelected {
                            Capsule()
                                .fill(Color.white.opacity(0.20))
                                .matchedGeometryEffect(id: "nav_pill", in: navNamespace)
                        }

                        Image(systemName: tab.1)
                            .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                            .foregroundColor(isSelected ? .white : .white.opacity(0.55))
                            .frame(width: 52, height: 42)
                    }
                    .frame(width: 52, height: 42)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        AppHaptics.tick()
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            selectedTab = tab.0
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .fixedSize()
        .contentShape(Capsule())
        .liquidGlass(cornerRadius: 32)
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: currentTrack != nil)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: currentTrack?.id)
        .overlay(alignment: .bottom) {
            if currentTrack != nil {
                GeometryReader { geo in
                    let baseRatio = transitionProgress > 0 ? ((1.0 - transitionProgress) * progress) : progress
                    let fillRatio = isSwipingProgress ? swipedProgress : baseRatio
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isBarHovered ? 0.95 : 0.75),
                                    Color.white.opacity(isBarHovered ? 0.65 : 0.45)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(geo.size.width * CGFloat(fillRatio), 0), height: isBarHovered ? 3.5 : 2)
                        .shadow(color: Color.white.opacity(isBarHovered ? 0.4 : 0.0), radius: 3)
                }
                .frame(height: isBarHovered ? 3.5 : 2)
                .clipShape(Capsule())
                .padding(.horizontal, 18)
                .padding(.bottom, 2)
                .transition(.opacity)
                .animation(.spring(response: 0.24, dampingFraction: 0.8), value: isBarHovered)
            }
        }
        .onHover { hovering in
            isBarHovered = hovering
            if hovering {
                setupSwipeHandlers()
                swipeHandler.start()
            } else {
                swipeHandler.stop()
            }
        }
        .onAppear {
            setupSwipeHandlers()
        }
        .onChange(of: progress) { _, newP in
            if !isSwipingProgress {
                swipedProgress = newP
            }
            setupSwipeHandlers()
        }
        .onDisappear {
            swipeHandler.forceStop()
        }
    }

    private func setupSwipeHandlers() {
        swipeHandler.onSwipeTick = { delta, phase, isPrecise in
            let currentP = isSwipingProgress ? swipedProgress : progress
            let deltaP = Double(delta) * 0.0015
            let next = min(max(currentP + deltaP, 0.0), 1.0)
            let oldNotch = Int(currentP * 40.0)
            let newNotch = Int(next * 40.0)
            if oldNotch != newNotch {
                if next <= 0.001 || next >= 0.999 {
                    AppHaptics.alignment()
                } else {
                    AppHaptics.tick()
                }
            }
            swipedProgress = next
            isSwipingProgress = true
            onSeek?(swipedProgress)
        }
        swipeHandler.onSwipeEnd = {
            isSwipingProgress = false
            AppHaptics.alignment()
            onSeek?(swipedProgress)
            if !isBarHovered {
                swipeHandler.forceStop()
            }
        }
    }

    @Namespace private var navNamespace
}

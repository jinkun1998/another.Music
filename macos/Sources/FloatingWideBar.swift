import SwiftUI

public struct FloatingWideBar: View {
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

    private let tabs = [
        ("Home", "house.fill"),
        ("Search", "magnifyingglass"),
        ("Library", "books.vertical.fill"),
        ("Account", "person.crop.circle")
    ]

    public var body: some View {
        HStack(spacing: 0) {
            // Left: Integrated Mini Player (animated expand/collapse)
            if let track = currentTrack {
                HStack(spacing: 12) {
                    HStack(spacing: 10) {
                        ZStack {
                            if let thumb = track.thumbnail, let url = URL(string: thumb) {
                                AsyncImage(url: url) { phase in
                                    if let img = phase.image {
                                        img.resizable().aspectRatio(contentMode: .fill)
                                    } else {
                                        Color.gray.opacity(0.3)
                                    }
                                }
                                .opacity(transitionProgress > 0 ? (1.0 - transitionProgress) : 1.0)
                            }

                            if transitionProgress > 0, let incThumb = incomingTrack?.thumbnail, let incUrl = URL(string: incThumb) {
                                AsyncImage(url: incUrl) { phase in
                                    if let img = phase.image {
                                        img.resizable().aspectRatio(contentMode: .fill)
                                    } else {
                                        Color.gray.opacity(0.3)
                                    }
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

                            if transitionProgress > 0, let incoming = incomingTrack {
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
                        Button(action: onPrevious) {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.85))
                                .frame(width: 32, height: 32)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Button(action: onTogglePlay) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.14))
                                    .frame(width: 36, height: 36)
                                    .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))

                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .contentShape(Circle())
                        }
                        .buttonStyle(.plain)

                        Button(action: onNext) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.85))
                                .frame(width: 32, height: 32)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
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
                    Button(action: {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            selectedTab = tab.0
                        }
                    }) {
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
                    }
                    .buttonStyle(.plain)
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
                    let fillRatio = transitionProgress > 0 ? ((1.0 - transitionProgress) * progress) : progress
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.75),
                                    Color.white.opacity(0.45)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(geo.size.width * CGFloat(fillRatio), 0), height: 2)
                }
                .frame(height: 2)
                .clipShape(Capsule())
                .padding(.horizontal, 18)
                .padding(.bottom, 2)
                .transition(.opacity)
            }
        }
    }

    @Namespace private var navNamespace
}

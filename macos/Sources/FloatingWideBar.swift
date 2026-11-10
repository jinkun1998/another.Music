import SwiftUI

public struct FloatingWideBar: View {
    @Binding var selectedTab: String
    let currentTrack: SongItem?
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
            // Left: Integrated Mini Player (only present when a track exists)
            if let track = currentTrack {
                HStack(spacing: 12) {
                    HStack(spacing: 10) {
                        if let thumb = track.thumbnail, let url = URL(string: thumb) {
                            AsyncImage(url: url) { phase in
                                if let img = phase.image {
                                    img.resizable().aspectRatio(contentMode: .fill)
                                } else {
                                    Color.gray.opacity(0.3)
                                }
                            }
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                        }

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
                        }
                        .buttonStyle(.plain)

                        Button(action: onTogglePlay) {
                            ZStack {
                                Circle()
                                    .fill(Color(red: 1.0, green: 0.18, blue: 0.34))
                                    .frame(width: 36, height: 36)
                                    .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 1))

                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(.plain)

                        Button(action: onNext) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.85))
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.plain)
                    }

                    // 1px divider
                    Rectangle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 1, height: 26)
                        .padding(.horizontal, 6)
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.85)),
                    removal: .opacity.combined(with: .scale(scale: 0.85))
                ))
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
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .fixedSize()
        .liquidGlass(cornerRadius: 32)
        .overlay(alignment: .bottom) {
            if currentTrack != nil {
                GeometryReader { geo in
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.18, blue: 0.34),
                                    Color(red: 1.0, green: 0.45, blue: 0.60)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(geo.size.width * CGFloat(progress), 0), height: 2)
                }
                .frame(height: 2)
                .clipShape(Capsule())
                .padding(.horizontal, 18)
                .padding(.bottom, 2)
            }
        }
    }

    @Namespace private var navNamespace
}

import SwiftUI

public struct HomeScreen: View {
    let onPlay: (SongItem, [SongItem]) -> Void

    @State private var sections: [HomeSection] = []
    @State private var isLoading: Bool = true

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 32) {
                // Hero Banner
                if let heroSection = sections.first, let heroSong = heroSection.items.first {
                    HeroBanner(song: heroSong, onPlay: { onPlay(heroSong, heroSection.items) })
                        .padding(.horizontal, 36)
                        .padding(.top, 16)
                }

                // Each Section
                ForEach(sections) { sec in
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(sec.title)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                            if let label = sec.label {
                                Text(label.uppercased())
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        .padding(.horizontal, 36)

                        // 4-row Quick Picks or Horizontal Scroll Shelf
                        if sec.items.count >= 4 {
                            QuickPicksGrid(items: sec.items, onPlay: { onPlay($0, sec.items) })
                                .padding(.horizontal, 36)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(sec.items) { item in
                                        SongCard(item: item, onPlay: { onPlay(item, sec.items) })
                                    }
                                }
                                .padding(.horizontal, 36)
                            }
                        }
                    }
                }

                Color.clear.frame(height: 100)
            }
        }
        .task {
            let res = await InnerTubeService.shared.fetchHome()
            self.sections = res
            self.isLoading = false
        }
    }
}

private struct HeroBanner: View {
    let song: SongItem
    let onPlay: () -> Void

    var body: some View {
        ZStack {
            // Ambient Artwork background
            if let thumb = song.thumbnail, let url = URL(string: thumb) {
                AsyncImage(url: url) { phase in
                    if let img = phase.image {
                        img.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Color(red: 0.1, green: 0.1, blue: 0.12)
                    }
                }
                .blur(radius: 60)
                .opacity(0.4)
            }

            // Dark gradient wash
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.07).opacity(0.95),
                    Color(red: 0.05, green: 0.05, blue: 0.07).opacity(0.50)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            HStack(spacing: 36) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("RECOMMENDED")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(red: 1.0, green: 0.28, blue: 0.45))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color(red: 1.0, green: 0.18, blue: 0.34).opacity(0.2))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color(red: 1.0, green: 0.18, blue: 0.34).opacity(0.4), lineWidth: 1))

                    Text(song.title)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)

                    Text(song.artist)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)

                    Button(action: onPlay) {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 14, weight: .bold))
                            Text("Play Now")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(Color(red: 1.0, green: 0.18, blue: 0.34))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .shadow(color: Color(red: 1.0, green: 0.18, blue: 0.34).opacity(0.4), radius: 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let thumb = song.thumbnail, let url = URL(string: thumb) {
                    AsyncImage(url: url) { phase in
                        if let img = phase.image {
                            img.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Color.gray.opacity(0.3)
                        }
                    }
                    .frame(width: 200, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.15), lineWidth: 1))
                    .shadow(color: .black.opacity(0.3), radius: 16)
                }
            }
            .padding(32)
        }
        .frame(height: 280)
        .background(Color(white: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}

private struct QuickPicksGrid: View {
    let items: [SongItem]
    let onPlay: (SongItem) -> Void

    var body: some View {
        let chunked = stride(from: 0, to: min(items.count, 16), by: 4).map {
            Array(items[$0..<min($0 + 4, items.count)])
        }

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(Array(chunked.enumerated()), id: \.offset) { _, column in
                    VStack(spacing: 10) {
                        ForEach(column) { song in
                            TrackRow(song: song, onPlay: { onPlay(song) })
                                .frame(width: 320)
                        }
                    }
                }
            }
        }
    }
}

public struct TrackRow: View {
    let song: SongItem
    let onPlay: () -> Void

    public var body: some View {
        HStack(spacing: 12) {
            if let thumb = song.thumbnail, let url = URL(string: thumb) {
                AsyncImage(url: url) { phase in
                    if let img = phase.image {
                        img.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Color.gray.opacity(0.3)
                    }
                }
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(song.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(song.artist)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.65))
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(8)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(Rectangle())
        .onTapGesture(perform: onPlay)
    }
}

private struct SongCard: View {
    let item: SongItem
    let onPlay: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let thumb = item.thumbnail, let url = URL(string: thumb) {
                AsyncImage(url: url) { phase in
                    if let img = phase.image {
                        img.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Color.gray.opacity(0.3)
                    }
                }
                .frame(width: 150, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.3), radius: 8)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(item.artist)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }
            .frame(width: 150, alignment: .leading)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onPlay)
    }
}

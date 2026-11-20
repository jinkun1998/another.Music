import SwiftUI

public struct HomeScreen: View {
    let onPlay: (SongItem, [SongItem]) -> Void
    var onNavigate: ((SongItem) -> Void)? = nil

    @ObservedObject private var library = LibraryStore.shared
    @ObservedObject private var player = AudioPlayerService.shared
    @State private var sections: [HomeSection] = []
    @State private var isLoading: Bool = true

    public init(
        onPlay: @escaping (SongItem, [SongItem]) -> Void,
        onNavigate: ((SongItem) -> Void)? = nil
    ) {
        self.onPlay = onPlay
        self.onNavigate = onNavigate
    }

    public var body: some View {
        ZStack {
            if isLoading && sections.isEmpty {
                ProgressView()
                    .scaleEffect(1.2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 28) {
                        TimelineView(.everyMinute) { context in
                            let hour = Calendar.current.component(.hour, from: context.date)
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(timeGreeting(hour: hour, name: library.username))
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .tracking(-0.8)
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.white, Color.white.opacity(0.72)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                            .padding(.horizontal, 36)
                        }

                        // Top Hero Carousel with Gacha Card
                        let avoidSongIds = library.avoidSongIds()
                        let avoidArtists = library.avoidArtists()
                        let heroCards = buildHeroCards(
                            history: library.history,
                            liked: library.likedSongs,
                            sections: sections,
                            currentTrack: player.currentTrack,
                            isPlaying: player.isPlaying,
                            avoidSongIds: avoidSongIds,
                            avoidArtists: avoidArtists
                        )
                        let gachaCandidates = buildGachaCandidates(
                            history: library.history,
                            liked: library.likedSongs,
                            sections: sections,
                            avoidSongIds: avoidSongIds,
                            avoidArtists: avoidArtists
                        )

                        if !heroCards.isEmpty {
                            HeroCarouselView(
                                cards: heroCards,
                                gachaCandidates: gachaCandidates,
                                currentPlayingTrackId: player.currentTrack?.id,
                                isAudioPlaying: player.isPlaying,
                                onPlaySong: { song, queue in
                                    onPlay(song, queue)
                                },
                                onTogglePauseResume: {
                                    if player.isPlaying {
                                        player.pause()
                                    } else {
                                        player.resume()
                                    }
                                },
                                onNavigateCollection: { song in
                                    onNavigate?(song)
                                }
                            )
                        }

                        ForEach(sections) { sec in
                            VStack(alignment: .leading, spacing: 14) {
                                VStack(alignment: .leading, spacing: 2) {
                                    if let label = sec.label, !label.isEmpty {
                                        Text(label.uppercased())
                                            .font(.system(size: 11, weight: .semibold))
                                            .tracking(0.8)
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                    Text(sec.title)
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 36)

                                if sec.isTrackGrid {
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

                        Color.clear.frame(height: 120)
                    }
                    .padding(.top, 38)
                }
            }
        }
        .task {
            let res = await InnerTubeService.shared.fetchHome(
                history: LibraryStore.shared.history,
                liked: LibraryStore.shared.likedSongs,
                avoidSongIds: LibraryStore.shared.avoidSongIds(),
                avoidArtists: LibraryStore.shared.avoidArtists()
            )
            self.sections = res
            self.isLoading = false
        }
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
        .contextMenu {
            Button(LibraryStore.shared.isLiked(song) ? "Unlike" : "Like") {
                LibraryStore.shared.toggleLike(song)
            }
            Divider()
            Button("Don't recommend this song") {
                LibraryStore.shared.blockSong(id: song.id)
            }
            if !song.artist.isEmpty && song.artist != "YouTube Music" {
                Button("Don't recommend \(song.artist)") {
                    LibraryStore.shared.blockArtist(song.artist)
                }
            }
        }
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
        .contextMenu {
            if item.kind == .song {
                Button(LibraryStore.shared.isLiked(item) ? "Unlike" : "Like") {
                    LibraryStore.shared.toggleLike(item)
                }
                Divider()
                Button("Don't recommend this song") {
                    LibraryStore.shared.blockSong(id: item.id)
                }
                if !item.artist.isEmpty && item.artist != "YouTube Music" {
                    Button("Don't recommend \(item.artist)") {
                        LibraryStore.shared.blockArtist(item.artist)
                    }
                }
            }
        }
    }
}

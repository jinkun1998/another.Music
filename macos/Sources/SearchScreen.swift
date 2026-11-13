import SwiftUI

public struct SearchScreen: View {
    let onPlay: (SongItem, [SongItem]) -> Void
    let onNavigateAlbum: ((String) -> Void)?
    let onNavigateArtist: ((String) -> Void)?
    let onNavigatePlaylist: ((String) -> Void)?

    @State private var query: String = ""
    @State private var results: [SongItem] = []
    @State private var suggestions: [String] = []
    @State private var recentSearches: [String] = []
    @State private var isSearching: Bool = false
    @State private var suggestionTask: Task<Void, Never>?

    public init(
        onPlay: @escaping (SongItem, [SongItem]) -> Void,
        onNavigateAlbum: ((String) -> Void)? = nil,
        onNavigateArtist: ((String) -> Void)? = nil,
        onNavigatePlaylist: ((String) -> Void)? = nil
    ) {
        self.onPlay = onPlay
        self.onNavigateAlbum = onNavigateAlbum
        self.onNavigateArtist = onNavigateArtist
        self.onNavigatePlaylist = onNavigatePlaylist
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.6))
                    .font(.system(size: 16))

                TextField("Search...", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .onChange(of: query) { _, newQuery in
                        handleQueryChange(newQuery)
                    }
                    .onSubmit {
                        performSearch()
                    }

                if !query.isEmpty {
                    Button(action: {
                        query = ""
                        results = []
                        suggestions = []
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .liquidGlass(cornerRadius: 24)
            .padding(.horizontal, 36)
            .padding(.top, 38)

            if isSearching {
                Spacer()
                ProgressView()
                    .scaleEffect(1.2)
                Spacer()
            } else if !suggestions.isEmpty && results.isEmpty {
                // Suggestions Section (Recent + Query suggestions)
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 14) {
                        if !recentSearches.isEmpty {
                            SearchSectionHeader(title: "Recent Searches")
                            LazyVStack(spacing: 6) {
                                ForEach(recentSearches, id: \.self) { recent in
                                    SearchSuggestionRow(
                                        text: recent,
                                        isRecent: true,
                                        onTap: { query = recent; performSearch() },
                                        onFill: { query = recent }
                                    )
                                }
                            }
                        }
                        if !suggestions.isEmpty {
                            SearchSectionHeader(title: "Suggestions")
                            LazyVStack(spacing: 6) {
                                ForEach(suggestions, id: \.self) { sug in
                                    SearchSuggestionRow(
                                        text: sug,
                                        isRecent: false,
                                        onTap: { query = sug; performSearch() },
                                        onFill: { query = sug }
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 36)
                    .padding(.top, 16)
                }
            } else if results.isEmpty && !query.isEmpty {
                Spacer()
                Text("No results")
                    .foregroundColor(.white.opacity(0.5))
                    .font(.system(size: 15))
                Spacer()
            } else {
                // Search Results with Top Result + Sections
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 24) {
                        // Top Result Section
                        if let topResult = results.first {
                            SearchSectionHeader(title: "Top Result")
                            SearchResultRow(
                                item: topResult,
                                isTopResult: true,
                                onPlay: onPlay,
                                onNavigateAlbum: onNavigateAlbum,
                                onNavigateArtist: onNavigateArtist,
                                onNavigatePlaylist: onNavigatePlaylist
                            )
                        }

                        // Remaining Results Section
                        let remainingResults = results.dropFirst()
                        if !remainingResults.isEmpty {
                            SearchSectionHeader(title: "Songs")
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 14)], spacing: 14) {
                                ForEach(Array(remainingResults.enumerated()), id: \.element.id) { _, item in
                                    if item.kind == .song {
                                        TrackRow(song: item, onPlay: { onPlay(item, Array(remainingResults)) })
                                    }
                                }
                            }

                            // Albums Section
                            let albums = remainingResults.filter { $0.kind == .album }
                            if !albums.isEmpty {
                                SearchSectionHeader(title: "Albums")
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 14)], spacing: 14) {
                                    ForEach(albums) { item in
                                        SearchResultRow(
                                            item: item,
                                            isTopResult: false,
                                            onPlay: onPlay,
                                            onNavigateAlbum: onNavigateAlbum,
                                            onNavigateArtist: onNavigateArtist,
                                            onNavigatePlaylist: onNavigatePlaylist
                                        )
                                    }
                                }
                            }

                            // Playlists Section
                            let playlists = remainingResults.filter { $0.kind == .playlist }
                            if !playlists.isEmpty {
                                SearchSectionHeader(title: "Playlists")
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 14)], spacing: 14) {
                                    ForEach(playlists) { item in
                                        SearchResultRow(
                                            item: item,
                                            isTopResult: false,
                                            onPlay: onPlay,
                                            onNavigateAlbum: onNavigateAlbum,
                                            onNavigateArtist: onNavigateArtist,
                                            onNavigatePlaylist: onNavigatePlaylist
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 36)
                    .padding(.top, 16)
                    .padding(.bottom, 120)
                }
            }
        }
    }

    private func handleQueryChange(_ newQuery: String) {
        let trimmed = newQuery.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            suggestions = []
            results = []
            return
        }

        suggestionTask?.cancel()
        suggestionTask = Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }
            let sugs = await InnerTubeService.shared.getSearchSuggestions(query: trimmed)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if results.isEmpty {
                    self.suggestions = sugs
                }
            }
        }
    }

    private func performSearch() {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearching = true
        suggestions = []
        Task {
            let res = await InnerTubeService.shared.search(query: query)
            self.results = res
            self.isSearching = false
            // Save to recent searches
            if !res.isEmpty {
                var recent = recentSearches.filter { $0 != query }
                recent.insert(query, at: 0)
                recentSearches = Array(recent.prefix(10))
            }
        }
    }
}

// MARK: - Subviews

private struct SearchSectionHeader: View {
    let title: String
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            Spacer()
        }
    }
}

private struct SearchSuggestionRow: View {
    let text: String
    let isRecent: Bool
    let onTap: () -> Void
    let onFill: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: isRecent ? "clock" : "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.4))
                Text(text)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
                Button(action: onFill) {
                    Image(systemName: "arrow.up.left")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

private struct SearchResultRow: View {
    let item: SongItem
    let isTopResult: Bool
    let onPlay: (SongItem, [SongItem]) -> Void
    let onNavigateAlbum: ((String) -> Void)?
    let onNavigateArtist: ((String) -> Void)?
    let onNavigatePlaylist: ((String) -> Void)?

    var body: some View {
        let subtitle: String = {
            switch item.kind {
            case .song: return item.artist
            case .album: return "Album" + (item.artist.isEmpty ? "" : " • \(item.artist)")
            case .playlist: return "Playlist"
            }
        }()

        let iconName: String = {
            switch item.kind {
            case .song: return "music.note"
            case .album: return "square.stack.fill"
            case .playlist: return "music.note.list"
            }
        }()

        Button(action: {
            switch item.kind {
            case .song:
                onPlay(item, [item])
            case .album:
                onNavigateAlbum?(item.browseId ?? item.id)
            case .playlist:
                onNavigatePlaylist?(item.browseId ?? item.id)
            }
        }) {
            HStack(spacing: 14) {
                if let thumb = item.thumbnail, let url = URL(string: thumb) {
                    AsyncImage(url: url) { phase in
                        if let img = phase.image {
                            img.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Color.gray.opacity(0.3)
                        }
                    }
                    .frame(width: isTopResult ? 64 : 56, height: isTopResult ? 64 : 56)
                    .clipShape(RoundedRectangle(cornerRadius: isTopResult ? 8 : (item.kind == .song ? 0 : 10)))
                } else {
                    RoundedRectangle(cornerRadius: isTopResult ? 8 : 10)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: isTopResult ? 64 : 56, height: isTopResult ? 64 : 56)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: isTopResult ? 17 : 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: isTopResult ? 14 : 13))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if isTopResult {
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, isTopResult ? 10 : 8)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

import SwiftUI

public struct SearchScreen: View {
    let onPlay: (SongItem, [SongItem]) -> Void
    let onNavigateAlbum: ((String) -> Void)?
    let onNavigateArtist: ((String) -> Void)?
    let onNavigatePlaylist: ((String) -> Void)?

    @AppStorage("pauseSearchHistory") private var pauseSearchHistory: Bool = false
    @State private var selectedFilter: SearchFilterType = .all
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
        GeometryReader { geo in
            let isWide = geo.size.width >= 700
            let gridColumns = isWide
                ? [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
                : [GridItem(.flexible(), spacing: 14)]

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

                // Filter Chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(SearchFilterType.allCases) { filter in
                            let isSelected = selectedFilter == filter
                            Button(action: {
                                selectedFilter = filter
                                if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                                    performSearch()
                                }
                            }) {
                                Text(filter.rawValue)
                                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                                    .foregroundColor(isSelected ? .white : .white.opacity(0.65))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(isSelected ? Color.white.opacity(0.20) : Color.white.opacity(0.06))
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Color.white.opacity(isSelected ? 0.28 : 0.08), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 36)
                }
                .padding(.top, 12)

                // Main Content
                if isSearching {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                    Spacer()
                } else if results.isEmpty && query.trimmingCharacters(in: .whitespaces).isEmpty {
                    if !recentSearches.isEmpty {
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 14) {
                                SearchSectionHeader(
                                    title: "Recent Searches",
                                    trailingButtonTitle: "Clear",
                                    onTrailingClick: {
                                        recentSearches.removeAll()
                                        UserDefaults.standard.removeObject(forKey: "recent_searches")
                                    }
                                )
                                LazyVStack(spacing: 6) {
                                    ForEach(recentSearches, id: \.self) { recent in
                                        SearchSuggestionRow(
                                            text: recent,
                                            isRecent: true,
                                            onTap: {
                                                query = recent
                                                performSearch()
                                            },
                                            onFill: { query = recent },
                                            onDelete: {
                                                recentSearches.removeAll { $0 == recent }
                                                UserDefaults.standard.set(recentSearches, forKey: "recent_searches")
                                            }
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal, 36)
                            .padding(.top, 16)
                            .padding(.bottom, 120)
                        }
                    } else {
                        Spacer()
                        VStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 38))
                                .foregroundColor(.white.opacity(0.25))
                            Text("Search songs, artists, albums, or playlists")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.45))
                        }
                        Spacer()
                    }
                } else if results.isEmpty && !suggestions.isEmpty {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 14) {
                            if !recentSearches.isEmpty {
                                SearchSectionHeader(
                                    title: "Recent Searches",
                                    trailingButtonTitle: "Clear",
                                    onTrailingClick: {
                                        recentSearches.removeAll()
                                        UserDefaults.standard.removeObject(forKey: "recent_searches")
                                    }
                                )
                                LazyVStack(spacing: 6) {
                                    ForEach(recentSearches.prefix(5), id: \.self) { recent in
                                        SearchSuggestionRow(
                                            text: recent,
                                            isRecent: true,
                                            onTap: {
                                                query = recent
                                                performSearch()
                                            },
                                            onFill: { query = recent },
                                            onDelete: {
                                                recentSearches.removeAll { $0 == recent }
                                                UserDefaults.standard.set(recentSearches, forKey: "recent_searches")
                                            }
                                        )
                                    }
                                }
                            }
                            SearchSectionHeader(title: "Suggestions")
                            LazyVStack(spacing: 6) {
                                ForEach(suggestions, id: \.self) { sug in
                                    SearchSuggestionRow(
                                        text: sug,
                                        isRecent: false,
                                        onTap: {
                                            query = sug
                                            performSearch()
                                        },
                                        onFill: { query = sug }
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 36)
                        .padding(.top, 16)
                        .padding(.bottom, 120)
                    }
                } else if results.isEmpty && !query.isEmpty {
                    Spacer()
                    Text("No results")
                        .foregroundColor(.white.opacity(0.5))
                        .font(.system(size: 15))
                    Spacer()
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 24) {
                            if selectedFilter == .all {
                                renderAllResultsSections(gridColumns: gridColumns)
                            } else {
                                renderFilteredResults(gridColumns: gridColumns)
                            }
                        }
                        .padding(.horizontal, 36)
                        .padding(.top, 16)
                        .padding(.bottom, 120)
                    }
                }
            }
            .onAppear {
                recentSearches = UserDefaults.standard.stringArray(forKey: "recent_searches") ?? []
            }
        }
    }

    @ViewBuilder
    private func renderAllResultsSections(gridColumns: [GridItem]) -> some View {
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

        let remainingResults = Array(results.dropFirst())
        let songs = remainingResults.filter { $0.kind == .song }
        if !songs.isEmpty {
            SearchSectionHeader(title: "Songs")
            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(songs) { song in
                    SearchResultRow(
                        item: song,
                        isTopResult: false,
                        onPlay: { item, _ in onPlay(item, songs) },
                        onNavigateAlbum: onNavigateAlbum,
                        onNavigateArtist: onNavigateArtist,
                        onNavigatePlaylist: onNavigatePlaylist
                    )
                }
            }
        }

        let albums = remainingResults.filter { $0.kind == .album }
        if !albums.isEmpty {
            SearchSectionHeader(title: "Albums")
            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(albums) { album in
                    SearchResultRow(
                        item: album,
                        isTopResult: false,
                        onPlay: onPlay,
                        onNavigateAlbum: onNavigateAlbum,
                        onNavigateArtist: onNavigateArtist,
                        onNavigatePlaylist: onNavigatePlaylist
                    )
                }
            }
        }

        let artists = remainingResults.filter { $0.kind == .artist }
        if !artists.isEmpty {
            SearchSectionHeader(title: "Artists")
            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(artists) { artist in
                    SearchResultRow(
                        item: artist,
                        isTopResult: false,
                        onPlay: onPlay,
                        onNavigateAlbum: onNavigateAlbum,
                        onNavigateArtist: onNavigateArtist,
                        onNavigatePlaylist: onNavigatePlaylist
                    )
                }
            }
        }

        let playlists = remainingResults.filter { $0.kind == .playlist }
        if !playlists.isEmpty {
            SearchSectionHeader(title: "Playlists")
            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(playlists) { playlist in
                    SearchResultRow(
                        item: playlist,
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

    @ViewBuilder
    private func renderFilteredResults(gridColumns: [GridItem]) -> some View {
        SearchSectionHeader(title: selectedFilter.rawValue)
        LazyVGrid(columns: gridColumns, spacing: 12) {
            ForEach(results) { item in
                SearchResultRow(
                    item: item,
                    isTopResult: false,
                    onPlay: { s, _ in
                        let songs = results.filter { $0.kind == .song }
                        onPlay(s, songs.isEmpty ? [s] : songs)
                    },
                    onNavigateAlbum: onNavigateAlbum,
                    onNavigateArtist: onNavigateArtist,
                    onNavigatePlaylist: onNavigatePlaylist
                )
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
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isSearching = true
        suggestions = []
        Task {
            let res = await InnerTubeService.shared.search(query: trimmed, params: selectedFilter.params)
            await MainActor.run {
                self.results = res
                self.isSearching = false
                if !pauseSearchHistory && !res.isEmpty {
                    var list = recentSearches.filter { $0.caseInsensitiveCompare(trimmed) != .orderedSame }
                    list.insert(trimmed, at: 0)
                    list = Array(list.prefix(20))
                    recentSearches = list
                    UserDefaults.standard.set(list, forKey: "recent_searches")
                }
            }
        }
    }
}

// MARK: - Subviews

private struct SearchSectionHeader: View {
    let title: String
    var trailingButtonTitle: String? = nil
    var onTrailingClick: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            Spacer()
            if let trailingButtonTitle, let onTrailingClick {
                Button(trailingButtonTitle, action: onTrailingClick)
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
            }
        }
    }
}

private struct SearchSuggestionRow: View {
    let text: String
    let isRecent: Bool
    let onTap: () -> Void
    let onFill: () -> Void
    var onDelete: (() -> Void)? = nil

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
                if isRecent, let onDelete {
                    Button(action: onDelete) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.35))
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                }
                Button(action: onFill) {
                    Image(systemName: "arrow.up.left")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.3))
                        .padding(4)
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
            case .artist: return "Artist"
            }
        }()

        let iconName: String = {
            switch item.kind {
            case .song: return "music.note"
            case .album: return "square.stack.fill"
            case .playlist: return "music.note.list"
            case .artist: return "person.crop.circle"
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
            case .artist:
                onNavigateArtist?(item.browseId ?? item.id)
            }
        }) {
            HStack(spacing: 14) {
                if let thumb = item.thumbnail, let url = URL(string: thumb) {
                    AsyncImage(url: url) { phase in
                        if let img = phase.image {
                            clipThumb(img.resizable().aspectRatio(contentMode: .fill))
                        } else {
                            clipThumb(Color.gray.opacity(0.3))
                        }
                    }
                    .frame(width: isTopResult ? 64 : 52, height: isTopResult ? 64 : 52)
                } else {
                    clipThumb(Color.gray.opacity(0.3))
                        .frame(width: isTopResult ? 64 : 52, height: isTopResult ? 64 : 52)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.system(size: isTopResult ? 17 : 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: isTopResult ? 14 : 12))
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

    @ViewBuilder
    private func clipThumb<Content: View>(_ content: Content) -> some View {
        if item.kind == .artist {
            content.clipShape(Circle())
        } else {
            content.clipShape(RoundedRectangle(cornerRadius: isTopResult ? 8 : 6))
        }
    }
}

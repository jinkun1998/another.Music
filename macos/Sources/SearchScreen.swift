import SwiftUI

public struct SearchScreen: View {
    let onPlay: (SongItem, [SongItem]) -> Void

    @State private var query: String = ""
    @State private var results: [SongItem] = []
    @State private var suggestions: [String] = []
    @State private var isSearching: Bool = false
    @State private var suggestionTask: Task<Void, Never>?

    public var body: some View {
        VStack(spacing: 20) {
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
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 6) {
                        ForEach(suggestions, id: \.self) { sug in
                            Button(action: {
                                query = sug
                                performSearch()
                            }) {
                                HStack(spacing: 14) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.4))
                                    Text(sug)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Image(systemName: "arrow.up.left")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.3))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 36)
                }
            } else if results.isEmpty && !query.isEmpty {
                Spacer()
                Text("No results")
                    .foregroundColor(.white.opacity(0.5))
                    .font(.system(size: 15))
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 14)], spacing: 14) {
                        ForEach(results) { item in
                            TrackRow(song: item, onPlay: { onPlay(item, results) })
                        }
                    }
                    .padding(.horizontal, 36)
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
        }
    }
}

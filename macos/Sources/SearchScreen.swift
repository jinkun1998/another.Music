import SwiftUI

public struct SearchScreen: View {
    let onPlay: (SongItem, [SongItem]) -> Void

    @State private var query: String = ""
    @State private var results: [SongItem] = []
    @State private var isSearching: Bool = false

    public var body: some View {
        VStack(spacing: 20) {
            // macOS native styled Search Field
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.6))
                    .font(.system(size: 16))

                TextField("Search songs, artists, albums...", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .onSubmit {
                        performSearch()
                    }

                if !query.isEmpty {
                    Button(action: { query = ""; results = [] }) {
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
            .padding(.top, 16)

            // Results grid
            if isSearching {
                Spacer()
                ProgressView()
                    .scaleEffect(1.2)
                Spacer()
            } else if results.isEmpty && !query.isEmpty {
                Spacer()
                Text("No results found for \"\(query)\"")
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
                    .padding(.bottom, 100)
                }
            }
        }
    }

    private func performSearch() {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearching = true
        Task {
            let res = await InnerTubeService.shared.search(query: query)
            self.results = res
            self.isSearching = false
        }
    }
}

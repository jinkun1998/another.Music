import SwiftUI

public struct LibraryScreen: View {
    let onPlay: (SongItem, [SongItem]) -> Void

    @ObservedObject private var library = LibraryStore.shared
    @State private var selectedFilter = "Liked"
    private let filters = ["Liked", "History"]

    public var body: some View {
        let items = selectedFilter == "Liked" ? library.likedSongs : library.history
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 10) {
                ForEach(filters, id: \.self) { filter in
                    let isSel = filter == selectedFilter
                    Button(action: { selectedFilter = filter }) {
                        Text(filter)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(isSel ? .black : .white.opacity(0.8))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(isSel ? Color.white : Color(white: 0.12))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 36)
            .padding(.top, 38)

            if items.isEmpty {
                Spacer()
                Image(systemName: "books.vertical")
                    .font(.system(size: 36))
                    .foregroundColor(.white.opacity(0.25))
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 14)], spacing: 14) {
                        ForEach(items) { s in
                            TrackRow(song: s, onPlay: { onPlay(s, items) })
                                .contextMenu {
                                    Button(library.isLiked(s) ? "Unlike" : "Like") { library.toggleLike(s) }
                                }
                        }
                    }
                    .padding(.horizontal, 36)
                    .padding(.bottom, 120)
                }
            }
        }
    }
}

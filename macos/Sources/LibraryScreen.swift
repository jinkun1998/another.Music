import SwiftUI

public struct LibraryScreen: View {
    let onPlay: (SongItem, [SongItem]) -> Void

    @State private var selectedFilter = "Playlists"
    private let filters = ["Playlists", "Songs", "Albums", "Artists"]

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Your Library")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 36)
                .padding(.top, 16)

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

            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "books.vertical")
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.3))
                Text("No saved \(selectedFilter.lowercased()) yet")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Text("Songs and playlists you play will appear here")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity)

            Spacer()
        }
    }
}

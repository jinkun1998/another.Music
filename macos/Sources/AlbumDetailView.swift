import SwiftUI

public struct AlbumDetailView: View {
    let item: SongItem
    let onPlay: (SongItem, [SongItem]) -> Void
    let onClose: () -> Void

    @State private var detail: (title: String, artist: String, thumbnail: String?, tracks: [SongItem])?
    @State private var failed = false

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                Button(action: onClose) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Color.white.opacity(0.10))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.leading, 84).padding(.top, 16).padding(.bottom, 12)

                if let d = detail {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 20) {
                            HStack(spacing: 24) {
                                Thumb(url: d.thumbnail ?? item.thumbnail, size: 180)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(d.title).font(.system(size: 28, weight: .bold)).foregroundColor(.white).lineLimit(2)
                                    Text(d.artist).font(.system(size: 15)).foregroundColor(.white.opacity(0.65))
                                    Text("\(d.tracks.count) songs").font(.system(size: 12)).foregroundColor(.white.opacity(0.45))
                                    Button(action: { if let f = d.tracks.first { onPlay(f, d.tracks) } }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "play.fill")
                                            Text("Play All")
                                        }
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 22).padding(.vertical, 10)
                                        .background(Color.white.opacity(0.16))
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            LazyVStack(spacing: 8) {
                                ForEach(d.tracks) { t in
                                    TrackRow(song: t, onPlay: { onPlay(t, d.tracks) })
                                }
                            }
                        }
                        .padding(.horizontal, 36)
                        .padding(.bottom, 120)
                    }
                } else if failed {
                    Spacer()
                    Text("Could not load").foregroundColor(.white.opacity(0.5)).frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    Spacer()
                    ProgressView().frame(maxWidth: .infinity)
                    Spacer()
                }
            }
        }
        .task(id: item.id) {
            guard let bid = item.browseId else { failed = true; return }
            if let r = await InnerTubeService.shared.fetchBrowseAlbumOrPlaylist(browseId: bid), !r.tracks.isEmpty {
                detail = r
            } else {
                failed = true
            }
        }
    }
}

private struct Thumb: View {
    let url: String?
    let size: CGFloat
    var body: some View {
        Group {
            if let u = url.flatMap(URL.init(string:)) {
                AsyncImage(url: u) { p in
                    if let i = p.image { i.resizable().aspectRatio(contentMode: .fill) } else { Color.gray.opacity(0.3) }
                }
            } else { Color.gray.opacity(0.3) }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

import SwiftUI

@MainActor public struct QueueDrawerView: View {
    @ObservedObject var player: AudioPlayerService

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text("Queue")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "infinity")
                        .font(.system(size: 11, weight: .bold))
                    Text("Autoplay")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(player.isAutoplay ? Color.white : .white.opacity(0.5))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(player.isAutoplay ? Color.white.opacity(0.18) : Color.white.opacity(0.06))
                .clipShape(Capsule())
                .contentShape(Capsule())
                .onTapGesture { player.toggleAutoplay() }

                Text("\(player.queue.count) songs")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 10)

            Divider().background(Color.white.opacity(0.1))

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(player.queue.enumerated()), id: \.element.id) { idx, song in
                        let isActive = idx == player.currentIndex
                        HStack(spacing: 10) {
                            if let thumb = song.thumbnail, let url = URL(string: thumb) {
                                AsyncImage(url: url) { phase in
                                    if let img = phase.image {
                                        img.resizable().aspectRatio(contentMode: .fill)
                                    } else {
                                        Color.gray.opacity(0.3)
                                    }
                                }
                                .frame(width: 36, height: 36)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            } else {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.1))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Image(systemName: "music.note")
                                            .font(.system(size: 12))
                                            .foregroundColor(.white.opacity(0.4))
                                    )
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(song.title)
                                    .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                                    .foregroundColor(isActive ? Color.white : .white)
                                    .lineLimit(1)
                                Text(song.artist)
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.55))
                                    .lineLimit(1)
                            }

                            Spacer()

                            if isActive {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color.white)
                            }

                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.4))
                                .frame(width: 24, height: 24)
                                .contentShape(Rectangle())
                                .onTapGesture { player.removeFromQueue(at: idx) }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isActive ? Color.white.opacity(0.07) : Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture { player.playAt(index: idx) }
                    }
                }
            }
        }
        .background(Color(white: 0.08).opacity(0.98))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}

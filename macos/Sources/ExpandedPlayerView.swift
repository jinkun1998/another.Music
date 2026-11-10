import SwiftUI

public struct ExpandedPlayerView: View {
    let track: SongItem
    @ObservedObject var player: AudioPlayerService
    let onClose: () -> Void

    @State private var lyrics: [LyricLine] = []
    @State private var useVinyl: Bool = true
    @State private var isSeeking: Bool = false
    @State private var seekProgress: Double = 0.0

    public var body: some View {
        ZStack {
            // Dark gradient backdrop
            RadialGradient(
                stops: [
                    .init(color: Color(red: 0.16, green: 0.10, blue: 0.14), location: 0),
                    .init(color: Color(red: 0.08, green: 0.07, blue: 0.10), location: 0.65),
                    .init(color: Color(red: 0.05, green: 0.04, blue: 0.06), location: 1.0)
                ],
                center: .center,
                startRadius: 100,
                endRadius: 700
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top header bar
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 38, height: 38)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    // Cover mode / Vinyl mode switcher
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            useVinyl.toggle()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: useVinyl ? "record.circle" : "square.stack.fill")
                                .font(.system(size: 13))
                            Text(useVinyl ? "Vinyl Mode" : "Cover Mode")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.10))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 32)
                .padding(.top, 24)

                // Main two-column content
                HStack(spacing: 48) {
                    // Left: Vinyl or Cover Art + Track details
                    VStack(spacing: 28) {
                        Spacer()

                        ZStack {
                            if useVinyl {
                                TurntableCanvas(
                                    thumbnail: track.thumbnail,
                                    title: track.title,
                                    isPlaying: player.isPlaying,
                                    progress: player.progress
                                )
                                .frame(width: 380, height: 380)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.88).combined(with: .opacity),
                                    removal: .scale(scale: 0.88).combined(with: .opacity)
                                ))
                            } else {
                                if let thumb = track.thumbnail, let url = URL(string: thumb) {
                                    AsyncImage(url: url) { phase in
                                        if let img = phase.image {
                                            img.resizable().aspectRatio(contentMode: .fill)
                                        } else {
                                            Color.gray.opacity(0.3)
                                        }
                                    }
                                    .frame(width: 360, height: 360)
                                    .clipShape(RoundedRectangle(cornerRadius: 24))
                                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.15), lineWidth: 1))
                                    .shadow(color: .black.opacity(0.4), radius: 25, y: 12)
                                    .scaleEffect(player.isPlaying ? 1.0 : 0.94)
                                    .animation(.easeInOut(duration: 0.4), value: player.isPlaying)
                                    .transition(.asymmetric(
                                        insertion: .scale(scale: 0.88).combined(with: .opacity),
                                        removal: .scale(scale: 0.88).combined(with: .opacity)
                                    ))
                                }
                            }
                        }

                        VStack(spacing: 6) {
                            Text(track.title)
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Text(track.artist)
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: 380)

                        Spacer()
                    }
                    .frame(maxWidth: .infinity)

                    // Right: Synced Lyrics panel
                    VStack {
                        SyncedLyricsView(
                            lyrics: lyrics,
                            currentTimeMs: Int64(player.positionSec * 1000),
                            durationMs: Int64(player.durationSec * 1000),
                            onSeek: { player.seek(to: $0) }
                        )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.08), lineWidth: 1))
                    .padding(.vertical, 16)
                }
                .padding(.horizontal, 48)

                // Bottom scrubber and controls
                VStack(spacing: 8) {
                    // Scrubber slider
                    GeometryReader { geo in
                        let activeVal = isSeeking ? seekProgress : player.progress
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.18))
                                .frame(height: 5)

                            Capsule()
                                .fill(Color(red: 1.0, green: 0.18, blue: 0.34))
                                .frame(width: max(geo.size.width * activeVal, 0), height: 5)

                            Circle()
                                .fill(Color.white)
                                .frame(width: 13, height: 13)
                                .offset(x: max(geo.size.width * activeVal - 6.5, 0))
                        }
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    isSeeking = true
                                    seekProgress = min(max(value.location.x / geo.size.width, 0.0), 1.0)
                                }
                                .onEnded { value in
                                    let finalVal = min(max(value.location.x / geo.size.width, 0.0), 1.0)
                                    player.seek(to: finalVal)
                                    isSeeking = false
                                }
                        )
                    }
                    .frame(height: 18)
                    .padding(.horizontal, 48)

                    // Time labels & Controls row
                    HStack {
                        let curSec = isSeeking ? (seekProgress * player.durationSec) : player.positionSec
                        Text("\(formatTime(curSec)) / \(formatTime(player.durationSec))")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 140, alignment: .leading)

                        Spacer()

                        // Central controls
                        HStack(spacing: 20) {
                            Button(action: {}) {
                                Image(systemName: "shuffle")
                                    .font(.system(size: 15))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .buttonStyle(.plain)

                            Button(action: { player.previous() }) {
                                Image(systemName: "backward.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.white)
                            }
                            .buttonStyle(.plain)

                            Button(action: { player.togglePlayPause() }) {
                                ZStack {
                                    Circle()
                                        .fill(Color(red: 1.0, green: 0.18, blue: 0.34))
                                        .frame(width: 52, height: 52)
                                        .shadow(color: Color(red: 1.0, green: 0.18, blue: 0.34).opacity(0.4), radius: 10)

                                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            .buttonStyle(.plain)

                            Button(action: { player.next() }) {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.white)
                            }
                            .buttonStyle(.plain)

                            Button(action: {}) {
                                Image(systemName: "repeat")
                                    .font(.system(size: 15))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                        }

                        Spacer()

                        // Volume Slider
                        HStack(spacing: 8) {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.6))
                            Slider(value: Binding(
                                get: { Double(player.volume) },
                                set: { player.setVolume(Float($0)) }
                            ), in: 0...1)
                            .frame(width: 100)
                        }
                        .frame(width: 140, alignment: .trailing)
                    }
                    .padding(.horizontal, 48)
                }
                .padding(.bottom, 32)
            }
        }
        .task(id: track.id) {
            let fetched = await LyricsService.shared.fetchLyrics(
                title: track.title,
                artist: track.artist,
                durationSec: Int(player.durationSec)
            )
            self.lyrics = fetched
        }
    }

    private func formatTime(_ sec: Double) -> String {
        guard sec.isFinite && sec >= 0 else { return "0:00" }
        let total = Int(sec)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}

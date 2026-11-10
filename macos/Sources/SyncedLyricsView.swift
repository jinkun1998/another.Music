import SwiftUI

public struct SyncedLyricsView: View {
    let lyrics: [LyricLine]
    let currentTimeMs: Int64
    let durationMs: Int64
    let onSeek: (Double) -> Void

    public var body: some View {
        if lyrics.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 32))
                    .foregroundColor(.white.opacity(0.3))
                Text("No synchronized lyrics available")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            let activeIndex = lyrics.lastIndex(where: { $0.timeMs <= currentTimeMs }) ?? 0

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        Color.clear.frame(height: 140)

                        ForEach(Array(lyrics.enumerated()), id: \.element.id) { index, line in
                            let isActive = index == activeIndex
                            Text(line.text)
                                .font(.system(size: isActive ? 26 : 20, weight: isActive ? .bold : .medium))
                                .foregroundColor(isActive ? .white : .white.opacity(0.28))
                                .lineSpacing(6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if durationMs > 0 {
                                        onSeek(Double(line.timeMs) / Double(durationMs))
                                    }
                                }
                                .id(index)
                                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isActive)
                        }

                        Color.clear.frame(height: 160)
                    }
                    .padding(.horizontal, 28)
                }
                .onChange(of: activeIndex) { _, newIndex in
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
        }
    }
}

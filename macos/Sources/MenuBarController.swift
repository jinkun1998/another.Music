import SwiftUI

struct MenuBarController: View {
    @ObservedObject var player: AudioPlayerService

    var body: some View {
        VStack(spacing: 10) {
            Text(player.currentTrack?.title ?? "Not playing").font(.system(size: 13, weight: .semibold)).lineLimit(1)
            Text(player.currentTrack?.artist ?? " ").font(.system(size: 11)).foregroundColor(.secondary).lineLimit(1)
            ProgressView(value: player.progress)
            if player.sleepTimerOption != .off {
                let text = player.sleepTimerOption == .endOfTrack ? "Sleep: End of track" : "Sleep in \(player.sleepTimerRemainingSec / 60)m \(player.sleepTimerRemainingSec % 60)s"
                Text(text)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color.white)
            }
            HStack(spacing: 22) {
                Button { player.previous() } label: { Image(systemName: "backward.fill") }
                Button { player.togglePlayPause() } label: { Image(systemName: player.isPlaying ? "pause.fill" : "play.fill").font(.system(size: 18)) }
                Button { player.next() } label: { Image(systemName: "forward.fill") }
            }
            .buttonStyle(.plain)
            Divider()
            Button("Open anotherMusic") { NSApp.activate(ignoringOtherApps: true); NSApp.windows.first?.makeKeyAndOrderFront(nil) }
            Button("Quit") { NSApp.terminate(nil) }
        }
        .padding(14)
        .frame(width: 240)
    }
}

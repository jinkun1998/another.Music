import Foundation
import AVFoundation
import MediaPlayer
import Combine

@MainActor
public final class AudioPlayerService: ObservableObject {
    public static let shared = AudioPlayerService()

    private var player: AVPlayer?
    private var timeObserverToken: Any?
    private var endObserverToken: Any?

    @Published public var currentTrack: SongItem?
    @Published public var isPlaying: Bool = false
    @Published public var progress: Double = 0.0
    @Published public var positionSec: Double = 0.0
    @Published public var durationSec: Double = 0.0
    @Published public var volume: Float = 0.8
    @Published public var queue: [SongItem] = []
    @Published public var currentIndex: Int = -1

    private init() {
        setupRemoteCommands()
    }

    public func play(song: SongItem, newQueue: [SongItem] = []) {
        if !newQueue.isEmpty {
            self.queue = newQueue
            self.currentIndex = newQueue.firstIndex(where: { $0.id == song.id }) ?? 0
        } else if !queue.contains(where: { $0.id == song.id }) {
            queue.append(song)
            currentIndex = queue.count - 1
        }

        self.currentTrack = song
        self.positionSec = 0
        self.progress = 0
        if let d = song.duration, d > 0 {
            self.durationSec = Double(d)
        }

        Task {
            guard let stream = await InnerTubeService.shared.resolveStream(videoId: song.id) else {
                return
            }

            if stream.durationMs > 0 {
                self.durationSec = Double(stream.durationMs) / 1000.0
            }

            guard let url = URL(string: stream.url) else { return }
            self.startPlayback(url: url)
        }
    }

    private func startPlayback(url: URL) {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        if let token = endObserverToken {
            NotificationCenter.default.removeObserver(token)
            endObserverToken = nil
        }

        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.volume = self.volume

        self.player = newPlayer

        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = newPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let current = time.seconds
                if current.isFinite && current >= 0 {
                    self.positionSec = current
                    let dur = self.durationSec > 0 ? self.durationSec : (self.player?.currentItem?.duration.seconds ?? 0)
                    if dur > 0 && dur.isFinite {
                        self.durationSec = dur
                        self.progress = min(max(current / dur, 0.0), 1.0)
                    }
                    self.updateNowPlaying()
                }
            }
        }

        endObserverToken = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.next()
            }
        }

        newPlayer.play()
        self.isPlaying = true
        updateNowPlaying()
    }

    public func togglePlayPause() {
        guard let p = player else {
            if let track = currentTrack {
                play(song: track, newQueue: queue)
            }
            return
        }

        if isPlaying {
            p.pause()
            isPlaying = false
        } else {
            if positionSec >= durationSec - 1.0 && durationSec > 0 {
                seek(to: 0.0)
            }
            p.play()
            isPlaying = true
        }
        updateNowPlaying()
    }

    public func seek(to fraction: Double) {
        guard let p = player else { return }
        let clamped = min(max(fraction, 0.0), 1.0)
        let targetSec = clamped * durationSec
        self.positionSec = targetSec
        self.progress = clamped

        let cmTime = CMTime(seconds: targetSec, preferredTimescale: 600)
        p.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        updateNowPlaying()
    }

    public func setVolume(_ vol: Float) {
        let clamped = min(max(vol, 0.0), 1.0)
        self.volume = clamped
        player?.volume = clamped
    }

    public func next() {
        guard !queue.isEmpty else { return }
        let nextIdx = currentIndex + 1
        if nextIdx < queue.count {
            currentIndex = nextIdx
            play(song: queue[nextIdx], newQueue: queue)
        } else {
            player?.pause()
            isPlaying = false
            seek(to: 0.0)
        }
    }

    public func previous() {
        if positionSec > 3.0 {
            seek(to: 0.0)
            return
        }
        guard !queue.isEmpty else { return }
        let prevIdx = currentIndex - 1
        if prevIdx >= 0 {
            currentIndex = prevIdx
            play(song: queue[prevIdx], newQueue: queue)
        } else {
            seek(to: 0.0)
        }
    }

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }

        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }

        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }

        center.nextTrackCommand.isEnabled = true
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.next()
            return .success
        }

        center.previousTrackCommand.isEnabled = true
        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.previous()
            return .success
        }

        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self, let posEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            if self.durationSec > 0 {
                self.seek(to: posEvent.positionTime / self.durationSec)
            }
            return .success
        }
    }

    private func updateNowPlaying() {
        guard let track = currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: positionSec,
            MPMediaItemPropertyPlaybackDuration: durationSec,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]

        if let album = track.album {
            info[MPMediaItemPropertyAlbumTitle] = album
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}

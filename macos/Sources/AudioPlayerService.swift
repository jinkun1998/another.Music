public enum SleepTimerOption: String, CaseIterable, Sendable {
    case off = "Off"
    case min15 = "15 min"
    case min30 = "30 min"
    case min45 = "45 min"
    case min60 = "60 min"
    case endOfTrack = "End of track"
}

import Foundation
import AVFoundation
import MediaPlayer
import Combine
import AppKit

public enum TransitionMode: String, CaseIterable, Sendable {
    case automix = "Auto Mix"
    case crossfade = "Cross Fade"
    case off = "Off"
}

public enum RepeatMode: String, CaseIterable, Sendable {
    case off
    case all
    case one
}

@MainActor
public final class AudioPlayerService: ObservableObject {
    public static let shared = AudioPlayerService()

    private var player: AVPlayer?
    private var timeObserverToken: Any?
    private var endObserverToken: Any?
    private var failObserverToken: Any?
    private var statusObservation: NSKeyValueObservation?
    private var advancedForItem: ObjectIdentifier?
    private var isSeekingInProgress: Bool = false
    private var resolveTask: Task<Void, Never>?
    private var originalQueue: [SongItem] = []

    @Published public var currentTrack: SongItem?
    @Published public var isPlaying: Bool = false
    @Published public var progress: Double = 0.0
    @Published public var positionSec: Double = 0.0
    @Published public var durationSec: Double = 0.0
    @Published public var volume: Float = 0.8
    @Published public var queue: [SongItem] = []
    @Published public var currentIndex: Int = -1
    @Published public var isShuffle: Bool = false
    @Published public var repeatMode: RepeatMode = .off
    @Published public var isAutoplay: Bool = true
    @Published public var sleepTimerOption: SleepTimerOption = .off
    @Published public var sleepTimerRemainingSec: Int = 0
    private var sleepTimer: Timer?

    @Published public var transitionMode: TransitionMode {
        didSet {
            UserDefaults.standard.set(transitionMode.rawValue, forKey: "transitionMode")
            UserDefaults.standard.set(transitionMode == .automix, forKey: "automixEnabled")
            UserDefaults.standard.set(transitionMode == .crossfade, forKey: "crossfadeEnabled")
            if transitionMode == .off && isTransitioning {
                cancelCrossmix()
            }
        }
    }

    public var isAutomix: Bool {
        get { transitionMode == .automix }
        set { transitionMode = newValue ? .automix : .off }
    }
    @Published public var isEqEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEqEnabled, forKey: "eqEnabled")
        }
    }
    @Published public private(set) var isTransitioning: Bool = false
    private var transitionStartDate: Date?

    // Dual-Deck Crossmix Engine (Phase 2 AutoMix)
    private var secondaryPlayer: AVPlayer?
    private var preloadedTrack: (song: SongItem, item: AVPlayerItem, durSec: Double)?
    private var preloadTask: Task<Void, Never>?
    private var crossmixTimer: Timer?

    private var radioTask: Task<Void, Never>?
    private var artwork: MPMediaItemArtwork?
    private var artworkId: String?
    private var artworkTask: Task<Void, Never>?

    private init() {
        if let raw = UserDefaults.standard.string(forKey: "transitionMode") {
            if raw == "AutoMix" || raw == "Auto Mix" {
                self.transitionMode = .automix
            } else if raw == "Crossfade" || raw == "Cross Fade" {
                self.transitionMode = .crossfade
            } else {
                self.transitionMode = .off
            }
        } else {
            let auto = UserDefaults.standard.object(forKey: "automixEnabled") as? Bool ?? true
            let cross = UserDefaults.standard.bool(forKey: "crossfadeEnabled")
            if auto {
                self.transitionMode = .automix
            } else if cross {
                self.transitionMode = .crossfade
            } else {
                self.transitionMode = .off
            }
        }
        self.isEqEnabled = UserDefaults.standard.bool(forKey: "eqEnabled")
        setupRemoteCommands()
        restoreLastTrack()
    }

    public func setTransitionMode(_ mode: TransitionMode) {
        self.transitionMode = mode
    }

    public func toggleEqualizer() {
        isEqEnabled.toggle()
    }

    public func toggleAutomix() {
        if transitionMode == .automix {
            setTransitionMode(.off)
        } else {
            setTransitionMode(.automix)
        }
    }

    public func restoreLastTrack() {
        guard currentTrack == nil, let last = LibraryStore.shared.history.first else { return }
        prepare(song: last, queue: LibraryStore.shared.history)
    }

    public func prepare(song: SongItem, queue: [SongItem] = []) {
        guard song.kind == .song else { return }
        let songs = queue.filter { $0.kind == .song }
        let cleanQueue = songs.isEmpty ? [song] : songs
        self.originalQueue = cleanQueue
        self.queue = cleanQueue
        self.currentIndex = cleanQueue.firstIndex(where: { $0.id == song.id }) ?? 0
        let isSameSong = self.currentTrack?.id == song.id
        let initialSec = (isSameSong && self.positionSec > 0) ? self.positionSec : 0.0
        self.currentTrack = song
        self.positionSec = initialSec
        self.durationSec = Double(song.duration ?? 0)
        self.progress = self.durationSec > 0 ? (initialSec / self.durationSec) : 0
        self.isPlaying = false
        updateNowPlaying()
    }

    public func play(song: SongItem, newQueue: [SongItem] = []) {
        guard song.kind == .song else { return }
        cancelCrossmix()

        if !newQueue.isEmpty {
            let songs = newQueue.filter { $0.kind == .song }
            let cleanQueue = songs.isEmpty ? [song] : songs
            self.originalQueue = cleanQueue
            if isShuffle {
                let rest = cleanQueue.filter { $0.id != song.id }.shuffled()
                self.queue = [song] + rest
                self.currentIndex = 0
            } else {
                self.queue = cleanQueue
                self.currentIndex = cleanQueue.firstIndex(where: { $0.id == song.id }) ?? 0
            }
        } else if let idx = queue.firstIndex(where: { $0.id == song.id }) {
            self.currentIndex = idx
        } else {
            queue.append(song)
            originalQueue.append(song)
            currentIndex = queue.count - 1
        }

        self.currentTrack = song
        self.positionSec = 0
        self.progress = 0
        self.durationSec = Double(song.duration ?? 0)
        LibraryStore.shared.recordPlay(song)
        if isAutoplay && (queue.count <= 6 || currentIndex >= queue.count - 2) {
            loadRadio(seed: song)
        }

        resolveTask?.cancel()
        resolveTask = Task {
            let resolved = await InnerTubeService.shared.resolveStream(videoId: song.id)
            guard !Task.isCancelled else { return }
            guard let stream = resolved else {
                // ponytail: skip unplayable track; stops when queue ends
                self.isPlaying = false
                if self.currentIndex + 1 < self.queue.count { self.next(autoAdvance: true) }
                return
            }

            if stream.durationMs > 0 {
                self.durationSec = Double(stream.durationMs) / 1000.0
                if let curItem = self.player?.currentItem {
                    curItem.forwardPlaybackEndTime = CMTime(seconds: self.durationSec, preferredTimescale: 600)
                }
            }

            guard let url = URL(string: stream.url) else { return }
            self.startPlayback(url: url)
        }
    }

    public func toggleShuffle() {
        isShuffle.toggle()
        guard !queue.isEmpty else { return }

        if isShuffle {
            if originalQueue.isEmpty {
                originalQueue = queue
            }
            if let current = currentTrack, queue.contains(where: { $0.id == current.id }) {
                let rest = queue.filter { $0.id != current.id }.shuffled()
                queue = [current] + rest
                currentIndex = 0
            } else {
                queue.shuffle()
            }
        } else {
            if !originalQueue.isEmpty {
                queue = originalQueue
            }
            if let current = currentTrack {
                currentIndex = queue.firstIndex(where: { $0.id == current.id }) ?? 0
            }
        }
    }

    public func setSleepTimer(_ option: SleepTimerOption) {
        sleepTimer?.invalidate()
        sleepTimer = nil
        sleepTimerOption = option

        switch option {
        case .off:
            sleepTimerRemainingSec = 0
        case .min15:
            startSleepCountdown(seconds: 15 * 60)
        case .min30:
            startSleepCountdown(seconds: 30 * 60)
        case .min45:
            startSleepCountdown(seconds: 45 * 60)
        case .min60:
            startSleepCountdown(seconds: 60 * 60)
        case .endOfTrack:
            sleepTimerRemainingSec = 0
        }
    }

    private func startSleepCountdown(seconds: Int) {
        sleepTimerRemainingSec = seconds
        sleepTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            Task { @MainActor [weak self] in
                guard let self else { timer.invalidate(); return }
                if self.sleepTimerRemainingSec > 1 {
                    self.sleepTimerRemainingSec -= 1
                } else {
                    timer.invalidate()
                    self.sleepTimer = nil
                    self.sleepTimerOption = .off
                    self.sleepTimerRemainingSec = 0
                    self.player?.pause()
                    self.isPlaying = false
                }
            }
        }
    }

    public func toggleAutoplay() {
        isAutoplay.toggle()
        if isAutoplay, let cur = currentTrack, (queue.count <= 2 || currentIndex >= queue.count - 2) {
            loadRadio(seed: cur)
        }
    }

    private func loadRadio(seed: SongItem) {
        radioTask?.cancel()
        radioTask = Task {
            let radio = await InnerTubeService.shared.fetchRadio(videoId: seed.id)
            guard !Task.isCancelled else { return }
            let newTracks = radio.filter { r in !self.queue.contains(where: { $0.id == r.id }) }
            guard !newTracks.isEmpty else { return }
            self.queue.append(contentsOf: newTracks)
            self.originalQueue.append(contentsOf: newTracks)
        }
    }

    public func cycleRepeatMode() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }

    public func playAt(index: Int) {
        guard queue.indices.contains(index) else { return }
        currentIndex = index
        play(song: queue[index])
    }

    public func removeFromQueue(at index: Int) {
        cancelCrossmix()
        guard queue.indices.contains(index) else { return }
        let removed = queue.remove(at: index)
        originalQueue.removeAll(where: { $0.id == removed.id })

        if queue.isEmpty {
            player?.pause()
            player = nil
            currentTrack = nil
            currentIndex = -1
            isPlaying = false
            positionSec = 0
            durationSec = 0
            progress = 0
            updateNowPlaying()
            return
        }

        if index < currentIndex {
            currentIndex -= 1
        } else if index == currentIndex {
            let nextIdx = min(index, queue.count - 1)
            currentIndex = nextIdx
            play(song: queue[nextIdx])
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
        if let token = failObserverToken {
            NotificationCenter.default.removeObserver(token)
            failObserverToken = nil
        }
        statusObservation = nil

        let headers = ["User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"]
        let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        let item = AVPlayerItem(asset: asset)
        item.audioTimePitchAlgorithm = .timeDomain
        if self.durationSec > 0 {
            // ponytail: clamp playback to exact YouTube track duration; prevents fMP4 2x moov+sidx duration bug from playing past track end
            item.forwardPlaybackEndTime = CMTime(seconds: self.durationSec, preferredTimescale: 600)
        }
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.volume = self.volume

        self.player = newPlayer
        attachObservers(to: newPlayer, item: item)

        if self.positionSec > 0 {
            let cmTime = CMTime(seconds: self.positionSec, preferredTimescale: 600)
            newPlayer.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        }

        newPlayer.play()
        self.isPlaying = true
        updateNowPlaying()
    }

    private func attachObservers(to newPlayer: AVPlayer, item: AVPlayerItem) {
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        let itemId = ObjectIdentifier(item)
        timeObserverToken = newPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self, !self.isSeekingInProgress else { return }
                let current = time.seconds
                if current.isFinite && current >= 0 {
                    if self.durationSec > 0 {
                        self.positionSec = min(current, self.durationSec)
                        self.progress = min(max(current / self.durationSec, 0.0), 1.0)

                        // 1. Preload upcoming song ~14s before finish
                        if current >= self.durationSec - 14.0 {
                            self.maybePreloadNextTrack()
                        }

                        // 2. Dual-Deck Equal-Power AutoMix Trigger
                        if self.shouldCrossfade, let pre = self.preloadedTrack, !self.isTransitioning, current >= (self.durationSec - self.crossmixDuration) {
                            self.startCrossmix(to: pre, duration: self.crossmixDuration)
                        } else if current >= self.durationSec - 0.25 && !self.isTransitioning {
                            self.advanceOnce(itemId)
                        }
                    } else {
                        self.positionSec = current
                        let dur = self.player?.currentItem?.duration.seconds ?? 0
                        if dur > 0 && dur.isFinite {
                            self.durationSec = dur
                            self.progress = min(max(current / dur, 0.0), 1.0)
                        }
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
                self?.advanceOnce(itemId)
            }
        }

        failObserverToken = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.advanceOnce(itemId) }
        }
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] it, _ in
            guard it.status == .failed else { return }
            Task { @MainActor [weak self] in self?.advanceOnce(itemId) }
        }
        advancedForItem = nil
    }

    // MARK: - AutoMix / Dual-Deck Engine
    private var shouldCrossfade: Bool {
        guard repeatMode != .one, nextIndex != nil else { return false }
        return transitionMode != .off
    }

    private var crossmixDuration: Double {
        let baseDur: Double
        if transitionMode == .automix {
            let dur = UserDefaults.standard.double(forKey: "crossfadeDuration")
            baseDur = dur > 0 ? min(max(dur, 4.0), 12.0) : 8.0
        } else {
            let dur = UserDefaults.standard.double(forKey: "crossfadeDuration")
            baseDur = dur > 0 ? min(max(dur, 2.0), 12.0) : 5.0
        }
        return durationSec > 0 ? min(baseDur, max(2.0, durationSec * 0.35)) : baseDur
    }

    private var nextIndex: Int? {
        guard !queue.isEmpty else { return nil }
        let next = currentIndex + 1
        if next < queue.count { return next }
        if repeatMode == .all { return 0 }
        return nil
    }

    private func maybePreloadNextTrack() {
        guard let nextIdx = nextIndex, queue.indices.contains(nextIdx),
              preloadedTrack == nil, preloadTask == nil else { return }
        let nextSong = queue[nextIdx]
        preloadTask = Task {
            let res = await InnerTubeService.shared.resolveStream(videoId: nextSong.id)
            guard !Task.isCancelled, let stream = res, let url = URL(string: stream.url) else {
                self.preloadTask = nil
                return
            }
            let headers = ["User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"]
            let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
            let item = AVPlayerItem(asset: asset)
            item.audioTimePitchAlgorithm = .timeDomain
            let dur = stream.durationMs > 0 ? (Double(stream.durationMs) / 1000.0) : Double(nextSong.duration ?? 0)
            if dur > 0 {
                item.forwardPlaybackEndTime = CMTime(seconds: dur, preferredTimescale: 600)
            }
            let sec = AVPlayer(playerItem: item)
            sec.volume = 0
            self.secondaryPlayer = sec
            self.preloadedTrack = (song: nextSong, item: item, durSec: dur)
            self.preloadTask = nil
        }
    }

    private func cancelCrossmix() {
        crossmixTimer?.invalidate()
        crossmixTimer = nil
        preloadTask?.cancel()
        preloadTask = nil
        secondaryPlayer?.pause()
        secondaryPlayer?.rate = 1.0
        secondaryPlayer = nil
        preloadedTrack = nil
        isTransitioning = false
        player?.rate = 1.0
        player?.volume = self.volume
    }

    /// Phase 2 Intelligent Bass-Swap Gain Curves
    nonisolated public static func calculateAutomixGains(progress: Double) -> (outGain: Double, inGain: Double) {
        let p = min(max(progress, 0.0), 1.0)
        func smoothstep(_ x: Double) -> Double {
            let c = min(max(x, 0.0), 1.0)
            return c * c * (3.0 - 2.0 * c)
        }

        if p < 0.35 {
            // Phase A: Entrance (outgoing maintains 100% full low-end driver; incoming fades in airy highs/mids)
            let inFrac = smoothstep(p / 0.35)
            let outGain = 1.0
            let inGain = 0.50 * inFrac
            return (outGain, inGain)
        } else if p <= 0.65 {
            // Phase B: Bass Swap crossover window (outgoing drops bass; incoming kicks into full low-end driver)
            let swapFrac = smoothstep((p - 0.35) / 0.30)
            let outGain = 1.0 - 0.60 * swapFrac
            let inGain = 0.50 + 0.50 * swapFrac
            return (outGain, inGain)
        } else {
            // Phase C: Outro handoff (incoming owns the track; outgoing tails dissipate to zero)
            let outroFrac = smoothstep((p - 0.65) / 0.35)
            let outGain = 0.40 * (1.0 - outroFrac)
            let inGain = 1.0
            return (outGain, inGain)
        }
    }

    private func startCrossmix(to pre: (song: SongItem, item: AVPlayerItem, durSec: Double), duration: Double) {
        guard !isTransitioning, let sec = secondaryPlayer else { return }
        isTransitioning = true
        let start = Date()
        transitionStartDate = start

        sec.volume = 0
        sec.play()
        if transitionMode == .automix {
            // Micro-tempo alignment: slight nudge locks incoming momentum to outgoing groove
            sec.rate = 1.008
        }

        crossmixTimer?.invalidate()
        crossmixTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            Task { @MainActor [weak self] in
                guard let self, self.isTransitioning else {
                    timer.invalidate()
                    return
                }
                let elapsed = Date().timeIntervalSince(start)
                let frac = min(max(elapsed / duration, 0.0), 1.0)

                let outVol: Float
                let inVol: Float

                if self.transitionMode == .automix {
                    let (outCurve, inCurve) = AudioPlayerService.calculateAutomixGains(progress: frac)
                    let totalPower = (outCurve * outCurve) + (inCurve * inCurve)
                    let headroom = totalPower > 1.0 ? (1.0 / sqrt(totalPower)) : 1.0
                    outVol = Float(outCurve * headroom) * self.volume
                    inVol = Float(inCurve * headroom) * self.volume
                } else {
                    let theta = frac * (.pi / 2.0)
                    outVol = Float(cos(theta)) * self.volume
                    inVol = Float(sin(theta)) * self.volume
                }

                self.player?.volume = outVol
                self.secondaryPlayer?.volume = inVol

                if frac >= 1.0 {
                    timer.invalidate()
                    self.crossmixTimer = nil
                    self.finishCrossmix(to: pre, overlapSec: duration)
                }
            }
        }
    }

    private func finishCrossmix(to pre: (song: SongItem, item: AVPlayerItem, durSec: Double), overlapSec: Double) {
        let old = player
        old?.pause()
        old?.rate = 1.0

        guard let newPlayer = secondaryPlayer else {
            isTransitioning = false
            return
        }
        newPlayer.rate = 1.0
        newPlayer.volume = self.volume
        self.player = newPlayer
        self.secondaryPlayer = nil
        self.isTransitioning = false
        self.preloadedTrack = nil

        if let token = timeObserverToken {
            old?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        if let token = endObserverToken {
            NotificationCenter.default.removeObserver(token)
            endObserverToken = nil
        }
        if let token = failObserverToken {
            NotificationCenter.default.removeObserver(token)
            failObserverToken = nil
        }
        statusObservation = nil

        let newItem = pre.item
        attachObservers(to: newPlayer, item: newItem)

        self.currentTrack = pre.song
        self.currentIndex = queue.firstIndex(where: { $0.id == pre.song.id }) ?? (currentIndex + 1)
        self.durationSec = pre.durSec
        self.positionSec = overlapSec
        self.progress = min(overlapSec / max(pre.durSec, 1.0), 1.0)
        self.isPlaying = true
        LibraryStore.shared.recordPlay(pre.song)

        if isAutoplay && (queue.count <= 6 || currentIndex >= queue.count - 2) {
            loadRadio(seed: pre.song)
        }
        updateNowPlaying()
    }

    private func advanceOnce(_ id: ObjectIdentifier) {
        guard advancedForItem != id, let cur = player?.currentItem, ObjectIdentifier(cur) == id else { return }
        advancedForItem = id
        handleTrackEnded()
    }

    private func handleTrackEnded() {
        if sleepTimerOption == .endOfTrack {
            sleepTimerOption = .off
            player?.pause()
            isPlaying = false
            updateNowPlaying()
            return
        }

        if repeatMode == .one {
            seek(to: 0.0)
            player?.play()
            isPlaying = true
            updateNowPlaying()
        } else {
            next(autoAdvance: true)
        }
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
            secondaryPlayer?.pause()
            isPlaying = false
        } else {
            if positionSec >= durationSec - 1.0 && durationSec > 0 {
                seek(to: 0.0)
            }
            p.play()
            if isTransitioning {
                secondaryPlayer?.play()
            }
            isPlaying = true
        }
        updateNowPlaying()
    }

    public func seek(to fraction: Double) {
        cancelCrossmix()
        let clamped = min(max(fraction, 0.0), 1.0)
        let targetSec = durationSec > 0 ? min(clamped * durationSec, max(0, durationSec - 0.1)) : 0
        self.positionSec = targetSec
        self.progress = clamped

        guard let p = player else {
            // Player not yet loaded (e.g. prepared track before play); positionSec & progress remain set
            updateNowPlaying()
            return
        }

        isSeekingInProgress = true
        let cmTime = CMTime(seconds: targetSec, preferredTimescale: 600)
        let tol = CMTime(seconds: 0.15, preferredTimescale: 600)
        p.seek(to: cmTime, toleranceBefore: tol, toleranceAfter: tol) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isSeekingInProgress = false
                self.updateNowPlaying()
            }
        }
        updateNowPlaying()
    }

    public func seekBy(seconds delta: Double) {
        guard durationSec > 0 else { return }
        let nextSec = min(max(positionSec + delta, 0), durationSec)
        seek(to: nextSec / durationSec)
    }

    public func setVolume(_ vol: Float) {
        let clamped = min(max(vol, 0.0), 1.0)
        self.volume = clamped
        player?.volume = clamped
    }

    public func next(autoAdvance: Bool = false) {
        cancelCrossmix()
        guard !queue.isEmpty else { return }
        let nextIdx = currentIndex + 1
        if nextIdx < queue.count {
            currentIndex = nextIdx
            play(song: queue[nextIdx])
        } else if repeatMode == .all {
            currentIndex = 0
            play(song: queue[0])
        } else if isAutoplay, let current = currentTrack {
            Task {
                let radio = await InnerTubeService.shared.fetchRadio(videoId: current.id)
                let newTracks = radio.filter { r in !self.queue.contains(where: { $0.id == r.id }) }
                if !newTracks.isEmpty {
                    self.queue.append(contentsOf: newTracks)
                    self.originalQueue.append(contentsOf: newTracks)
                    self.next(autoAdvance: autoAdvance)
                } else {
                    self.player?.pause()
                    self.isPlaying = false
                    self.seek(to: 0.0)
                }
            }
        } else {
            player?.pause()
            isPlaying = false
            seek(to: 0.0)
        }
    }

    public func previous() {
        cancelCrossmix()
        if positionSec > 3.0 {
            seek(to: 0.0)
            return
        }
        guard !queue.isEmpty else { return }
        let prevIdx = currentIndex - 1
        if prevIdx >= 0 {
            currentIndex = prevIdx
            play(song: queue[prevIdx])
        } else if repeatMode == .all {
            currentIndex = queue.count - 1
            play(song: queue[currentIndex])
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
        if artworkId == track.id, let artwork {
            info[MPMediaItemPropertyArtwork] = artwork
        } else {
            loadArtwork(for: track)
        }

        let center = MPNowPlayingInfoCenter.default()
        center.nowPlayingInfo = info
        center.playbackState = isPlaying ? .playing : .paused
    }

    // ponytail: no disk cache; refetched once per track. Exposes cover to system Now Playing (notch apps, Control Center)
    private func loadArtwork(for track: SongItem) {
        guard artworkId != track.id, let thumb = track.thumbnail, let url = URL(string: thumb) else { return }
        artworkId = track.id
        artwork = nil
        artworkTask?.cancel()
        artworkTask = Task {
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  !Task.isCancelled, let img = NSImage(data: data) else { return }
            let art = MPMediaItemArtwork(boundsSize: img.size) { _ in img }
            self.artwork = art
            guard self.currentTrack?.id == track.id else { return }
            var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
            info[MPMediaItemPropertyArtwork] = art
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        }
    }
}

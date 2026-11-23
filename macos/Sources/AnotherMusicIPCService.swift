import Foundation
import AppKit
import Combine

/// Native macOS IPC Service facilitating two-way communication between anotherMusic
/// and other apps in the family (such as anotherNotch) via DistributedNotificationCenter.
@MainActor
public final class AnotherMusicIPCService: NSObject {
    public static let shared = AnotherMusicIPCService()

    public static let commandNotification = Notification.Name("com.jinkun1998.anothermusic.command")
    public static let stateNotification = Notification.Name("com.jinkun1998.anothermusic.playbackState")
    public static let bundleIdentifier = "com.jinkun1998.anothermusic"

    private var isStarted = false
    private var lastBroadcastTime: Date = .distantPast
    private var cancellables = Set<AnyCancellable>()

    public override init() {
        super.init()
    }

    /// Starts the IPC listener on the default DistributedNotificationCenter.
    public func start() {
        guard !isStarted else { return }
        isStarted = true

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleRemoteCommand(_:)),
            name: Self.commandNotification,
            object: nil,
            suspensionBehavior: .deliverImmediately
        )

        // Observe player changes
        let player = AudioPlayerService.shared
        player.$currentTrack
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.broadcastState() }
            .store(in: &cancellables)

        player.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.broadcastState() }
            .store(in: &cancellables)

        // Broadcast initial state
        broadcastState()
    }

    /// Stops listening to distributed notifications.
    public func stop() {
        DistributedNotificationCenter.default().removeObserver(self)
        cancellables.removeAll()
        isStarted = false
    }

    // MARK: - Remote Command Handler
    @objc private func handleRemoteCommand(_ notification: Notification) {
        guard let userInfo = notification.userInfo as? [String: Any],
              let action = userInfo["action"] as? String else {
            return
        }

        let player = AudioPlayerService.shared
        let library = LibraryStore.shared

        switch action {
        case "play":
            player.resume()
        case "pause":
            player.pause()
        case "togglePlay", "toggle":
            player.togglePlayPause()
        case "next":
            player.next()
        case "previous", "prev":
            player.previous()
        case "seek":
            if let fraction = userInfo["fraction"] as? Double {
                player.seek(to: fraction)
            } else if let pos = userInfo["position"] as? Double, player.durationSec > 0 {
                player.seek(to: pos / player.durationSec)
            }
        case "setVolume":
            if let vol = userInfo["volume"] as? Double {
                player.volume = Float(max(0.0, min(1.0, vol)))
            }
        case "toggleLike", "favorite":
            if let track = player.currentTrack {
                library.toggleLike(track)
                AppHaptics.alignment()
                broadcastState()
            }
        case "setFavorite":
            if let track = player.currentTrack, let fav = userInfo["favorite"] as? Bool {
                let currentFav = library.isLiked(track)
                if currentFav != fav {
                    library.toggleLike(track)
                    broadcastState()
                }
            }
        case "setTransitionMode":
            if let modeStr = userInfo["mode"] as? String {
                switch modeStr.lowercased() {
                case "automix", "auto mix":
                    player.transitionMode = .automix
                case "crossfade", "cross fade":
                    player.transitionMode = .crossfade
                case "off":
                    player.transitionMode = .off
                default:
                    break
                }
                broadcastState()
            }
        case "cycleTransitionMode":
            switch player.transitionMode {
            case .automix:
                player.transitionMode = .crossfade
            case .crossfade:
                player.transitionMode = .off
            case .off:
                player.transitionMode = .automix
            }
            broadcastState()
        case "toggleShuffle":
            player.toggleShuffle()
            broadcastState()
        case "toggleRepeat":
            switch player.repeatMode {
            case .off: player.repeatMode = .all
            case .all: player.repeatMode = .one
            case .one: player.repeatMode = .off
            }
            broadcastState()
        case "requestState":
            broadcastState()
        default:
            break
        }
    }

    // MARK: - State Broadcast
    public func broadcastState() {
        let player = AudioPlayerService.shared
        let library = LibraryStore.shared
        let track = player.currentTrack

        var payload: [String: Any] = [
            "bundleIdentifier": Self.bundleIdentifier,
            "isPlaying": player.isPlaying,
            "title": track?.title ?? "",
            "artist": track?.artist ?? "",
            "album": track?.album ?? "",
            "trackId": track?.id ?? "",
            "currentTime": player.positionSec,
            "duration": player.durationSec,
            "playbackRate": player.isPlaying ? 1.0 : 0.0,
            "volume": Double(player.volume),
            "isFavorite": track != nil ? library.isLiked(track!) : false,
            "isShuffled": player.isShuffle,
            "repeatMode": player.repeatMode == .off ? 1 : (player.repeatMode == .one ? 2 : 3),
            "transitionMode": player.transitionMode.rawValue
        ]

        if let thumb = track?.thumbnail {
            payload["artworkUrl"] = thumb
        }

        DistributedNotificationCenter.default().postNotificationName(
            Self.stateNotification,
            object: nil,
            userInfo: payload,
            deliverImmediately: true
        )
    }

    // MARK: - URL Handler (anothermusic://)
    public func handleURL(_ url: URL) {
        guard url.scheme?.lowercased() == "anothermusic" else { return }

        let host = url.host?.lowercased() ?? ""
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        let command = !host.isEmpty ? host : path

        let player = AudioPlayerService.shared
        let library = LibraryStore.shared

        switch command {
        case "play":
            player.resume()
        case "pause":
            player.pause()
        case "toggle", "toggleplay":
            player.togglePlayPause()
        case "next":
            player.next()
        case "prev", "previous":
            player.previous()
        case "like", "favorite":
            if let track = player.currentTrack {
                library.toggleLike(track)
                broadcastState()
            }
        case "automix":
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let mode = components.queryItems?.first(where: { $0.name == "mode" })?.value {
                switch mode.lowercased() {
                case "automix": player.transitionMode = .automix
                case "crossfade": player.transitionMode = .crossfade
                case "off": player.transitionMode = .off
                default: break
                }
            } else {
                player.transitionMode = .automix
            }
            broadcastState()
        default:
            break
        }
    }
}

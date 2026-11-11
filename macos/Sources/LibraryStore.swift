import Foundation
import Combine
import AppKit

@MainActor
public final class LibraryStore: ObservableObject {
    public static let shared = LibraryStore()

    @Published public private(set) var likedSongs: [SongItem] = []
    @Published public private(set) var history: [SongItem] = []
    @Published public var username: String = "User"
    @Published public var userTag: String = "8402"
    @Published public var profilePicPath: String? = nil
    @Published public private(set) var totalPlayTimeSec: Int = 0
    @Published public var isSyncEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isSyncEnabled, forKey: "iCloudSyncEnabled")
            if isSyncEnabled { save() }
        }
    }
    @Published public private(set) var isICloudSyncing: Bool = false
    @Published public private(set) var lastSyncDate: Date? = nil

    private let localURL: URL
    private let iCloudURL: URL?
    private var fileWatcher: DispatchSourceFileSystemObject?

    private struct Snapshot: Codable {
        var username: String?
        var userTag: String?
        var profilePicPath: String?
        var totalPlayTimeSec: Int?
        var likedSongs: [SongItem]
        var history: [SongItem]
    }

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        let localDir = appSupport.appendingPathComponent("anotherMusic", isDirectory: true)
        try? FileManager.default.createDirectory(at: localDir, withIntermediateDirectories: true)
        self.localURL = localDir.appendingPathComponent("library.json")

        // iCloud Drive container folder: ~/Library/Mobile Documents/com~apple~CloudDocs/anotherMusic
        let cloudDocs = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
        if FileManager.default.fileExists(atPath: cloudDocs.path) {
            let cloudDir = cloudDocs.appendingPathComponent("anotherMusic", isDirectory: true)
            try? FileManager.default.createDirectory(at: cloudDir, withIntermediateDirectories: true)
            self.iCloudURL = cloudDir.appendingPathComponent("library.json")
            self.isICloudSyncing = true
        } else {
            self.iCloudURL = nil
            self.isICloudSyncing = false
        }

        self.isSyncEnabled = UserDefaults.standard.object(forKey: "iCloudSyncEnabled") as? Bool ?? true

        let defaultName = NSFullUserName().isEmpty ? NSUserName() : NSFullUserName()
        self.username = defaultName.isEmpty ? "User" : defaultName
        self.userTag = String(format: "%04d", abs(self.username.hashValue % 9000) + 1000)

        load()
        setupWatcher()
    }

    public func isLiked(_ song: SongItem) -> Bool {
        likedSongs.contains(where: { $0.id == song.id })
    }

    public func toggleLike(_ song: SongItem) {
        if let idx = likedSongs.firstIndex(where: { $0.id == song.id }) {
            likedSongs.remove(at: idx)
        } else {
            likedSongs.insert(song, at: 0)
        }
        save()
    }

    public func clearHistory() {
        history.removeAll()
        totalPlayTimeSec = 0
        save()
    }

    public func recordPlay(_ song: SongItem) {
        guard song.kind == .song else { return }
        history.removeAll(where: { $0.id == song.id })
        history.insert(song, at: 0)
        if history.count > 150 {
            history.removeLast(history.count - 150)
        }
        totalPlayTimeSec += song.duration ?? 180
        save()
    }

    public func updateProfile(name: String, photoData: Data?) {
        self.username = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? self.username : name
        self.userTag = String(format: "%04d", abs(self.username.hashValue % 9000) + 1000)

        if let photoData {
            let targetDir = iCloudURL?.deletingLastPathComponent() ?? localURL.deletingLastPathComponent()
            let avatarURL = targetDir.appendingPathComponent("profile_avatar.jpg")
            try? photoData.write(to: avatarURL, options: .atomic)
            self.profilePicPath = avatarURL.path
        }
        save()
    }

    public var topArtists: [(artist: String, count: Int)] {
        var counts: [String: Int] = [:]
        for item in history where item.kind == .song && !item.artist.isEmpty {
            counts[item.artist, default: 0] += 1
        }
        for item in likedSongs where !item.artist.isEmpty {
            counts[item.artist, default: 0] += 2
        }
        return counts.sorted { $0.value > $1.value }.prefix(10).map { (artist: $0.key, count: $0.value) }
    }

    public func revealInFinder() {
        let url = (isICloudSyncing && iCloudURL != nil) ? iCloudURL! : localURL
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func load() {
        // Read from iCloud if newer or present, otherwise local
        var activeData: Data? = nil
        if isSyncEnabled, let iCloudURL, FileManager.default.fileExists(atPath: iCloudURL.path) {
            activeData = try? Data(contentsOf: iCloudURL)
        }
        if activeData == nil, FileManager.default.fileExists(atPath: localURL.path) {
            activeData = try? Data(contentsOf: localURL)
        }

        guard let activeData, let snap = try? JSONDecoder().decode(Snapshot.self, from: activeData) else {
            return
        }

        if let u = snap.username, !u.isEmpty { self.username = u }
        if let t = snap.userTag, !t.isEmpty { self.userTag = t }
        if let p = snap.profilePicPath, FileManager.default.fileExists(atPath: p) { self.profilePicPath = p }
        if let sec = snap.totalPlayTimeSec { self.totalPlayTimeSec = sec }
        self.likedSongs = snap.likedSongs
        self.history = snap.history
        self.lastSyncDate = Date()
    }

    private func save() {
        let snap = Snapshot(
            username: username,
            userTag: userTag,
            profilePicPath: profilePicPath,
            totalPlayTimeSec: totalPlayTimeSec,
            likedSongs: likedSongs,
            history: history
        )
        guard let data = try? JSONEncoder().encode(snap) else { return }

        // Write local backup
        try? data.write(to: localURL, options: .atomic)

        // Write iCloud Drive sync copy
        if isSyncEnabled, let iCloudURL {
            try? data.write(to: iCloudURL, options: .atomic)
            self.lastSyncDate = Date()
        }
    }

    private func setupWatcher() {
        guard let target = iCloudURL else { return }
        let fd = open(target.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename], queue: .main)
        source.setEventHandler { [weak self] in
            self?.load()
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        self.fileWatcher = source
    }
}

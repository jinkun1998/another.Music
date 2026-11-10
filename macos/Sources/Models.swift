import Foundation

public struct SongItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let artist: String
    public let album: String?
    public let duration: Int?
    public let thumbnail: String?

    public init(id: String, title: String, artist: String, album: String? = nil, duration: Int? = nil, thumbnail: String? = nil) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.thumbnail = thumbnail
    }
}

public struct HomeSection: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let label: String?
    public let items: [SongItem]

    public init(id: String = UUID().uuidString, title: String, label: String? = nil, items: [SongItem]) {
        self.id = id
        self.title = title
        self.label = label
        self.items = items
    }
}

public struct LyricLine: Identifiable, Equatable, Sendable {
    public var id: Int64 { timeMs }
    public let timeMs: Int64
    public let text: String

    public init(timeMs: Int64, text: String) {
        self.timeMs = timeMs
        self.text = text
    }
}

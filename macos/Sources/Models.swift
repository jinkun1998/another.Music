import Foundation

public enum MediaItemKind: String, Codable, Sendable {
    case song
    case album
    case playlist
}

public struct SongItem: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let title: String
    public let artist: String
    public let album: String?
    public let duration: Int?
    public let thumbnail: String?
    public let kind: MediaItemKind
    public let browseId: String?

    public init(
        id: String,
        title: String,
        artist: String,
        album: String? = nil,
        duration: Int? = nil,
        thumbnail: String? = nil,
        kind: MediaItemKind = .song,
        browseId: String? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.thumbnail = thumbnail
        self.kind = kind
        self.browseId = browseId
    }
}

public struct HomeSection: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let label: String?
    public let items: [SongItem]
    public let isTrackGrid: Bool

    public init(id: String = UUID().uuidString, title: String, label: String? = nil, items: [SongItem], isTrackGrid: Bool = false) {
        self.id = id
        self.title = title
        self.label = label
        self.items = items
        self.isTrackGrid = isTrackGrid
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

// ponytail: four time buckets cover standard day periods; add user name suffix when profile name setting exists
public func timeGreeting(hour: Int = Calendar.current.component(.hour, from: Date())) -> String {
    switch hour {
    case 5..<12: return "Good morning"
    case 12..<17: return "Good afternoon"
    case 17..<22: return "Good evening"
    default: return "Good night"
    }
}

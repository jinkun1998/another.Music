import Foundation

public final class LyricsService: Sendable {
    public static let shared = LyricsService()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        self.session = URLSession(configuration: config)
    }

    private let titleCleanRegex = try? NSRegularExpression(
        pattern: #"\s*(\(|\[).*?(official|video|audio|lyrics|lyric|visualizer|hd|hq|4k|remaster|remix|mv).*?(\)|\])"#,
        options: .caseInsensitive
    )

    private func cleanTitle(_ title: String) -> String {
        guard let titleCleanRegex else { return title }
        let range = NSRange(location: 0, length: title.utf16.count)
        return titleCleanRegex.stringByReplacingMatches(in: title, range: range, withTemplate: "").trimmingCharacters(in: .whitespaces)
    }

    private func cleanArtist(_ artist: String) -> String {
        let separators = [" & ", " and ", ", ", " x ", " feat. ", " ft. "]
        var res = artist
        for sep in separators {
            if let first = res.components(separatedBy: sep).first {
                res = first
            }
        }
        return res.trimmingCharacters(in: .whitespaces)
    }

    public func fetchLyrics(title: String, artist: String, durationSec: Int = 0) async -> [LyricLine] {
        let cTitle = cleanTitle(title)
        let cArtist = cleanArtist(artist)

        if let exact = await tryGetLyrics(title: cTitle, artist: cArtist, durationSec: durationSec), !exact.isEmpty {
            return exact
        }

        if let searched = await trySearchLyrics(query: "\(cArtist) \(cTitle)"), !searched.isEmpty {
            return searched
        }

        if let searchedTitle = await trySearchLyrics(query: cTitle), !searchedTitle.isEmpty {
            return searchedTitle
        }

        return []
    }

    private func tryGetLyrics(title: String, artist: String, durationSec: Int) async -> [LyricLine]? {
        var comp = URLComponents(string: "https://lrclib.net/api/get")
        var qItems = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist)
        ]
        if durationSec > 0 {
            qItems.append(URLQueryItem(name: "duration", value: String(durationSec)))
        }
        comp?.queryItems = qItems

        guard let url = comp?.url else { return nil }
        var req = URLRequest(url: url)
        req.setValue("anotherMusic macOS (https://github.com)", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await session.data(for: req),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let lrc = (json["syncedLyrics"] as? String) ?? (json["plainLyrics"] as? String) ?? ""
        return parseLrc(lrc)
    }

    private func trySearchLyrics(query: String) async -> [LyricLine]? {
        var comp = URLComponents(string: "https://lrclib.net/api/search")
        comp?.queryItems = [URLQueryItem(name: "q", value: query)]

        guard let url = comp?.url else { return nil }
        var req = URLRequest(url: url)
        req.setValue("anotherMusic macOS (https://github.com)", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await session.data(for: req),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let first = array.first(where: { ($0["syncedLyrics"] as? String)?.isEmpty == false }) ?? array.first else {
            return nil
        }

        let lrc = (first["syncedLyrics"] as? String) ?? (first["plainLyrics"] as? String) ?? ""
        return parseLrc(lrc)
    }

    public func parseLrc(_ lrc: String) -> [LyricLine] {
        guard !lrc.isEmpty else { return [] }
        var lines: [LyricLine] = []
        let regex = try? NSRegularExpression(pattern: #"^\[(\d{2}):(\d{2})\.?(\d{2,3})?\](.*)$"#)
        let wordTagRegex = try? NSRegularExpression(pattern: #"<[^>]+>"#)

        for rawLine in lrc.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let range = NSRange(location: 0, length: trimmed.utf16.count)
            if let match = regex?.firstMatch(in: trimmed, range: range) {
                let minRange = match.range(at: 1)
                let secRange = match.range(at: 2)
                let fracRange = match.range(at: 3)
                let textRange = match.range(at: 4)

                let minStr = (trimmed as NSString).substring(with: minRange)
                let secStr = (trimmed as NSString).substring(with: secRange)
                var fracStr = fracRange.location != NSNotFound ? (trimmed as NSString).substring(with: fracRange) : "0"
                let rawText = textRange.location != NSNotFound ? (trimmed as NSString).substring(with: textRange) : ""

                let min = Int64(minStr) ?? 0
                let sec = Int64(secStr) ?? 0
                if fracStr.count == 2 { fracStr += "0" }
                let frac = Int64(fracStr) ?? 0

                let timeMs = (min * 60 + sec) * 1000 + frac
                let cleanText: String
                if let wordTagRegex {
                    let wRange = NSRange(location: 0, length: rawText.utf16.count)
                    cleanText = wordTagRegex.stringByReplacingMatches(in: rawText, range: wRange, withTemplate: "").trimmingCharacters(in: .whitespaces)
                } else {
                    cleanText = rawText.trimmingCharacters(in: .whitespaces)
                }

                if !cleanText.isEmpty {
                    lines.append(LyricLine(timeMs: timeMs, text: cleanText))
                }
            }
        }

        return lines.sorted(by: { $0.timeMs < $1.timeMs })
    }
}

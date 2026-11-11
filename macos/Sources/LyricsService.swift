import Foundation

public final class LyricsService: Sendable {
    public static let shared = LyricsService()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        self.session = URLSession(configuration: config)
    }

    private let cleanupPatterns: [NSRegularExpression] = [
        #"\s*(\(|\[).*?(official|video|audio|lyrics|lyric|visualizer|hd|hq|4k|remaster|remix|mv|live|acoustic|version|edit|extended|radio|clean|explicit|prod\.|feat\.|ft\.).*?(\)|\])"#,
        #"\s*【.*?】"#,
        #"\s*\|.*$"#,
        #"\s*-\s*(official|video|audio|lyrics|lyric|visualizer|mv).*$"#,
        #"\s*(feat\.|ft\.|featuring)\s+.*$"#
    ].compactMap { try? NSRegularExpression(pattern: $0, options: .caseInsensitive) }

    private func cleanTitle(_ title: String) -> String {
        var res = title.trimmingCharacters(in: .whitespacesAndNewlines)
        for regex in cleanupPatterns {
            let range = NSRange(location: 0, length: res.utf16.count)
            res = regex.stringByReplacingMatches(in: res, range: range, withTemplate: "")
        }
        return res.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func cleanArtist(_ artist: String) -> String {
        var res = artist
            .replacingOccurrences(of: " - Topic", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "VEVO", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let separators = [" & ", " and ", ", ", " x ", " X ", " feat. ", " ft. ", " featuring ", " with ", " • "]
        for sep in separators {
            if let range = res.range(of: sep, options: .caseInsensitive) {
                res = String(res[..<range.lowerBound])
                break
            }
        }
        return res.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // ponytail: cascades SimpMusic(videoId) -> LRCLIB -> YouTube Captions(json3) -> YouTube Music(MPLYt) matching Android LyricsHelper
    public func fetchLyrics(videoId: String = "", title: String, artist: String, durationSec: Int = 0) async -> [LyricLine] {
        let cTitle = cleanTitle(title)
        let cArtist = cleanArtist(artist)

        // 1. SimpMusic by YouTube videoId (synced LRC)
        if !videoId.isEmpty, let simp = await trySimpMusic(videoId: videoId, durationSec: durationSec), !simp.isEmpty {
            return simp
        }

        // 2. LRCLIB exact + search cascade
        var plainFallback: [LyricLine]? = nil
        var candidatePairs: [(String, String)] = [(cTitle, cArtist)]
        if cTitle.contains(" - ") {
            let parts = cTitle.components(separatedBy: " - ").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            if parts.count >= 2 {
                candidatePairs.append((parts[1], parts[0]))
                candidatePairs.append((parts[0], parts[1]))
            }
        }

        for (t, a) in candidatePairs {
            if let exact = await tryGetLrcLib(title: t, artist: a, durationSec: durationSec) {
                if exact.isSynced { return exact.lines }
                if plainFallback == nil { plainFallback = exact.lines }
            }
            if let searched = await trySearchLrcLib(trackName: t, artistName: a, query: nil, durationSec: durationSec) {
                if searched.isSynced { return searched.lines }
                if plainFallback == nil { plainFallback = searched.lines }
            }
            if let searchedQ = await trySearchLrcLib(trackName: nil, artistName: nil, query: "\(a) \(t)", durationSec: durationSec) {
                if searchedQ.isSynced { return searchedQ.lines }
                if plainFallback == nil { plainFallback = searchedQ.lines }
            }
            if let searchedTitle = await trySearchLrcLib(trackName: nil, artistName: nil, query: t, durationSec: durationSec) {
                if searchedTitle.isSynced { return searchedTitle.lines }
                if plainFallback == nil { plainFallback = searchedTitle.lines }
            }
        }

        // 3. YouTube Captions (timed json3 track from InnerTube player)
        if !videoId.isEmpty, let ytCaptions = await tryYouTubeCaptions(videoId: videoId), !ytCaptions.isEmpty {
            return ytCaptions
        }

        // 4. YouTube Music InnerTube lyrics tab (MPLYt_...)
        if !videoId.isEmpty, let ytPlain = await tryYouTubeMusicLyrics(videoId: videoId), !ytPlain.isEmpty {
            return ytPlain
        }

        return plainFallback ?? []
    }

    private func trySimpMusic(videoId: String, durationSec: Int) async -> [LyricLine]? {
        guard let url = URL(string: "https://api-lyrics.simpmusic.org/v1/\(videoId)") else { return nil }
        var req = URLRequest(url: url)
        req.setValue("SimpMusicLyrics/1.0", forHTTPHeaderField: "User-Agent")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        guard let (data, resp) = try? await session.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (json["success"] as? Bool) == true,
              let list = json["data"] as? [[String: Any]], !list.isEmpty else {
            return nil
        }

        let best = list.first(where: { ($0["syncedLyrics"] as? String)?.isEmpty == false }) ?? list.first
        guard let best else { return nil }
        let lrc = (best["syncedLyrics"] as? String) ?? (best["plainLyrics"] as? String) ?? ""
        let parsed = parseLrc(lrc)
        return parsed.isEmpty ? nil : parsed
    }

    private func tryGetLrcLib(title: String, artist: String, durationSec: Int) async -> (lines: [LyricLine], isSynced: Bool)? {
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
        req.setValue("Mochy (+https://github.com/realidkroo/Mochy-Music)", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await session.data(for: req),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let synced = json["syncedLyrics"] as? String, !synced.isEmpty {
            let lines = parseLrc(synced)
            if !lines.isEmpty { return (lines, true) }
        }
        if let plain = json["plainLyrics"] as? String, !plain.isEmpty {
            let lines = parseLrc(plain)
            if !lines.isEmpty { return (lines, false) }
        }
        return nil
    }

    private func trySearchLrcLib(trackName: String?, artistName: String?, query: String?, durationSec: Int) async -> (lines: [LyricLine], isSynced: Bool)? {
        var comp = URLComponents(string: "https://lrclib.net/api/search")
        var items: [URLQueryItem] = []
        if let q = query, !q.isEmpty { items.append(URLQueryItem(name: "q", value: q)) }
        if let t = trackName, !t.isEmpty { items.append(URLQueryItem(name: "track_name", value: t)) }
        if let a = artistName, !a.isEmpty && a.lowercased() != "youtube music" { items.append(URLQueryItem(name: "artist_name", value: a)) }
        comp?.queryItems = items

        guard let url = comp?.url else { return nil }
        var req = URLRequest(url: url)
        req.setValue("Mochy (+https://github.com/realidkroo/Mochy-Music)", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await session.data(for: req),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              !array.isEmpty else {
            return nil
        }

        let sorted: [[String: Any]]
        if durationSec > 0 {
            sorted = array.sorted {
                let d1 = ($0["duration"] as? Double).map(Int.init) ?? ($0["duration"] as? Int) ?? 9999
                let d2 = ($1["duration"] as? Double).map(Int.init) ?? ($1["duration"] as? Int) ?? 9999
                return abs(d1 - durationSec) < abs(d2 - durationSec)
            }
        } else {
            sorted = array
        }

        if let syncedMatch = sorted.first(where: { ($0["syncedLyrics"] as? String)?.isEmpty == false }),
           let synced = syncedMatch["syncedLyrics"] as? String {
            let lines = parseLrc(synced)
            if !lines.isEmpty { return (lines, true) }
        }

        if let plainMatch = sorted.first(where: { ($0["plainLyrics"] as? String)?.isEmpty == false }),
           let plain = plainMatch["plainLyrics"] as? String {
            let lines = parseLrc(plain)
            if !lines.isEmpty { return (lines, false) }
        }
        return nil
    }

    private func tryYouTubeCaptions(videoId: String) async -> [LyricLine]? {
        guard let url = URL(string: "https://music.youtube.com/youtubei/v1/player") else { return nil }
        let visitor = await InnerTubeService.shared.ensureVisitorData()

        var clientCtx: [String: Any] = [
            "clientName": "IOS",
            "clientVersion": "20.10.4",
            "osName": "iOS",
            "osVersion": "18.3.2.22D82",
            "deviceMake": "Apple",
            "deviceModel": "iPhone16,2",
            "hl": "en",
            "gl": "US"
        ]
        if let visitor { clientCtx["visitorData"] = visitor }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)", forHTTPHeaderField: "User-Agent")
        if let visitor { req.setValue(visitor, forHTTPHeaderField: "X-Goog-Visitor-Id") }
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["context": ["client": clientCtx], "videoId": videoId])

        guard let (data, resp) = try? await session.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let captions = (json["captions"] as? [String: Any])?["playerCaptionsTracklistRenderer"] as? [String: Any],
              let tracks = captions["captionTracks"] as? [[String: Any]],
              !tracks.isEmpty else {
            return nil
        }

        let uploaded = tracks.first(where: { ($0["kind"] as? String) != "asr" }) ?? tracks.first
        guard let baseUrl = uploaded?["baseUrl"] as? String,
              let capUrl = URL(string: baseUrl + "&fmt=json3") else {
            return nil
        }

        var capReq = URLRequest(url: capUrl)
        capReq.setValue("com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)", forHTTPHeaderField: "User-Agent")
        guard let (capData, capResp) = try? await session.data(for: capReq),
              (capResp as? HTTPURLResponse)?.statusCode == 200,
              let capJson = try? JSONSerialization.jsonObject(with: capData) as? [String: Any],
              let events = capJson["events"] as? [[String: Any]] else {
            return nil
        }

        var lines: [LyricLine] = []
        var prevText = ""
        let bracketRegex = try? NSRegularExpression(pattern: #"\[[^\]]*\]"#)

        for ev in events {
            guard let startMs = (ev["tStartMs"] as? Int64) ?? (ev["tStartMs"] as? Int).map(Int64.init),
                  let segs = ev["segs"] as? [[String: Any]] else { continue }
            var text = segs.compactMap { $0["utf8"] as? String }.joined()
            if let bracketRegex {
                let r = NSRange(location: 0, length: text.utf16.count)
                text = bracketRegex.stringByReplacingMatches(in: text, range: r, withTemplate: " ")
            }
            text = text
                .replacingOccurrences(of: "♪", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
                .joined(separator: " ")

            guard !text.isEmpty && text != prevText else { continue }
            prevText = text
            lines.append(LyricLine(timeMs: startMs, text: text))
        }
        return lines.count >= 3 ? lines : nil
    }

    private func tryYouTubeMusicLyrics(videoId: String) async -> [LyricLine]? {
        guard let nextUrl = URL(string: "https://music.youtube.com/youtubei/v1/next"),
              let browseUrl = URL(string: "https://music.youtube.com/youtubei/v1/browse") else { return nil }
        let visitor = await InnerTubeService.shared.ensureVisitorData()

        var clientDict: [String: Any] = [
            "clientName": "WEB_REMIX",
            "clientVersion": "1.20260707.12.00",
            "hl": "en",
            "gl": "US"
        ]
        if let visitor { clientDict["visitorData"] = visitor }

        var nextReq = URLRequest(url: nextUrl)
        nextReq.httpMethod = "POST"
        nextReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        nextReq.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) Gecko/20100101 Firefox/140.0", forHTTPHeaderField: "User-Agent")
        if let visitor { nextReq.setValue(visitor, forHTTPHeaderField: "X-Goog-Visitor-Id") }
        nextReq.httpBody = try? JSONSerialization.data(withJSONObject: [
            "context": ["client": clientDict],
            "videoId": videoId
        ])

        guard let (nData, nResp) = try? await session.data(for: nextReq),
              (nResp as? HTTPURLResponse)?.statusCode == 200,
              let nJson = try? JSONSerialization.jsonObject(with: nData) as? [String: Any],
              let contents = nJson["contents"] as? [String: Any],
              let single = contents["singleColumnMusicWatchNextResultsRenderer"] as? [String: Any],
              let tabbed = (single["tabbedRenderer"] as? [String: Any])?["watchNextTabbedResultsRenderer"] as? [String: Any],
              let tabs = tabbed["tabs"] as? [[String: Any]],
              tabs.count > 1,
              let tabRenderer = tabs[1]["tabRenderer"] as? [String: Any],
              let browseEndpoint = (tabRenderer["endpoint"] as? [String: Any])?["browseEndpoint"] as? [String: Any],
              let browseId = browseEndpoint["browseId"] as? String else {
            return nil
        }

        var bReq = URLRequest(url: browseUrl)
        bReq.httpMethod = "POST"
        bReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        bReq.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) Gecko/20100101 Firefox/140.0", forHTTPHeaderField: "User-Agent")
        if let visitor { bReq.setValue(visitor, forHTTPHeaderField: "X-Goog-Visitor-Id") }
        bReq.httpBody = try? JSONSerialization.data(withJSONObject: [
            "context": ["client": clientDict],
            "browseId": browseId
        ])

        guard let (bData, bResp) = try? await session.data(for: bReq),
              (bResp as? HTTPURLResponse)?.statusCode == 200,
              let bJson = try? JSONSerialization.jsonObject(with: bData) as? [String: Any],
              let bContents = (bJson["contents"] as? [String: Any])?["sectionListRenderer"] as? [String: Any],
              let secList = bContents["contents"] as? [[String: Any]] else {
            return nil
        }

        for sec in secList {
            if let descShelf = sec["musicDescriptionShelfRenderer"] as? [String: Any],
               let runs = (descShelf["description"] as? [String: Any])?["runs"] as? [[String: Any]] {
                let raw = runs.compactMap { $0["text"] as? String }.joined()
                let parsed = parseLrc(raw)
                if !parsed.isEmpty { return parsed }
            }
        }
        return nil
    }

    public func parseLrc(_ lrc: String) -> [LyricLine] {
        guard !lrc.isEmpty else { return [] }
        var lines: [LyricLine] = []
        let regex = try? NSRegularExpression(pattern: #"^\[(\d{1,2}):(\d{2})(?:[\.:](\d{1,3}))?\](.*)$"#)
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
                if fracStr.count == 1 { fracStr += "00" }
                else if fracStr.count == 2 { fracStr += "0" }
                let frac = Int64(fracStr.prefix(3)) ?? 0

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

        if !lines.isEmpty {
            return lines.sorted(by: { $0.timeMs < $1.timeMs })
        }

        // Plain lyrics fallback when no [mm:ss] timestamps exist
        var plainLines: [LyricLine] = []
        for (idx, rawLine) in lrc.components(separatedBy: .newlines).enumerated() {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && !trimmed.hasPrefix("[") {
                plainLines.append(LyricLine(timeMs: Int64(idx) * 4000, text: trimmed))
            }
        }
        return plainLines
    }
}

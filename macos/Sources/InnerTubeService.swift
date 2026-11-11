import Foundation

private actor VisitorStore {
    private var token: String?
    func get() -> String? { token }
    func set(_ val: String) { token = val }
}

public final class InnerTubeService: Sendable {
    public static let shared = InnerTubeService()

    private let session: URLSession
    private let visitorStore = VisitorStore()

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    // ponytail: fetches sw.js_data visitor token once per session matching Android YouTube.visitorData()
    public func ensureVisitorData() async -> String? {
        if let existing = await visitorStore.get() { return existing }
        guard let url = URL(string: "https://music.youtube.com/sw.js_data") else { return nil }
        var req = URLRequest(url: url)
        req.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) Gecko/20100101 Firefox/140.0", forHTTPHeaderField: "User-Agent")
        guard let (data, _) = try? await session.data(for: req),
              let str = String(data: data, encoding: .utf8),
              let regex = try? NSRegularExpression(pattern: "\"(Cg[ts][a-zA-Z0-9_%-]+)\""),
              let match = regex.firstMatch(in: str, range: NSRange(str.startIndex..., in: str)),
              let range = Range(match.range(at: 1), in: str) else {
            return nil
        }
        let token = String(str[range])
        await visitorStore.set(token)
        return token
    }

    private func makeWebRemixRequest(endpoint: String, body: [String: Any], visitorData: String? = nil) -> URLRequest? {
        guard let url = URL(string: "https://music.youtube.com/youtubei/v1/\(endpoint)") else { return nil }
        var fullBody = body
        var clientDict: [String: Any] = [
            "clientName": "WEB_REMIX",
            "clientVersion": "1.20260707.12.00",
            "hl": "en",
            "gl": "US"
        ]
        if let visitorData { clientDict["visitorData"] = visitorData }
        fullBody["context"] = ["client": clientDict]
        guard let httpBody = try? JSONSerialization.data(withJSONObject: fullBody) else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) Gecko/20100101 Firefox/140.0", forHTTPHeaderField: "User-Agent")
        request.setValue("67", forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue("1.20260707.12.00", forHTTPHeaderField: "X-YouTube-Client-Version")
        if let visitorData {
            request.setValue(visitorData, forHTTPHeaderField: "X-Goog-Visitor-Id")
        }
        request.httpBody = httpBody
        return request
    }

    private func parseCarouselShelves(_ sectionContents: [[String: Any]]) -> [HomeSection] {
        var result: [HomeSection] = []
        for sec in sectionContents {
            guard let shelf = sec["musicCarouselShelfRenderer"] as? [String: Any] else { continue }
            let header = shelf["header"] as? [String: Any]
            let basicHeader = header?["musicCarouselShelfBasicHeaderRenderer"] as? [String: Any]
            let titleRuns = (basicHeader?["title"] as? [String: Any])?["runs"] as? [[String: Any]]
            let sectionTitle = titleRuns?.first?["text"] as? String ?? "Featured"
            if sectionTitle.lowercased().contains("shorts") { continue }
            let straplineRuns = (basicHeader?["strapline"] as? [String: Any])?["runs"] as? [[String: Any]]
            let sectionLabel = straplineRuns?.first?["text"] as? String

            var items: [SongItem] = []
            var responsiveCount = 0
            let shelfItems = shelf["contents"] as? [[String: Any]] ?? []

            for c in shelfItems {
                if let item = c["musicResponsiveListItemRenderer"] as? [String: Any],
                   let song = parseResponsiveItem(item) {
                    items.append(song)
                    responsiveCount += 1
                } else if let twoRow = c["musicTwoRowItemRenderer"] as? [String: Any],
                          let song = parseTwoRowItem(twoRow) {
                    items.append(song)
                }
            }

            if !items.isEmpty {
                let isGrid = responsiveCount > items.count / 2 && items.count >= 4
                result.append(HomeSection(title: sectionTitle, label: sectionLabel, items: items, isTrackGrid: isGrid))
            }
        }
        return result
    }

    public func fetchHome(history: [SongItem] = [], liked: [SongItem] = []) async -> [HomeSection] {
        let visitor = await ensureVisitorData()

        async let ytHomeTask: [HomeSection] = {
            guard let request = self.makeWebRemixRequest(endpoint: "browse", body: ["browseId": "FEmusic_home"], visitorData: visitor),
                  let (data, response) = try? await self.session.data(for: request),
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let contents = json["contents"] as? [String: Any],
                  let single = contents["singleColumnBrowseResultsRenderer"] as? [String: Any],
                  let tabs = single["tabs"] as? [[String: Any]],
                  let firstTab = tabs.first?["tabRenderer"] as? [String: Any],
                  let tabContent = firstTab["content"] as? [String: Any],
                  let sectionList = tabContent["sectionListRenderer"] as? [String: Any],
                  let sectionContents = sectionList["contents"] as? [[String: Any]] else {
                return []
            }

            var sections = self.parseCarouselShelves(sectionContents)
            var contToken = ((sectionList["continuations"] as? [[String: Any]])?.first?["nextContinuationData"] as? [String: Any])?["continuation"] as? String

            for _ in 0..<2 {
                guard let token = contToken,
                      let cReq = self.makeWebRemixRequest(endpoint: "browse", body: ["continuation": token], visitorData: visitor),
                      let (cData, cResp) = try? await self.session.data(for: cReq),
                      (cResp as? HTTPURLResponse)?.statusCode == 200,
                      let cJson = try? JSONSerialization.jsonObject(with: cData) as? [String: Any],
                      let slCont = (cJson["continuationContents"] as? [String: Any])?["sectionListContinuation"] as? [String: Any],
                      let cContents = slCont["contents"] as? [[String: Any]] else {
                    break
                }
                sections.append(contentsOf: self.parseCarouselShelves(cContents))
                contToken = ((slCont["continuations"] as? [[String: Any]])?.first?["nextContinuationData"] as? [String: Any])?["continuation"] as? String
            }
            return sections
        }()

        async let personalTask: [HomeSection] = buildPersonalizedShelves(history: history, liked: liked)

        let (ytSections, personalSections) = await (ytHomeTask, personalTask)

        var combined: [HomeSection] = []
        var ytRemaining = ytSections
        if let firstIdx = ytRemaining.firstIndex(where: { $0.isTrackGrid }) {
            combined.append(ytRemaining.remove(at: firstIdx))
        }
        combined.append(contentsOf: personalSections)
        combined.append(contentsOf: ytRemaining)
        return combined
    }

    private func buildPersonalizedShelves(history: [SongItem], liked: [SongItem]) async -> [HomeSection] {
        var scores: [String: Double] = [:]
        var songMap: [String: SongItem] = [:]

        for (idx, song) in history.prefix(60).enumerated() where song.kind == .song {
            let weight = exp(-Double(idx) / 14.0)
            scores[song.id, default: 0] += weight
            songMap[song.id] = song
        }
        for song in liked.suffix(50) where song.kind == .song {
            scores[song.id, default: 0] += 1.5
            songMap[song.id] = song
        }

        let ranked = scores.sorted { $0.value > $1.value }.compactMap { songMap[$0.key] }
        guard !ranked.isEmpty else { return [] }

        var result: [HomeSection] = []
        let listenAgain = Array(ranked.prefix(12))
        if listenAgain.count >= 4 {
            result.append(HomeSection(title: "Listen again", items: listenAgain, isTrackGrid: false))
        }

        var seeds: [SongItem] = []
        var seenArtists = Set<String>()
        for s in ranked {
            let key = s.artist.lowercased()
            if seenArtists.insert(key).inserted {
                seeds.append(s)
                if seeds.count >= 3 { break }
            }
        }

        let heardIds = Set(history.prefix(30).map(\.id))
        await withTaskGroup(of: (Int, HomeSection?).self) { group in
            for (idx, seed) in seeds.enumerated() {
                group.addTask {
                    let radio = await self.fetchRadio(videoId: seed.id)
                    var artistCounts: [String: Int] = [:]
                    let filtered = radio.filter { item in
                        guard item.id != seed.id && !heardIds.contains(item.id) else { return false }
                        let aKey = item.artist.lowercased()
                        let c = (artistCounts[aKey] ?? 0) + 1
                        artistCounts[aKey] = c
                        return c <= 2
                    }
                    guard filtered.count >= 4 else { return (idx, nil) }
                    let isArtistShelf = idx == 1 && seed.artist != "YouTube Music"
                    let title = isArtistShelf ? "More like \(seed.artist)" : "Because you like \(seed.title)"
                    return (idx, HomeSection(title: title, items: Array(filtered.prefix(12)), isTrackGrid: false))
                }
            }
            var shelves: [(Int, HomeSection)] = []
            for await (idx, sec) in group {
                if let sec { shelves.append((idx, sec)) }
            }
            shelves.sort { $0.0 < $1.0 }
            result.append(contentsOf: shelves.map(\.1))
        }

        return result
    }

    public func getSearchSuggestions(query: String) async -> [String] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty,
              let request = makeWebRemixRequest(endpoint: "music/get_search_suggestions", body: ["input": query]),
              let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let contents = json["contents"] as? [[String: Any]] else {
            return []
        }

        var results: [String] = []
        for c in contents {
            guard let section = c["searchSuggestionsSectionRenderer"] as? [String: Any],
                  let items = section["contents"] as? [[String: Any]] else { continue }
            for it in items {
                guard let renderer = it["searchSuggestionRenderer"] as? [String: Any],
                      let suggestion = renderer["suggestion"] as? [String: Any],
                      let runs = suggestion["runs"] as? [[String: Any]] else { continue }
                let text = runs.compactMap { $0["text"] as? String }.joined().trimmingCharacters(in: .whitespaces)
                if !text.isEmpty && !results.contains(text) {
                    results.append(text)
                }
            }
        }
        return results
    }

    public func search(query: String) async -> [SongItem] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty,
              let request = makeWebRemixRequest(endpoint: "search", body: ["query": query]),
              let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let contents = json["contents"] as? [String: Any],
              let tabbed = contents["tabbedSearchResultsRenderer"] as? [String: Any],
              let tabs = tabbed["tabs"] as? [[String: Any]],
              let firstTab = tabs.first?["tabRenderer"] as? [String: Any],
              let tabContent = firstTab["content"] as? [String: Any],
              let sectionList = tabContent["sectionListRenderer"] as? [String: Any],
              let sections = sectionList["contents"] as? [[String: Any]] else {
            return []
        }

        var results: [SongItem] = []

        for sec in sections {
            if let card = sec["musicCardShelfRenderer"] as? [String: Any] {
                if let top = parseCardShelfTopResult(card) {
                    results.append(top)
                }
                for c in card["contents"] as? [[String: Any]] ?? [] {
                    if let item = c["musicResponsiveListItemRenderer"] as? [String: Any],
                       let parsed = parseResponsiveItem(item) {
                        results.append(parsed)
                    }
                }
            } else if let shelf = (sec["musicShelfRenderer"] as? [String: Any]) ?? (sec["itemSectionRenderer"] as? [String: Any]) {
                for c in shelf["contents"] as? [[String: Any]] ?? [] {
                    if let item = c["musicResponsiveListItemRenderer"] as? [String: Any],
                       let parsed = parseResponsiveItem(item) {
                        results.append(parsed)
                    }
                }
            }
        }

        return results
    }

    public func fetchBrowseAlbumOrPlaylist(browseId: String) async -> (title: String, artist: String, thumbnail: String?, tracks: [SongItem])? {
        guard !browseId.isEmpty,
              let request = makeWebRemixRequest(endpoint: "browse", body: ["browseId": browseId]),
              let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let contents = json["contents"] as? [String: Any] else {
            return nil
        }

        var headerDict: [String: Any]?
        var shelfContainers: [[String: Any]] = []

        if let twoCol = contents["twoColumnBrowseResultsRenderer"] as? [String: Any] {
            let tabs = twoCol["tabs"] as? [[String: Any]]
            let tabSections = (((tabs?.first?["tabRenderer"] as? [String: Any])?["content"] as? [String: Any])?["sectionListRenderer"] as? [String: Any])?["contents"] as? [[String: Any]]
            if let firstHeaderSec = tabSections?.first {
                headerDict = (firstHeaderSec["musicResponsiveHeaderRenderer"] as? [String: Any])
                    ?? (firstHeaderSec["musicDetailHeaderRenderer"] as? [String: Any])
            }
            shelfContainers = ((twoCol["secondaryContents"] as? [String: Any])?["sectionListRenderer"] as? [String: Any])?["contents"] as? [[String: Any]] ?? []
        } else if let single = contents["singleColumnBrowseResultsRenderer"] as? [String: Any] {
            let tabs = single["tabs"] as? [[String: Any]]
            shelfContainers = (((tabs?.first?["tabRenderer"] as? [String: Any])?["content"] as? [String: Any])?["sectionListRenderer"] as? [String: Any])?["contents"] as? [[String: Any]] ?? []
            headerDict = (json["header"] as? [String: Any])?["musicDetailHeaderRenderer"] as? [String: Any]
        }

        let title = runsText((headerDict?["title"] as? [String: Any])?["runs"] as? [[String: Any]]) ?? "Collection"
        let strapline = runsText((headerDict?["straplineTextOne"] as? [String: Any])?["runs"] as? [[String: Any]])
        let subtitle = runsText((headerDict?["subtitle"] as? [String: Any])?["runs"] as? [[String: Any]])
        let artist = strapline ?? subtitle ?? "YouTube Music"
        let thumbnail = extractThumbnail(from: headerDict?["thumbnail"] as? [String: Any])

        var tracks: [SongItem] = []
        for sec in shelfContainers {
            let shelf = (sec["musicShelfRenderer"] as? [String: Any])
                ?? (sec["musicPlaylistShelfRenderer"] as? [String: Any])
            guard let shelf else { continue }
            for c in shelf["contents"] as? [[String: Any]] ?? [] {
                if let item = c["musicResponsiveListItemRenderer"] as? [String: Any],
                   let parsed = parseResponsiveItem(item, fallbackArtist: artist, fallbackThumbnail: thumbnail),
                   parsed.kind == .song {
                    tracks.append(parsed)
                }
            }
        }

        return (title: title, artist: artist, thumbnail: thumbnail, tracks: tracks)
    }

    public func fetchRadio(videoId: String) async -> [SongItem] {
        guard !videoId.isEmpty,
              let request = makeWebRemixRequest(endpoint: "next", body: [
                  "videoId": videoId,
                  "playlistId": "RDAMVM\(videoId)"
              ]),
              let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let contents = json["contents"] as? [String: Any],
              let singleCol = contents["singleColumnMusicWatchNextResultsRenderer"] as? [String: Any],
              let tabbed = singleCol["tabbedRenderer"] as? [String: Any],
              let watchNext = tabbed["watchNextTabbedResultsRenderer"] as? [String: Any],
              let tabs = watchNext["tabs"] as? [[String: Any]],
              let firstTab = tabs.first?["tabRenderer"] as? [String: Any],
              let tabContent = firstTab["content"] as? [String: Any],
              let queueRenderer = tabContent["musicQueueRenderer"] as? [String: Any],
              let panelContent = queueRenderer["content"] as? [String: Any],
              let panelRenderer = panelContent["playlistPanelRenderer"] as? [String: Any],
              let rawItems = panelRenderer["contents"] as? [[String: Any]] else {
            return []
        }

        var results: [SongItem] = []
        for c in rawItems {
            guard let p = c["playlistPanelVideoRenderer"] as? [String: Any],
                  let vid = p["videoId"] as? String else { continue }
            let titleRuns = (p["title"] as? [String: Any])?["runs"] as? [[String: Any]]
            let title = titleRuns?.first?["text"] as? String ?? "Unknown"
            let bylineRuns = (p["longBylineText"] as? [String: Any])?["runs"] as? [[String: Any]]
            let artist = bylineRuns?.first?["text"] as? String ?? "YouTube Music"
            let durRuns = ((p["lengthText"] as? [String: Any])?["runs"] as? [[String: Any]])?.first?["text"] as? String
            let duration = parseDuration(durRuns)
            let thumbDict = p["thumbnail"] as? [String: Any]
            let thumbs = thumbDict?["thumbnails"] as? [[String: Any]] ?? []
            let thumb = thumbs.last?["url"] as? String
            results.append(SongItem(id: vid, title: title, artist: artist, duration: duration, thumbnail: thumb, kind: .song))
        }
        return results
    }

    public func resolveStream(videoId: String) async -> (url: String, durationMs: Int64)? {
        guard let url = URL(string: "https://music.youtube.com/youtubei/v1/player") else { return nil }
        let visitor = await ensureVisitorData()

        let clients: [[String: String]] = [
            [
                "clientName": "VISIONOS",
                "clientVersion": "0.1",
                "clientId": "101",
                "osName": "visionOS",
                "osVersion": "1.3.21O771",
                "deviceMake": "Apple",
                "deviceModel": "RealityDevice14,1",
                "userAgent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"
            ],
            [
                "clientName": "ANDROID_VR",
                "clientVersion": "1.61.48",
                "clientId": "28",
                "osName": "Android",
                "osVersion": "12",
                "deviceMake": "Oculus",
                "deviceModel": "Quest 3",
                "userAgent": "com.google.android.apps.youtube.vr.oculus/1.61.48 (Linux; U; Android 12; en_US; Quest 3; Build/SQ3A.220605.009.A1; Cronet/132.0.6808.3)"
            ]
        ]

        for client in clients {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(client["userAgent"]!, forHTTPHeaderField: "User-Agent")
            request.setValue(client["clientId"]!, forHTTPHeaderField: "X-YouTube-Client-Name")
            request.setValue(client["clientVersion"]!, forHTTPHeaderField: "X-YouTube-Client-Version")
            if let visitor {
                request.setValue(visitor, forHTTPHeaderField: "X-Goog-Visitor-Id")
            }

            var clientCtx: [String: Any] = [
                "clientName": client["clientName"]!,
                "clientVersion": client["clientVersion"]!,
                "osName": client["osName"]!,
                "osVersion": client["osVersion"]!,
                "deviceMake": client["deviceMake"]!,
                "deviceModel": client["deviceModel"]!,
                "hl": "en",
                "gl": "US"
            ]
            if let visitor {
                clientCtx["visitorData"] = visitor
            }

            let body: [String: Any] = [
                "context": ["client": clientCtx],
                "videoId": videoId
            ]

            guard let httpBody = try? JSONSerialization.data(withJSONObject: body),
                  let (data, response) = try? await session.data(for: request.withBody(httpBody)),
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            let streaming = json["streamingData"] as? [String: Any]
            let formats = streaming?["adaptiveFormats"] as? [[String: Any]] ?? []

            let mp4Audio = formats.filter { f in
                let mime = f["mimeType"] as? String ?? ""
                let streamUrl = f["url"] as? String
                let isDrc = f["isDrc"] as? Bool ?? false
                return mime.hasPrefix("audio/mp4") && streamUrl != nil && !streamUrl!.isEmpty && !isDrc
            }

            if let best = mp4Audio.max(by: { ($0["bitrate"] as? Int ?? 0) < ($1["bitrate"] as? Int ?? 0) }),
               let streamUrl = best["url"] as? String {
                let durMs = (best["approxDurationMs"] as? String).flatMap(Int64.init)
                    ?? (json["videoDetails"] as? [String: Any])?["lengthSeconds"].flatMap { s in (s as? String).flatMap(Int64.init).map { $0 * 1000 } }
                    ?? 0
                return (url: streamUrl, durationMs: durMs)
            }
        }

        return nil
    }

    private func parseCardShelfTopResult(_ card: [String: Any]) -> SongItem? {
        let titleRuns = (card["title"] as? [String: Any])?["runs"] as? [[String: Any]]
        guard let title = titleRuns?.first?["text"] as? String else { return nil }
        let nav = (titleRuns?.first?["navigationEndpoint"] as? [String: Any]) ?? (card["onTap"] as? [String: Any])
        let thumb = extractThumbnail(from: card["thumbnail"] as? [String: Any])
        let subRuns = (card["subtitle"] as? [String: Any])?["runs"] as? [[String: Any]]
        let artist = extractArtist(from: subRuns) ?? "YouTube Music"
        var duration: Int? = nil
        for r in (subRuns ?? []).reversed() {
            if let t = r["text"] as? String, let d = parseDuration(t) {
                duration = d
                break
            }
        }

        if let vid = (nav?["watchEndpoint"] as? [String: Any])?["videoId"] as? String {
            return SongItem(id: vid, title: title, artist: artist, duration: duration, thumbnail: thumb, kind: .song)
        }
        if let browse = extractBrowse(from: nav) {
            return SongItem(id: browse.browseId, title: title, artist: artist, duration: duration, thumbnail: thumb, kind: browse.kind, browseId: browse.browseId)
        }
        return nil
    }

    private func parseResponsiveItem(
        _ item: [String: Any],
        fallbackArtist: String? = nil,
        fallbackThumbnail: String? = nil
    ) -> SongItem? {
        let flex = item["flexColumns"] as? [[String: Any]] ?? []
        guard !flex.isEmpty else { return nil }

        let firstCol = (flex[0]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any])?["text"] as? [String: Any]
        let firstRuns = firstCol?["runs"] as? [[String: Any]]
        guard let title = firstRuns?.first?["text"] as? String else { return nil }

        let firstNav = firstRuns?.first?["navigationEndpoint"] as? [String: Any]
        var vid = (firstNav?["watchEndpoint"] as? [String: Any])?["videoId"] as? String

        if vid == nil {
            let overlay = item["overlay"] as? [String: Any]
            let thumbOverlay = overlay?["musicItemThumbnailOverlayRenderer"] as? [String: Any]
            let btn = (thumbOverlay?["content"] as? [String: Any])?["musicPlayButtonRenderer"] as? [String: Any]
            let playNav = btn?["playNavigationEndpoint"] as? [String: Any]
            let watch = playNav?["watchEndpoint"] as? [String: Any]
            vid = watch?["videoId"] as? String
        }

        let secondRuns = flex.count >= 2
            ? ((flex[1]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any])?["text"] as? [String: Any])?["runs"] as? [[String: Any]]
            : nil
        let artist = extractArtist(from: secondRuns) ?? fallbackArtist ?? "YouTube Music"
        let thumb = extractThumbnail(from: item["thumbnail"] as? [String: Any]) ?? fallbackThumbnail

        let fixedCols = item["fixedColumns"] as? [[String: Any]] ?? []
        let durRuns = ((fixedCols.first?["musicResponsiveListItemFixedColumnRenderer"] as? [String: Any])?["text"] as? [String: Any])?["runs"] as? [[String: Any]]
        var duration = parseDuration(durRuns?.first?["text"] as? String)
        if duration == nil {
            for col in flex {
                let runs = ((col["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any])?["text"] as? [String: Any])?["runs"] as? [[String: Any]] ?? []
                for r in runs.reversed() {
                    if let t = r["text"] as? String, let d = parseDuration(t) {
                        duration = d
                        break
                    }
                }
                if duration != nil { break }
            }
        }

        if let vid {
            return SongItem(id: vid, title: title, artist: artist, duration: duration, thumbnail: thumb, kind: .song)
        }

        let browse = extractBrowse(from: item["navigationEndpoint"] as? [String: Any]) ?? extractBrowse(from: firstNav)
        if let browse {
            return SongItem(id: browse.browseId, title: title, artist: artist, duration: duration, thumbnail: thumb, kind: browse.kind, browseId: browse.browseId)
        }

        return nil
    }

    private func parseTwoRowItem(_ twoRow: [String: Any]) -> SongItem? {
        let titleRuns = (twoRow["title"] as? [String: Any])?["runs"] as? [[String: Any]]
        guard let title = titleRuns?.first?["text"] as? String else { return nil }

        let subRuns = (twoRow["subtitle"] as? [String: Any])?["runs"] as? [[String: Any]]
        let artist = extractArtist(from: subRuns) ?? "YouTube Music"

        let nav = twoRow["navigationEndpoint"] as? [String: Any]
        var vid = (nav?["watchEndpoint"] as? [String: Any])?["videoId"] as? String

        if vid == nil {
            let overlay = twoRow["thumbnailOverlay"] as? [String: Any]
            let thumbOverlay = overlay?["musicItemThumbnailOverlayRenderer"] as? [String: Any]
            let btn = (thumbOverlay?["content"] as? [String: Any])?["musicPlayButtonRenderer"] as? [String: Any]
            let playNav = btn?["playNavigationEndpoint"] as? [String: Any]
            let watch = playNav?["watchEndpoint"] as? [String: Any]
            vid = watch?["videoId"] as? String
        }

        let thumb = extractThumbnail(from: twoRow["thumbnailRenderer"] as? [String: Any])
        var duration: Int? = nil
        for r in (subRuns ?? []).reversed() {
            if let t = r["text"] as? String, let d = parseDuration(t) {
                duration = d
                break
            }
        }

        if let vid {
            return SongItem(id: vid, title: title, artist: artist, duration: duration, thumbnail: thumb, kind: .song)
        }

        if let browse = extractBrowse(from: nav) {
            return SongItem(id: browse.browseId, title: title, artist: artist, duration: duration, thumbnail: thumb, kind: browse.kind, browseId: browse.browseId)
        }

        return nil
    }

    private func extractBrowse(from nav: [String: Any]?) -> (browseId: String, kind: MediaItemKind)? {
        guard let be = nav?["browseEndpoint"] as? [String: Any],
              let browseId = be["browseId"] as? String else { return nil }
        let configs = be["browseEndpointContextSupportedConfigs"] as? [String: Any]
        let musicCfg = configs?["browseEndpointContextMusicConfig"] as? [String: Any]
        let pageType = musicCfg?["pageType"] as? String

        switch pageType {
        case "MUSIC_PAGE_TYPE_ALBUM":
            return (browseId, .album)
        case "MUSIC_PAGE_TYPE_PLAYLIST":
            return (browseId, .playlist)
        default:
            return nil
        }
    }

    private func extractThumbnail(from dict: [String: Any]?) -> String? {
        let renderer = dict?["musicThumbnailRenderer"] as? [String: Any]
        let container = renderer?["thumbnail"] as? [String: Any]
        let thumbs = container?["thumbnails"] as? [[String: Any]] ?? []
        return thumbs.last?["url"] as? String
    }

    private func runsText(_ runs: [[String: Any]]?) -> String? {
        guard let runs, !runs.isEmpty else { return nil }
        let joined = runs.compactMap { $0["text"] as? String }.joined().trimmingCharacters(in: .whitespaces)
        return joined.isEmpty ? nil : joined
    }

    private func extractArtist(from runs: [[String: Any]]?) -> String? {
        guard let runs, !runs.isEmpty else { return nil }
        let skipKinds: Set<String> = ["Song", "Video", "Album", "Single", "EP", "Playlist"]
        let texts = runs.compactMap { $0["text"] as? String }
        // Split on " • " segments and drop leading media-type label or trailing play/year stats
        let segments = texts.joined().components(separatedBy: " • ")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !segments.isEmpty else { return nil }
        if segments.count >= 2 && skipKinds.contains(segments[0]) {
            return segments[1]
        }
        return segments[0]
    }

    private func parseDuration(_ text: String?) -> Int? {
        guard let text else { return nil }
        let parts = text.split(separator: ":").compactMap { Int($0) }
        switch parts.count {
        case 2: return parts[0] * 60 + parts[1]
        case 3: return parts[0] * 3600 + parts[1] * 60 + parts[2]
        default: return nil
        }
    }
}

private extension URLRequest {
    func withBody(_ body: Data) -> URLRequest {
        var copy = self
        copy.httpBody = body
        return copy
    }
}

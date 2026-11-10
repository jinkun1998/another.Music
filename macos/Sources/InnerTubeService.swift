import Foundation

public final class InnerTubeService: Sendable {
    public static let shared = InnerTubeService()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    public func fetchHome() async -> [HomeSection] {
        guard let url = URL(string: "https://music.youtube.com/youtubei/v1/browse") else { return [] }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) Gecko/20100101 Firefox/140.0", forHTTPHeaderField: "User-Agent")
        request.setValue("67", forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue("1.20260707.12.00", forHTTPHeaderField: "X-YouTube-Client-Version")

        let body: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "WEB_REMIX",
                    "clientVersion": "1.20260707.12.00",
                    "hl": "en",
                    "gl": "US"
                ]
            ],
            "browseId": "FEmusic_home"
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body),
              let (data, response) = try? await session.data(for: request.withBody(httpBody)),
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

        var result: [HomeSection] = []

        for sec in sectionContents {
            guard let shelf = sec["musicCarouselShelfRenderer"] as? [String: Any] else { continue }
            let header = shelf["header"] as? [String: Any]
            let basicHeader = header?["musicCarouselShelfBasicHeaderRenderer"] as? [String: Any]
            let titleRuns = (basicHeader?["title"] as? [String: Any])?["runs"] as? [[String: Any]]
            let sectionTitle = titleRuns?.first?["text"] as? String ?? "Featured"
            let straplineRuns = (basicHeader?["strapline"] as? [String: Any])?["runs"] as? [[String: Any]]
            let sectionLabel = straplineRuns?.first?["text"] as? String

            var items: [SongItem] = []
            let shelfItems = shelf["contents"] as? [[String: Any]] ?? []

            for c in shelfItems {
                if let item = c["musicResponsiveListItemRenderer"] as? [String: Any] {
                    if let song = parseResponsiveItem(item) {
                        items.append(song)
                    }
                } else if let twoRow = c["musicTwoRowItemRenderer"] as? [String: Any] {
                    if let song = parseTwoRowItem(twoRow) {
                        items.append(song)
                    }
                }
            }

            if !items.isEmpty {
                result.append(HomeSection(title: sectionTitle, label: sectionLabel, items: items))
            }
        }

        return result
    }

    public func search(query: String) async -> [SongItem] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty,
              let url = URL(string: "https://music.youtube.com/youtubei/v1/search") else { return [] }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) Gecko/20100101 Firefox/140.0", forHTTPHeaderField: "User-Agent")
        request.setValue("67", forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue("1.20260707.12.00", forHTTPHeaderField: "X-YouTube-Client-Version")

        let body: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "WEB_REMIX",
                    "clientVersion": "1.20260707.12.00",
                    "hl": "en",
                    "gl": "US"
                ]
            ],
            "query": query
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body),
              let (data, response) = try? await session.data(for: request.withBody(httpBody)),
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
            let shelf = (sec["musicShelfRenderer"] as? [String: Any]) ?? (sec["musicCardShelfRenderer"] as? [String: Any])
            guard let shelf else { continue }
            let shelfContents = shelf["contents"] as? [[String: Any]] ?? []

            for c in shelfContents {
                if let item = c["musicResponsiveListItemRenderer"] as? [String: Any],
                   let song = parseResponsiveItem(item) {
                    results.append(song)
                }
            }
        }

        return results
    }

    public func resolveStream(videoId: String) async -> (url: String, durationMs: Int64)? {
        guard let url = URL(string: "https://music.youtube.com/youtubei/v1/player") else { return nil }

        let clients: [[String: String]] = [
            ["clientName": "VISIONOS", "clientVersion": "0.1", "deviceMake": "Apple", "deviceModel": "RealityDevice14,1"],
            ["clientName": "IOS", "clientVersion": "21.03.1"],
            ["clientName": "ANDROID_VR", "clientVersion": "1.65.10"]
        ]

        for client in clients {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
            if let cName = client["clientName"], cName == "VISIONOS" {
                request.setValue("101", forHTTPHeaderField: "X-YouTube-Client-Name")
                request.setValue("0.1", forHTTPHeaderField: "X-YouTube-Client-Version")
            }

            let body: [String: Any] = [
                "context": [
                    "client": [
                        "clientName": client["clientName"] ?? "VISIONOS",
                        "clientVersion": client["clientVersion"] ?? "0.1",
                        "deviceMake": client["deviceMake"] ?? "Apple",
                        "deviceModel": client["deviceModel"] ?? "RealityDevice14,1",
                        "hl": "en",
                        "gl": "US"
                    ]
                ],
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
                return mime.hasPrefix("audio/mp4") && streamUrl != nil && !streamUrl!.isEmpty
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

    private func parseResponsiveItem(_ item: [String: Any]) -> SongItem? {
        let flex = item["flexColumns"] as? [[String: Any]] ?? []
        guard flex.count >= 2 else { return nil }

        let firstCol = (flex[0]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any])?["text"] as? [String: Any]
        let firstRuns = firstCol?["runs"] as? [[String: Any]]
        guard let title = firstRuns?.first?["text"] as? String else { return nil }

        let videoId = (firstRuns?.first?["navigationEndpoint"] as? [String: Any])?["watchEndpoint"] as? [String: Any]
        var vid = videoId?["videoId"] as? String

        if vid == nil {
            let overlay = item["overlay"] as? [String: Any]
            let thumbOverlay = overlay?["musicItemThumbnailOverlayRenderer"] as? [String: Any]
            let btn = (thumbOverlay?["content"] as? [String: Any])?["musicPlayButtonRenderer"] as? [String: Any]
            let playNav = btn?["playNavigationEndpoint"] as? [String: Any]
            let watch = playNav?["watchEndpoint"] as? [String: Any]
            vid = watch?["videoId"] as? String
        }

        guard let vid else { return nil }

        let secondCol = (flex[1]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any])?["text"] as? [String: Any]
        let secondRuns = secondCol?["runs"] as? [[String: Any]]
        let artist = secondRuns?.first?["text"] as? String ?? "YouTube Music"

        let thumbDict = item["thumbnail"] as? [String: Any]
        let renderer = thumbDict?["musicThumbnailRenderer"] as? [String: Any]
        let thumbContainer = renderer?["thumbnail"] as? [String: Any]
        let thumbs = thumbContainer?["thumbnails"] as? [[String: Any]] ?? []
        let thumb = thumbs.last?["url"] as? String

        return SongItem(id: vid, title: title, artist: artist, thumbnail: thumb)
    }

    private func parseTwoRowItem(_ twoRow: [String: Any]) -> SongItem? {
        let titleRuns = (twoRow["title"] as? [String: Any])?["runs"] as? [[String: Any]]
        guard let title = titleRuns?.first?["text"] as? String else { return nil }

        let subRuns = (twoRow["subtitle"] as? [String: Any])?["runs"] as? [[String: Any]]
        let artist = subRuns?.first?["text"] as? String ?? "YouTube Music"

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

        let thumbRenderer = (twoRow["thumbnailRenderer"] as? [String: Any])?["musicThumbnailRenderer"] as? [String: Any]
        let thumbContainer = thumbRenderer?["thumbnail"] as? [String: Any]
        let thumbs = thumbContainer?["thumbnails"] as? [[String: Any]] ?? []
        let thumb = thumbs.last?["url"] as? String

        return SongItem(id: vid ?? title, title: title, artist: artist, thumbnail: thumb)
    }
}

private extension URLRequest {
    func withBody(_ body: Data) -> URLRequest {
        var copy = self
        copy.httpBody = body
        return copy
    }
}

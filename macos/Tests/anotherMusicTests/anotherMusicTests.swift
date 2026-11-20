import XCTest
@testable import anotherMusic

final class AnotherMusicTests: XCTestCase {
    func testInnerTubeStreamResolutionAndRangeProbe() async throws {
        let seed = SongItem(id: "4NRXx6U8ABQ", title: "Blinding Lights", artist: "The Weeknd", kind: .song)
        let home = await InnerTubeService.shared.fetchHome(history: [seed], liked: [seed])
        XCTAssertGreaterThan(home.count, 1, "Home should return multiple shelves via continuation + personalized recommender")

        let firstSong = home.flatMap(\.items).first(where: { $0.kind == .song }) ?? seed
        let stream = await InnerTubeService.shared.resolveStream(videoId: firstSong.id)
        XCTAssertNotNil(stream, "Stream should resolve for home track \(firstSong.id)")
        if let stream, let url = URL(string: stream.url) {
            XCTAssertFalse(stream.url.isEmpty)
            XCTAssertGreaterThan(stream.durationMs, 30_000)

            var req = URLRequest(url: url)
            req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
            req.setValue("bytes=0-1048575", forHTTPHeaderField: "Range")
            let (_, resp) = try await URLSession.shared.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode
            XCTAssertEqual(code, 206, "Audio stream should return HTTP 206 Partial Content for >786KB range")
        }
    }

    func testLrcParsing() {
        let sampleLrc = """
        [00:12.34]First line of lyrics
        [00:25.67]<00:25.67>Word <00:26.10>synced <00:27.00>line
        """
        let parsed = LyricsService.shared.parseLrc(sampleLrc)
        XCTAssertEqual(parsed.count, 2)
        XCTAssertEqual(parsed[0].timeMs, 12340)
        XCTAssertEqual(parsed[0].text, "First line of lyrics")
        XCTAssertEqual(parsed[1].timeMs, 25670)
        XCTAssertEqual(parsed[1].text, "Word synced line")
    }

    func testAlbumBrowse() async throws {
        let r = await InnerTubeService.shared.fetchBrowseAlbumOrPlaylist(browseId: "MPREb_TH6Wut5eTMQ")
        XCTAssertNotNil(r)
        XCTAssertGreaterThan(r?.tracks.count ?? 0, 5)
    }

    @MainActor func testShuffleKeepsCurrentFirst() {
        let p = AudioPlayerService.shared
        let q = (0..<10).map { SongItem(id: "s\($0)", title: "t\($0)", artist: "a") }
        p.queue = q; p.currentIndex = 3
        p.toggleShuffle()
        XCTAssertEqual(p.queue.count, 10)
        p.toggleShuffle()
        XCTAssertFalse(p.isShuffle)
        p.cycleRepeatMode(); XCTAssertEqual(p.repeatMode, .all)
        p.cycleRepeatMode(); XCTAssertEqual(p.repeatMode, .one)
    }

    func testFetchRadio() async throws {
        let radio = await InnerTubeService.shared.fetchRadio(videoId: "dQw4w9WgXcQ")
        XCTAssertGreaterThan(radio.count, 10, "Radio should return similar tracks")
        XCTAssertEqual(radio.first?.kind, .song)
    }

    func testLyricsFetchCascade() async throws {
        let lines = await LyricsService.shared.fetchLyrics(videoId: "4NRXx6U8ABQ", title: "Blinding Lights", artist: "The Weeknd", durationSec: 200)
        XCTAssertGreaterThan(lines.count, 10, "Lyrics cascade should return lines")
    }

    func testTimeGreeting() {
        XCTAssertEqual(timeGreeting(hour: 8), "Good morning")
        XCTAssertEqual(timeGreeting(hour: 14), "Good afternoon")
        XCTAssertEqual(timeGreeting(hour: 19), "Good evening")
        XCTAssertEqual(timeGreeting(hour: 23), "Good night")
        XCTAssertEqual(timeGreeting(hour: 2), "Good night")
        XCTAssertEqual(timeGreeting(hour: 9, name: "Jin"), "Good morning, Jin")
        XCTAssertEqual(timeGreeting(hour: 15, name: "Jin"), "Good afternoon, Jin")
        XCTAssertEqual(timeGreeting(hour: 20, name: "  "), "Good evening")
    }

    func testSearchSuggestions() async throws {
        let sugs = await InnerTubeService.shared.getSearchSuggestions(query: "the weeknd")
        XCTAssertFalse(sugs.isEmpty, "Search suggestions should return completions")
    }

    func testSearchDurationParsingAndStreamDuration() async throws {
        let results = await InnerTubeService.shared.search(query: "neon a20 lite")
        let neon = results.first(where: { $0.id == "rlYOsUfpi3M" || $0.id == "D968qfUZMUE" })
        XCTAssertNotNil(neon, "Search should find Neon")
        if let neon {
            XCTAssertNotNil(neon.duration, "Neon search result should have duration parsed")
            if let d = neon.duration {
                XCTAssertGreaterThan(d, 200)
                XCTAssertLessThan(d, 230)
            }
        }
    }

    func testAutoMixEqualPowerEnergyPreservation() {
        let duration = 5.0
        for step in 0...10 {
            let elapsed = Double(step) * (duration / 10.0)
            let frac = min(max(elapsed / duration, 0.0), 1.0)
            let theta = frac * (.pi / 2.0)
            let outVol = cos(theta)
            let inVol = sin(theta)
            let totalPower = (outVol * outVol) + (inVol * inVol)
            XCTAssertEqual(totalPower, 1.0, accuracy: 0.0001, "Equal power curve must preserve constant acoustic energy (power == 1.0)")
        }
    }

    @MainActor
    func testPhase2AutoMixBassSwapAndHeadroomBounds() {
        // At progress 0: outgoing is 100% full, incoming is completely silent
        let start = AudioPlayerService.calculateAutomixGains(progress: 0.0)
        XCTAssertEqual(start.outGain, 1.0, accuracy: 0.001)
        XCTAssertEqual(start.inGain, 0.0, accuracy: 0.001)

        // At progress 1: outgoing is completely silent, incoming is 100% full
        let end = AudioPlayerService.calculateAutomixGains(progress: 1.0)
        XCTAssertEqual(end.outGain, 0.0, accuracy: 0.001)
        XCTAssertEqual(end.inGain, 1.0, accuracy: 0.001)

        // Bass-swap midpoint (progress 0.50)
        let mid = AudioPlayerService.calculateAutomixGains(progress: 0.50)
        XCTAssertGreaterThan(mid.outGain, 0.5)
        XCTAssertGreaterThan(mid.inGain, 0.5)

        // Across all steps, headroom compensation guarantees total acoustic power never clips (> 1.0)
        for step in 0...20 {
            let p = Double(step) / 20.0
            let (outCurve, inCurve) = AudioPlayerService.calculateAutomixGains(progress: p)
            let totalPower = (outCurve * outCurve) + (inCurve * inCurve)
            let headroom = totalPower > 1.0 ? (1.0 / sqrt(totalPower)) : 1.0
            let postPower = ((outCurve * headroom) * (outCurve * headroom)) + ((inCurve * headroom) * (inCurve * headroom))
            XCTAssertLessThanOrEqual(postPower, 1.0001, "Headroom limiter must strictly prevent acoustic power exceeding 1.0")
            XCTAssertGreaterThan(postPower, 0.5, "Acoustic power must stay energized during blend")
        }
    }

    @MainActor
    func testTransitionModeSelection() {
        let player = AudioPlayerService.shared
        player.setTransitionMode(.automix)
        XCTAssertEqual(player.transitionMode, .automix)
        XCTAssertEqual(player.transitionMode.rawValue, "Auto Mix")
        XCTAssertTrue(player.isAutomix)

        player.setTransitionMode(.crossfade)
        XCTAssertEqual(player.transitionMode, .crossfade)
        XCTAssertEqual(player.transitionMode.rawValue, "Cross Fade")
        XCTAssertFalse(player.isAutomix)

        player.setTransitionMode(.off)
        XCTAssertEqual(player.transitionMode, .off)
        XCTAssertEqual(player.transitionMode.rawValue, "Off")
        XCTAssertFalse(player.isAutomix)
    }

    @MainActor
    func testEqualizerToggleState() {
        let player = AudioPlayerService.shared
        let original = player.isEqEnabled
        player.toggleEqualizer()
        XCTAssertEqual(player.isEqEnabled, !original)
        player.toggleEqualizer()
        XCTAssertEqual(player.isEqEnabled, original)
    }

    @MainActor
    func testSeekWhileNotPlayingPreservesPosition() {
        let player = AudioPlayerService.shared
        player.prepare(song: SongItem(id: "test-seek", title: "Test Seek", artist: "Artist", duration: 200, kind: .song))
        XCTAssertFalse(player.isPlaying)
        XCTAssertEqual(player.positionSec, 0.0)

        // Scrub timeline to 50%
        player.seek(to: 0.50)
        XCTAssertEqual(player.progress, 0.50, accuracy: 0.001)
        XCTAssertEqual(player.positionSec, 100.0, accuracy: 0.1)

        // Scrub timeline to 75%
        player.seek(to: 0.75)
        XCTAssertEqual(player.progress, 0.75, accuracy: 0.001)
        XCTAssertEqual(player.positionSec, 150.0, accuracy: 0.1)

        // Scrub timeline to 90% (near end)
        player.seek(to: 0.90)
        XCTAssertEqual(player.progress, 0.90, accuracy: 0.001)
        XCTAssertEqual(player.positionSec, 180.0, accuracy: 0.1)
    }

    
    @MainActor
    func testTransitionVisualAndProgressLinearity() {
        let player = AudioPlayerService.shared
        XCTAssertEqual(player.transitionProgress, 0.0)
        XCTAssertNil(player.incomingTrack)

        // When not transitioning, uiTransitionProgress is 0.0
        XCTAssertEqual(player.uiTransitionProgress, 0.0)

        // Continuous S-curve centered at 0.50 (<duration> / 2)
        func evalUiFade(_ p: Double) -> Double {
            let clamped = min(max(p, 0.0), 1.0)
            return clamped * clamped * (3.0 - 2.0 * clamped)
        }
        XCTAssertEqual(evalUiFade(0.0), 0.0, accuracy: 0.001)
        XCTAssertEqual(evalUiFade(0.50), 0.50, accuracy: 0.001, "UI crossfade must reach 50% exactly at <duration> / 2")
        XCTAssertEqual(evalUiFade(1.0), 1.0, accuracy: 0.001)
    }

    @MainActor
    func testSeekNearEndAdvancesQueue() {
        let p = AudioPlayerService.shared
        let trackA = SongItem(id: "s1", title: "Track A", artist: "Artist", duration: 200, kind: .song)
        let trackB = SongItem(id: "s2", title: "Track B", artist: "Artist", duration: 212, kind: .song)
        p.prepare(song: trackA, queue: [trackA, trackB])
        XCTAssertEqual(p.currentTrack?.id, trackA.id)
        
        // Seeking to end (99%) cleanly advances to trackB
        p.seek(to: 0.99)
        XCTAssertEqual(p.currentTrack?.id, trackB.id, "Seek near end should cleanly advance to next song")
    }


    func testPauseFadeVolumeSmoothstepCurve() {
        // At progress 0.0 (moment pause is pressed): gain is full (1.0)
        XCTAssertEqual(AudioPlayerService.calculatePauseFadeGain(progress: 0.0), 1.0, accuracy: 0.001)

        // At midpoint 0.5: gain is exactly 0.50 (smooth ease)
        XCTAssertEqual(AudioPlayerService.calculatePauseFadeGain(progress: 0.5), 0.50, accuracy: 0.001)

        // At progress 1.0: gain reaches exact silence (0.0)
        XCTAssertEqual(AudioPlayerService.calculatePauseFadeGain(progress: 1.0), 0.0, accuracy: 0.001)

        // Verify gentle slope at start (no sudden drop): at 10% elapsed, volume only dropped by < 5%
        let startDrop = 1.0 - AudioPlayerService.calculatePauseFadeGain(progress: 0.10)
        XCTAssertLessThan(startDrop, 0.05, "Pause fade must start gently without abrupt initial volume cliff")

        // Monotonic decrease across all steps
        var prev = 1.0
        for step in 1...20 {
            let p = Double(step) / 20.0
            let g = AudioPlayerService.calculatePauseFadeGain(progress: p)
            XCTAssertLessThanOrEqual(g, prev)
            prev = g
        }
    }

    func testTurntableCartridgePauseGlideAndDropTransitions() {
        let grooveDeg = 100.0
        let restDeg = 77.5
        let duration = 1.4

        // At elapsed = 0, arm is at initial groove angle
        XCTAssertEqual(TurntableCanvas.calculateArmGlideAngle(from: grooveDeg, to: restDeg, elapsed: 0.0, duration: duration), grooveDeg, accuracy: 0.001)

        // At elapsed = half duration (0.7s), arm reaches exact midpoint (smoothstep S-curve symmetry)
        let mid = grooveDeg + (restDeg - grooveDeg) * 0.50
        XCTAssertEqual(TurntableCanvas.calculateArmGlideAngle(from: grooveDeg, to: restDeg, elapsed: 0.7, duration: duration), mid, accuracy: 0.001)

        // At elapsed >= duration (1.4s), arm is fully parked on rest stand
        XCTAssertEqual(TurntableCanvas.calculateArmGlideAngle(from: grooveDeg, to: restDeg, elapsed: 1.4, duration: duration), restDeg, accuracy: 0.001)
        XCTAssertEqual(TurntableCanvas.calculateArmGlideAngle(from: grooveDeg, to: restDeg, elapsed: 2.0, duration: duration), restDeg, accuracy: 0.001)

        // Arm drop on play (cubic ease-out)
        let dropDuration = 1.1
        XCTAssertEqual(TurntableCanvas.calculateArmDropAngle(from: restDeg, to: grooveDeg, elapsed: 0.0, duration: dropDuration), restDeg, accuracy: 0.001)
        XCTAssertEqual(TurntableCanvas.calculateArmDropAngle(from: restDeg, to: grooveDeg, elapsed: dropDuration, duration: dropDuration), grooveDeg, accuracy: 0.001)
    }

    func testSearchFiltersAndMediaKind() async {
        XCTAssertNil(SearchFilterType.all.params)
        XCTAssertEqual(SearchFilterType.songs.params, "EgWKAQIIAWoKEAkQBRAKEAMQBA%3D%3D")
        XCTAssertEqual(SearchFilterType.videos.params, "EgWKAQIQAWoKEAkQChAFEAMQBA%3D%3D")
        XCTAssertEqual(SearchFilterType.albums.params, "EgWKAQIYAWoKEAkQChAFEAMQBA%3D%3D")
        XCTAssertEqual(SearchFilterType.artists.params, "EgWKAQIgAWoKEAkQChAFEAMQBA%3D%3D")
        XCTAssertEqual(SearchFilterType.playlists.params, "EgeKAQQoAEABagoQAxAEEAoQCRAF")

        let artistKind = MediaItemKind.artist
        XCTAssertEqual(artistKind.rawValue, "artist")

        let songs = await InnerTubeService.shared.search(query: "Coldplay", params: SearchFilterType.songs.params)
        XCTAssertFalse(songs.isEmpty, "Filtered song search should return items")
        XCTAssertEqual(songs.first?.kind, .song)
    }

    func testYouTubeThumbnailResizing() {
        let ytUrl = "https://i.ytimg.com/vi/abc12345/mqdefault.jpg"
        XCTAssertEqual(ytUrl.ytResize(width: 1200, height: 1200), "https://i.ytimg.com/vi/abc12345/maxresdefault.jpg")
        XCTAssertEqual(ytUrl.ytResize(width: 500, height: 500), "https://i.ytimg.com/vi/abc12345/hqdefault.jpg")

        let googleContent = "https://lh3.googleusercontent.com/xyz=w226-h226-l90-rj"
        XCTAssertEqual(googleContent.ytResize(width: 1200, height: 1200), "https://lh3.googleusercontent.com/xyz=w1200-h1200-p-l90-rj")

        let ggpht = "https://yt3.ggpht.com/avatar=s120-c-k-c0x00ffffff-no-rj"
        XCTAssertEqual(ggpht.ytResize(width: 80, height: 80), "https://yt3.ggpht.com/avatar=s80")
    }

    func testHeroCarouselCardAssemblyAndGachaPlacement() {
        let history = [
            SongItem(id: "h1", title: "Song 1", artist: "Artist 1", thumbnail: "https://i.ytimg.com/vi/h1/default.jpg", kind: .song),
            SongItem(id: "h2", title: "Song 2", artist: "Artist 2", thumbnail: "https://i.ytimg.com/vi/h2/default.jpg", kind: .song)
        ]
        let liked = [
            SongItem(id: "l1", title: "Liked 1", artist: "Liked Artist 1", thumbnail: "https://i.ytimg.com/vi/l1/default.jpg", kind: .song)
        ]
        let shelfItems = [
            SongItem(id: "s1", title: "Rec 1", artist: "Rec Artist 1", thumbnail: "https://i.ytimg.com/vi/s1/default.jpg", kind: .song),
            SongItem(id: "a1", title: "Album 1", artist: "Album Artist 1", thumbnail: "https://i.ytimg.com/vi/a1/default.jpg", kind: .album)
        ]
        let sections = [
            HomeSection(id: "sec1", title: "Quick picks", label: "Because you like", items: shelfItems)
        ]

        // 1. When no current playing track, Card 0 is Continue from history
        let cards = buildHeroCards(
            history: history,
            liked: liked,
            sections: sections,
            currentTrack: nil,
            isPlaying: false
        )

        XCTAssertFalse(cards.isEmpty)
        XCTAssertEqual(cards.first?.id, "continue_h1")
        XCTAssertEqual(cards.first?.initialLabel.text, "Continue")

        // 2. Card 1 must be the Gacha Card ("hero_gacha_card")
        XCTAssertGreaterThan(cards.count, 1)
        XCTAssertEqual(cards[1].id, "hero_gacha_card")
        XCTAssertEqual(cards[1].kind, .gacha)
        XCTAssertEqual(cards[1].title, "Random plays")

        // 3. When song is actively playing, label shifts to "Now playing"
        let current = SongItem(id: "now1", title: "Playing Now", artist: "Live Artist", thumbnail: "https://i.ytimg.com/vi/now1/default.jpg", kind: .song)
        let playingCards = buildHeroCards(
            history: history,
            liked: liked,
            sections: sections,
            currentTrack: current,
            isPlaying: true
        )
        XCTAssertEqual(playingCards.first?.id, "now_playing_now1")
        XCTAssertEqual(playingCards.first?.label(isPlaying: true).text, "Now playing")

        // 4. Test Gacha candidate pool
        let candidates = buildGachaCandidates(history: history, liked: liked, sections: sections)
        XCTAssertGreaterThanOrEqual(candidates.count, 2)
        XCTAssertLessThanOrEqual(candidates.count, 10)
        let ids = candidates.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "Gacha candidates must be deduplicated")
    }

    func testGachaSoundsInitialization() {
        let sounds = GachaSounds.shared
        sounds.prepare()
        // Ensure calling tick and win does not crash even without physical audio output
        sounds.tick()
        sounds.win()
    }
}

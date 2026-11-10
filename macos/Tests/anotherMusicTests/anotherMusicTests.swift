import XCTest
@testable import anotherMusic

final class AnotherMusicTests: XCTestCase {
    func testInnerTubeStreamResolution() async throws {
        let stream = await InnerTubeService.shared.resolveStream(videoId: "dQw4w9WgXcQ")
        XCTAssertNotNil(stream, "Stream should resolve")
        if let stream {
            XCTAssertFalse(stream.url.isEmpty)
            XCTAssertGreaterThan(stream.durationMs, 200_000)
            print("Stream URL resolved: \(stream.url.prefix(60)), duration: \(stream.durationMs)ms")
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
}

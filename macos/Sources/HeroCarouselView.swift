import SwiftUI
import AppKit

// MARK: - YouTube Thumbnail Resizer
public extension String {
    func ytResize(width: Int? = nil, height: Int? = nil) -> String {
        if width == nil && height == nil { return self }
        if self.contains("i.ytimg.com") {
            let target = (width ?? 0) >= 1200 ? "maxresdefault.jpg" : "hqdefault.jpg"
            return self.replacingOccurrences(
                of: #"(default|mqdefault|hqdefault|sddefault|maxresdefault)\.jpg"#,
                with: target,
                options: .regularExpression
            )
        }
        if self.contains("googleusercontent.com") && self.contains("=w") {
            let baseUrl = self.components(separatedBy: "=w")[0]
            let w = width ?? 0
            let h = height ?? width ?? 0
            return "\(baseUrl)=w\(w)-h\(h)-p-l90-rj"
        }
        if self.contains("yt3.ggpht.com") {
            let baseUrl = self.components(separatedBy: "=")[0].components(separatedBy: "-s")[0]
            return "\(baseUrl)=s\(width ?? height ?? 0)"
        }
        if self.range(of: #"https://lh\d\.googleusercontent\.com/.*"#, options: .regularExpression) != nil {
            let baseUrl = self.components(separatedBy: "=")[0]
            let w = width ?? 0
            let h = height ?? width ?? 0
            return "\(baseUrl)=w\(w)-h\(h)-p-l90-rj"
        }
        return self
    }
}

// MARK: - Hero Models
public struct HeroLabel: Equatable, Hashable {
    public let text: String
    public let coverUrl: String?
    public let subject: String?
    public let roundCover: Bool

    public init(text: String, coverUrl: String? = nil, subject: String? = nil, roundCover: Bool = false) {
        self.text = text
        self.coverUrl = coverUrl
        self.subject = subject
        self.roundCover = roundCover
    }
}

public enum HeroPillKind: Equatable {
    case play
    case pause
    case view
    case roll
    case rolling
}

public enum HeroCardKind: Equatable {
    case keepListening(isLastPlayed: Bool)
    case discover(reason: String)
    case related(reason: HeroLabel)
    case playlist
    case album
    case gacha
}

public struct HeroCardModel: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let thumbnailUrl: String?
    public let kind: HeroCardKind
    public let songItem: SongItem?
    public let initialLabel: HeroLabel

    public init(
        id: String,
        title: String,
        subtitle: String,
        thumbnailUrl: String?,
        kind: HeroCardKind,
        songItem: SongItem?,
        initialLabel: HeroLabel
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.thumbnailUrl = thumbnailUrl
        self.kind = kind
        self.songItem = songItem
        self.initialLabel = initialLabel
    }

    public func label(isPlaying: Bool) -> HeroLabel {
        if case .gacha = kind {
            return initialLabel
        }
        if isPlaying {
            return HeroLabel(text: "Now playing")
        }
        return initialLabel
    }
}

// MARK: - Gacha Sound Effects (AppKit Native NSSound)
public final class GachaSounds {
    public static let shared = GachaSounds()
    private var tickSound: NSSound?
    private var winSound: NSSound?
    private var lastTickTime: TimeInterval = 0

    public init() {
        prepare()
    }

    public func prepare() {
        if tickSound == nil, let url = findSoundURL(named: "gacha_tick") {
            tickSound = NSSound(contentsOf: url, byReference: true)
        }
        if winSound == nil, let url = findSoundURL(named: "gacha_win") {
            winSound = NSSound(contentsOf: url, byReference: true)
        }
    }

    private func findSoundURL(named: String) -> URL? {
        if let bundleURL = Bundle.main.url(forResource: named, withExtension: "wav") {
            return bundleURL
        }
        let cwd = FileManager.default.currentDirectoryPath
        let candidates = [
            "\(cwd)/macos/Resources/\(named).wav",
            "\(cwd)/Resources/\(named).wav",
            "\(cwd)/app/src/main/res/raw/\(named).wav"
        ]
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        return nil
    }

    public func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastTickTime < 0.028 { return }
        lastTickTime = now
        tickSound?.stop()
        tickSound?.volume = 0.55
        tickSound?.play()
    }

    public func win() {
        winSound?.stop()
        winSound?.volume = 0.85
        winSound?.play()
    }
}

// MARK: - Gacha Die View
public struct GachaDieView: View {
    public let spinning: Bool

    public init(spinning: Bool) {
        self.spinning = spinning
    }

    public var body: some View {
        TimelineView(.animation(paused: !spinning)) { timeline in
            let angle: Double = spinning
                ? (timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 0.55) / 0.55) * 360.0
                : 0.0

            dieShape
                .rotationEffect(.degrees(angle))
        }
    }

    private var dieShape: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                .fill(Color.white)
                .frame(width: 20, height: 20)

            let pipSize: CGFloat = 3.0
            let pipColor = Color(red: 0.22, green: 0.22, blue: 0.22)
            let offset: CGFloat = 4.8

            Circle().fill(pipColor).frame(width: pipSize, height: pipSize)
                .offset(x: -offset, y: -offset)
            Circle().fill(pipColor).frame(width: pipSize, height: pipSize)
                .offset(x: offset, y: -offset)
            Circle().fill(pipColor).frame(width: pipSize, height: pipSize)
            Circle().fill(pipColor).frame(width: pipSize, height: pipSize)
                .offset(x: -offset, y: offset)
            Circle().fill(pipColor).frame(width: pipSize, height: pipSize)
                .offset(x: offset, y: offset)
        }
    }
}

// MARK: - Gacha Card View
public struct GachaCardView: View {
    public let candidates: [SongItem]
    public let isAudioPlaying: Bool
    public let currentPlayingTrackId: String?
    public let onPlayWonTrack: (SongItem, [SongItem]) -> Void
    public let onRollingStateChanged: ((Bool) -> Void)?

    @State private var reelPosition: Double = 0
    @State private var isRolling: Bool = false
    @State private var landedSong: SongItem?
    @State private var pointerKick: CGFloat = 0
    @State private var landPopScale: CGFloat = 1.0
    @State private var rollTimer: Timer?
    @State private var isHovered: Bool = false

    public init(
        candidates: [SongItem],
        isAudioPlaying: Bool = false,
        currentPlayingTrackId: String? = nil,
        onPlayWonTrack: @escaping (SongItem, [SongItem]) -> Void,
        onRollingStateChanged: ((Bool) -> Void)? = nil
    ) {
        self.candidates = candidates
        self.isAudioPlaying = isAudioPlaying
        self.currentPlayingTrackId = currentPlayingTrackId
        self.onPlayWonTrack = onPlayWonTrack
        self.onRollingStateChanged = onRollingStateChanged
    }

    public var body: some View {
        ZStack {
            // Background Dynamic Mesh Wash
            gachaBackgroundWash()

            // Reel covers column on right
            if !candidates.isEmpty {
                reelCoversColumn()
            }

            // Coral Pointer aimed at center
            coralPointerIndicator()

            // Text & Pill on bottom-left
            VStack(alignment: .leading, spacing: 6) {
                Spacer()

                // Android Mochy style HeroLabelLine
                Text(gachaLabelText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.70))

                // Title
                Text(gachaTitleText)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .shadow(color: Color.black.opacity(0.6), radius: 8, x: 0, y: 3)

                if let landed = landedSong, !isRolling {
                    Text(landed.artist)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.80))
                        .lineLimit(1)
                }

                Spacer().frame(height: 5)

                // Action Pill: roll!!
                Button(action: { startRoll() }) {
                    HStack(spacing: 8) {
                        GachaDieView(spinning: isRolling)

                        Text(isRolling ? "rolling!!" : "roll!!")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color(red: 0.18, green: 0.18, blue: 0.18))
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 34)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(isRolling ? 0.45 : 0.68))
                    )
                    .scaleEffect(isHovered && !isRolling ? 1.04 : 1.0)
                }
                .buttonStyle(.plain)
                .disabled(isRolling || candidates.isEmpty)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 26)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 8)
        .onHover { isHovered = $0 }
        .onDisappear {
            rollTimer?.invalidate()
            rollTimer = nil
        }
    }

    private var isCurrentlyPlayingResult: Bool {
        isAudioPlaying && landedSong != nil && currentPlayingTrackId == landedSong?.id
    }

    private var gachaLabelText: String {
        if isRolling {
            return "Rolling..."
        }
        if isCurrentlyPlayingResult {
            return "Now playing"
        }
        if landedSong != nil {
            return "You got"
        }
        return "Gacha here!"
    }

    private var gachaTitleText: String {
        if isRolling {
            return "Spinning reel..."
        }
        if let landed = landedSong {
            return landed.title
        }
        return "Random plays"
    }

    @ViewBuilder
    private func gachaBackgroundWash() -> some View {
        ZStack {
            // Base deep wash
            LinearGradient(
                colors: [
                    Color(red: 0.32, green: 0.28, blue: 0.44),
                    Color(red: 0.18, green: 0.16, blue: 0.28),
                    Color(red: 0.08, green: 0.08, blue: 0.14)
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )

            // Dynamic lit bloom
            RadialGradient(
                colors: [
                    Color(red: 0.88, green: 0.58, blue: 0.65).opacity(isRolling ? 0.45 : 0.32),
                    Color(red: 0.55, green: 0.45, blue: 0.72).opacity(0.20),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 40,
                endRadius: 650
            )

            // Text readability dark scrim on left
            LinearGradient(
                stops: [
                    .init(color: Color.black.opacity(0.85), location: 0.0),
                    .init(color: Color.black.opacity(0.45), location: 0.55),
                    .init(color: Color.clear, location: 0.85)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            // Subtle top/bottom edge shade
            LinearGradient(
                stops: [
                    .init(color: Color.black.opacity(0.50), location: 0.0),
                    .init(color: Color.clear, location: 0.35),
                    .init(color: Color.clear, location: 0.65),
                    .init(color: Color.black.opacity(0.70), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    @ViewBuilder
    private func coralPointerIndicator() -> some View {
        let pointerColor = Color(red: 0.94, green: 0.56, blue: 0.55)

        HStack {
            Spacer()

            Image(systemName: "arrowtriangle.right.fill")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(pointerColor)
                .shadow(color: pointerColor.opacity(0.5), radius: 8, x: 0, y: 0)
                .offset(x: -pointerKick * 7.0)
                .rotationEffect(.degrees(-Double(pointerKick * 8.0)))
                .scaleEffect(landPopScale > 1.0 ? 1.20 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: pointerKick)
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: landPopScale)
                .offset(x: -125, y: 0)
        }
    }

    @ViewBuilder
    private func reelCoversColumn() -> some View {
        let count = candidates.count

        ZStack {
            ForEach(Array(candidates.enumerated()), id: \.element.id) { index, song in
                let d = reelDistance(index: index, reel: reelPosition, count: count)
                if abs(d) <= 2.6 {
                    let near = max(0, 1.0 - abs(d))
                    let scale = (170.0 + (215.0 - 170.0) * near) / 215.0
                    let isCenter = near > 0.65
                    let pop = isCenter ? landPopScale : 1.0
                    let slotY = d * 185.0

                    CachedAsyncImage(
                        urlString: song.thumbnail?.ytResize(width: 500, height: 500),
                        content: { img in
                            img.resizable()
                                .aspectRatio(contentMode: .fill)
                        },
                        placeholder: {
                            Color.gray.opacity(0.3)
                        }
                    )
                    .frame(width: 210, height: 210)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(
                                isCenter ? Color.white.opacity(0.65) : Color.white.opacity(0.12),
                                lineWidth: isCenter ? 2.5 : 1.0
                            )
                    )
                    .shadow(
                        color: isCenter ? Color.black.opacity(0.65) : Color.black.opacity(0.35),
                        radius: isCenter ? 18 : 8,
                        x: 0,
                        y: isCenter ? 8 : 4
                    )
                    .scaleEffect(scale * pop)
                    .rotation3DEffect(
                        .degrees(-Double(d * 18.0)),
                        axis: (x: 1.0, y: 0.0, z: 0.0),
                        perspective: 0.6
                    )
                    .offset(x: 28, y: slotY)
                    .opacity(max(0, min(1.0, 2.5 - abs(d))))
                    .onTapGesture {
                        if !isRolling {
                            startRoll()
                        }
                    }
                }
            }
        }
        .frame(width: 260)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func reelDistance(index: Int, reel: Double, count: Int) -> Double {
        guard count > 0 else { return 0 }
        var d = (reel - Double(index)).truncatingRemainder(dividingBy: Double(count))
        if d < -Double(count) / 2.0 { d += Double(count) }
        if d >= Double(count) / 2.0 { d -= Double(count) }
        return d
    }

    private func startRoll() {
        guard !isRolling, !candidates.isEmpty else { return }
        isRolling = true
        onRollingStateChanged?(true)
        GachaSounds.shared.prepare()

        let count = candidates.count
        guard count > 0 else { return }
        let targetIndex = Int.random(in: 0..<count)
        let fullRevolutions = 3
        let currentNormalized = reelPosition.truncatingRemainder(dividingBy: Double(count))
        var stepDiff = Double(targetIndex) - currentNormalized
        if stepDiff <= 0 { stepDiff += Double(count) }
        let targetReel = reelPosition + Double(fullRevolutions * count) + stepDiff
        let duration: Double = 4.0
        let startTime = ProcessInfo.processInfo.systemUptime
        let startReel = reelPosition
        var lastCrossedIndex = Int(floor(startReel))

        rollTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { t in
            let elapsed = ProcessInfo.processInfo.systemUptime - startTime
            let progress = min(1.0, elapsed / duration)

            // Cubic bezier roll easing matching Android (0.15, 0.45, 0.2, 1.0)
            let eased = cubicBezier(t: progress, p1x: 0.15, p1y: 0.45, p2x: 0.2, p2y: 1.0)
            let current = startReel + (targetReel - startReel) * eased
            self.reelPosition = current

            let currentInt = Int(floor(current))
            if currentInt != lastCrossedIndex {
                lastCrossedIndex = currentInt
                GachaSounds.shared.tick()
                self.pointerKick = 1.0
                withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) {
                    self.pointerKick = 0.0
                }
            }

            if progress >= 1.0 {
                t.invalidate()
                self.rollTimer = nil
                self.reelPosition = targetReel
                self.isRolling = false
                self.onRollingStateChanged?(false)

                let wonSong = self.candidates[targetIndex % count]
                self.landedSong = wonSong

                GachaSounds.shared.win()

                withAnimation(.spring(response: 0.35, dampingFraction: 0.45)) {
                    self.landPopScale = 1.16
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        self.landPopScale = 1.0
                    }
                }

                // Auto-play the won track with radio queue!
                self.onPlayWonTrack(wonSong, self.candidates)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.rollTimer = timer
    }

    // Cubic bezier ease-out implementation
    private func cubicBezier(t: Double, p1x: Double, p1y: Double, p2x: Double, p2y: Double) -> Double {
        let cx = 3.0 * p1x
        let bx = 3.0 * (p2x - p1x) - cx
        let ax = 1.0 - cx - bx

        let cy = 3.0 * p1y
        let by = 3.0 * (p2y - p1y) - cy
        let ay = 1.0 - cy - by

        func sampleCurveX(_ u: Double) -> Double {
            return ((ax * u + bx) * u + cx) * u
        }
        func sampleCurveY(_ u: Double) -> Double {
            return ((ay * u + by) * u + cy) * u
        }
        func sampleCurveDerivativeX(_ u: Double) -> Double {
            return (3.0 * ax * u + 2.0 * bx) * u + cx
        }

        // Newton-Raphson solve for u given t = x
        var u = t
        for _ in 0..<8 {
            let x = sampleCurveX(u) - t
            if abs(x) < 1e-4 { break }
            let d = sampleCurveDerivativeX(u)
            if abs(d) < 1e-6 { break }
            u -= x / d
        }
        return sampleCurveY(max(0, min(1.0, u)))
    }
}

// MARK: - Standard Hero Card View
public struct HeroCardView: View {
    public let card: HeroCardModel
    public let isPlaying: Bool
    public let onPlay: (SongItem) -> Void
    public let onNavigate: (SongItem) -> Void

    @State private var isHovered: Bool = false
    @State private var isPillHovered: Bool = false

    public init(
        card: HeroCardModel,
        isPlaying: Bool,
        onPlay: @escaping (SongItem) -> Void,
        onNavigate: @escaping (SongItem) -> Void
    ) {
        self.card = card
        self.isPlaying = isPlaying
        self.onPlay = onPlay
        self.onNavigate = onNavigate
    }

    public var body: some View {
        ZStack {
            // High-resolution Artwork Background
            if let thumb = card.thumbnailUrl, !thumb.isEmpty {
                CachedAsyncImage(
                    urlString: thumb.ytResize(width: 1200, height: 1200),
                    content: { image in
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipped()
                    },
                    placeholder: {
                        Color(red: 0.12, green: 0.12, blue: 0.16)
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            } else {
                LinearGradient(
                    colors: [Color(red: 0.18, green: 0.20, blue: 0.28), Color.black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            // Scrim Gradients for crisp typography
            // Top scrim for seed badge
            LinearGradient(
                stops: [
                    .init(color: Color.black.opacity(0.60), location: 0.0),
                    .init(color: Color.clear, location: 0.35)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Bottom heavy scrim for title, subtitle, and pill
            LinearGradient(
                stops: [
                    .init(color: Color.clear, location: 0.22),
                    .init(color: Color.black.opacity(0.48), location: 0.58),
                    .init(color: Color.black.opacity(0.92), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Foreground Content
            VStack(alignment: .leading, spacing: 6) {
                Spacer()

                // Seed Label Line matching Android HeroLabelLine
                let label = card.label(isPlaying: isPlaying)
                HStack(spacing: 6) {
                    Text(label.text)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.70))

                    if let seedCover = label.coverUrl, !seedCover.isEmpty {
                        CachedAsyncImage(
                            urlString: seedCover.ytResize(width: 80, height: 80),
                            content: { img in
                                if label.roundCover {
                                    img.resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 18, height: 18)
                                        .clipShape(Circle())
                                } else {
                                    img.resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 18, height: 18)
                                        .clipShape(RoundedRectangle(cornerRadius: 4.5, style: .continuous))
                                }
                            },
                            placeholder: {
                                Color.white.opacity(0.2)
                                    .frame(width: 18, height: 18)
                            }
                        )
                    }

                    if let subject = label.subject, !subject.isEmpty {
                        Text(subject)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color.white.opacity(0.92))
                            .lineLimit(1)
                    }
                }

                // Main Title
                Text(card.title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .shadow(color: Color.black.opacity(0.7), radius: 10, x: 0, y: 4)

                // Subtitle
                if !card.subtitle.isEmpty {
                    Text(card.subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.78))
                        .lineLimit(1)
                        .shadow(color: Color.black.opacity(0.6), radius: 6, x: 0, y: 2)
                }

                Spacer().frame(height: 5)

                // Pill Action Button matching Android Mochy HeroPill
                Button(action: {
                    handlePillClick()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: pillIcon)
                            .font(.system(size: 13, weight: .bold))

                        Text(pillText)
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(Color(red: 0.18, green: 0.18, blue: 0.18))
                    .padding(.horizontal, 20)
                    .frame(height: 34)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.68))
                    )
                    .scaleEffect(isPillHovered ? 1.04 : 1.0)
                }
                .buttonStyle(.plain)
                .onHover { isPillHovered = $0 }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 26)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 8)
        .onHover { isHovered = $0 }
    }

    private var pillIcon: String {
        switch card.kind {
        case .playlist, .album:
            return "arrow.up.right"
        default:
            return isPlaying ? "pause.fill" : "play.fill"
        }
    }

    private var pillText: String {
        switch card.kind {
        case .playlist, .album:
            return "View"
        default:
            return isPlaying ? "Pause" : "Play"
        }
    }

    private func handlePillClick() {
        guard let song = card.songItem else { return }
        switch card.kind {
        case .playlist, .album:
            onNavigate(song)
        default:
            onPlay(song)
        }
    }
}

// MARK: - Hero Carousel Main Container
public struct HeroCarouselView: View {
    public let cards: [HeroCardModel]
    public let gachaCandidates: [SongItem]
    public let currentPlayingTrackId: String?
    public let isAudioPlaying: Bool
    public let onPlaySong: (SongItem, [SongItem]) -> Void
    public let onTogglePauseResume: () -> Void
    public let onNavigateCollection: (SongItem) -> Void

    @State private var activeCardId: String?
    @State private var isCarouselHovered: Bool = false
    @State private var isGachaRolling: Bool = false
    @State private var autoAdvanceTimer: Timer?

    public init(
        cards: [HeroCardModel],
        gachaCandidates: [SongItem],
        currentPlayingTrackId: String?,
        isAudioPlaying: Bool,
        onPlaySong: @escaping (SongItem, [SongItem]) -> Void,
        onTogglePauseResume: @escaping () -> Void,
        onNavigateCollection: @escaping (SongItem) -> Void
    ) {
        self.cards = cards
        self.gachaCandidates = gachaCandidates
        self.currentPlayingTrackId = currentPlayingTrackId
        self.isAudioPlaying = isAudioPlaying
        self.onPlaySong = onPlaySong
        self.onTogglePauseResume = onTogglePauseResume
        self.onNavigateCollection = onNavigateCollection
    }

    private var currentIndex: Int {
        guard let activeCardId else { return 0 }
        return cards.firstIndex(where: { $0.id == activeCardId }) ?? 0
    }

    public var body: some View {
        guard !cards.isEmpty else { return AnyView(EmptyView()) }

        return AnyView(
            GeometryReader { proxy in
                let totalW = proxy.size.width
                // Card width: ~80% of screen width, bounded nicely on desktop
                let cardW = min(max(totalW * 0.80, 520), 960)
                let cardH: CGFloat = 370
                let cardSpacing: CGFloat = 16.0
                let sideInset = max(0, (totalW - cardW) / 2.0)
                let containerH: CGFloat = 418

                ScrollViewReader { scrollProxy in
                    ZStack(alignment: .top) {
                        VStack(spacing: 12) {
                            // Native macOS Horizontal ScrollView with ViewAligned snapping
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: cardSpacing) {
                                    ForEach(cards) { card in
                                        Group {
                                            if card.kind == .gacha {
                                                GachaCardView(
                                                    candidates: gachaCandidates,
                                                    isAudioPlaying: isAudioPlaying,
                                                    currentPlayingTrackId: currentPlayingTrackId,
                                                    onPlayWonTrack: { wonSong, pool in
                                                        onPlaySong(wonSong, pool)
                                                    },
                                                    onRollingStateChanged: { rolling in
                                                        self.isGachaRolling = rolling
                                                    }
                                                )
                                            } else {
                                                let isThisCardPlaying = isAudioPlaying && (card.songItem?.id == currentPlayingTrackId)
                                                HeroCardView(
                                                    card: card,
                                                    isPlaying: isThisCardPlaying,
                                                    onPlay: { song in
                                                        if card.songItem?.id == currentPlayingTrackId {
                                                            onTogglePauseResume()
                                                        } else {
                                                            onPlaySong(song, [song])
                                                        }
                                                    },
                                                    onNavigate: { song in
                                                        onNavigateCollection(song)
                                                    }
                                                )
                                            }
                                        }
                                        .frame(width: cardW, height: cardH)
                                        .id(card.id)
                                    }
                                }
                                .scrollTargetLayout()
                            }
                            .scrollTargetBehavior(.viewAligned)
                            .safeAreaPadding(.horizontal, sideInset)
                            .scrollPosition(id: $activeCardId)
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 25)
                                    .onEnded { value in
                                        if value.translation.width < -40 {
                                            advanceNext(proxy: scrollProxy)
                                        } else if value.translation.width > 40 {
                                            advancePrev(proxy: scrollProxy)
                                        }
                                    }
                            )

                            // Bottom Capsule Page Indicators
                            HStack(spacing: 6) {
                                ForEach(0..<cards.count, id: \.self) { idx in
                                    Capsule()
                                        .fill(idx == currentIndex ? Color.white : Color.white.opacity(0.35))
                                        .frame(width: idx == currentIndex ? 24 : 6, height: 6)
                                        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: currentIndex)
                                        .onTapGesture {
                                            let targetId = cards[idx].id
                                            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                                                activeCardId = targetId
                                                scrollProxy.scrollTo(targetId, anchor: .center)
                                            }
                                        }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.35))
                            .clipShape(Capsule())
                        }

                        // Desktop Navigation Chevrons
                        if isCarouselHovered && cards.count > 1 {
                            HStack {
                                if currentIndex > 0 {
                                    Button(action: {
                                        advancePrev(proxy: scrollProxy)
                                    }) {
                                        Image(systemName: "chevron.left")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(width: 40, height: 40)
                                            .background(.ultraThinMaterial)
                                            .clipShape(Circle())
                                            .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                                            .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 4)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.leading, max(14, sideInset - 22))
                                }

                                Spacer()

                                if currentIndex < cards.count - 1 {
                                    Button(action: {
                                        advanceNext(proxy: scrollProxy)
                                    }) {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(width: 40, height: 40)
                                            .background(.ultraThinMaterial)
                                            .clipShape(Circle())
                                            .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                                            .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 4)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.trailing, max(14, sideInset - 22))
                                }
                            }
                            .frame(height: cardH)
                            .transition(.opacity)
                        }
                    }
                    .frame(width: totalW, height: containerH)
                    .onHover { hovering in
                        isCarouselHovered = hovering
                    }
                    .onAppear {
                        if activeCardId == nil {
                            activeCardId = cards.first?.id
                        }
                        startAutoAdvance(proxy: scrollProxy)
                    }
                    .onDisappear {
                        stopAutoAdvance()
                    }
                }
            }
            .frame(height: 418)
        )
    }

    private func advanceNext(proxy: ScrollViewProxy) {
        guard !cards.isEmpty else { return }
        let nextIdx = (currentIndex + 1) % cards.count
        let nextId = cards[nextIdx].id
        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
            activeCardId = nextId
            proxy.scrollTo(nextId, anchor: .center)
        }
    }

    private func advancePrev(proxy: ScrollViewProxy) {
        guard currentIndex > 0 else { return }
        let prevId = cards[currentIndex - 1].id
        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
            activeCardId = prevId
            proxy.scrollTo(prevId, anchor: .center)
        }
    }

    private func startAutoAdvance(proxy: ScrollViewProxy) {
        stopAutoAdvance()
        autoAdvanceTimer = Timer.scheduledTimer(withTimeInterval: 5.5, repeats: true) { _ in
            // Keep card still while music is actively playing, gacha is rolling, or user is hovering
            guard !isCarouselHovered, !isGachaRolling, !isAudioPlaying, cards.count > 1 else { return }
            advanceNext(proxy: proxy)
        }
    }

    private func stopAutoAdvance() {
        autoAdvanceTimer?.invalidate()
        autoAdvanceTimer = nil
    }
}

// MARK: - Hero Carousel Data Assembler
public func buildHeroCards(
    history: [SongItem],
    liked: [SongItem],
    sections: [HomeSection],
    currentTrack: SongItem?,
    isPlaying: Bool
) -> [HeroCardModel] {
    var result: [HeroCardModel] = []
    var seenMediaIds = Set<String>()

    // 1. Keep Listening / Now Playing / Continue (Card 0)
    if let current = currentTrack {
        seenMediaIds.insert(current.id)
        result.append(
            HeroCardModel(
                id: "now_playing_\(current.id)",
                title: current.title,
                subtitle: current.artist,
                thumbnailUrl: current.thumbnail,
                kind: .keepListening(isLastPlayed: false),
                songItem: current,
                initialLabel: HeroLabel(text: isPlaying ? "Now playing" : "Continue")
            )
        )
    } else if let lastPlayed = history.first {
        seenMediaIds.insert(lastPlayed.id)
        result.append(
            HeroCardModel(
                id: "continue_\(lastPlayed.id)",
                title: lastPlayed.title,
                subtitle: lastPlayed.artist,
                thumbnailUrl: lastPlayed.thumbnail,
                kind: .keepListening(isLastPlayed: true),
                songItem: lastPlayed,
                initialLabel: HeroLabel(text: "Continue")
            )
        )
    }

    // 2. Gacha Card ("Gacha here! / Random plays") placed right after the first card
    let gachaCandidatesPool = buildGachaCandidates(history: history, liked: liked, sections: sections)
    if gachaCandidatesPool.count >= 2 {
        result.append(
            HeroCardModel(
                id: "hero_gacha_card",
                title: "Random plays",
                subtitle: "",
                thumbnailUrl: nil,
                kind: .gacha,
                songItem: nil,
                initialLabel: HeroLabel(text: "Gacha here!")
            )
        )
    }

    // 3. Recommendation cards from Home shelves with contextual seed labels
    let sampleLiked = liked.shuffled()
    var likedIndex = 0

    for section in sections {
        for item in section.items {
            guard !seenMediaIds.contains(item.id), item.thumbnail != nil else { continue }

            if item.kind == .song {
                seenMediaIds.insert(item.id)

                let seedLabel: HeroLabel
                if likedIndex < sampleLiked.count {
                    let seed = sampleLiked[likedIndex]
                    likedIndex += 1
                    let reasons = ["Because you like", "Similar to", "Inspired by", "More from"]
                    let pickReason = reasons[result.count % reasons.count]
                    seedLabel = HeroLabel(
                        text: pickReason,
                        coverUrl: seed.thumbnail,
                        subject: pickReason == "More from" ? seed.artist : seed.title,
                        roundCover: pickReason == "More from"
                    )
                } else if let secLabel = section.label, !secLabel.isEmpty {
                    seedLabel = HeroLabel(text: secLabel)
                } else {
                    seedLabel = HeroLabel(text: "You may also like")
                }

                result.append(
                    HeroCardModel(
                        id: "rec_\(item.id)",
                        title: item.title,
                        subtitle: item.artist,
                        thumbnailUrl: item.thumbnail,
                        kind: .discover(reason: seedLabel.text),
                        songItem: item,
                        initialLabel: seedLabel
                    )
                )

                if result.count >= 7 { break }
            } else if item.kind == .album || item.kind == .playlist {
                seenMediaIds.insert(item.id)
                result.append(
                    HeroCardModel(
                        id: "collection_\(item.id)",
                        title: item.title,
                        subtitle: item.artist.isEmpty ? (item.kind == .album ? "Album" : "Playlist") : item.artist,
                        thumbnailUrl: item.thumbnail,
                        kind: item.kind == .album ? .album : .playlist,
                        songItem: item,
                        initialLabel: HeroLabel(text: item.kind == .album ? "Album pick" : "Featured playlist")
                    )
                )

                if result.count >= 8 { break }
            }
        }
        if result.count >= 8 { break }
    }

    // 4. Fill with History / Liked fallback if needed
    if result.count < 3 {
        for song in liked where !seenMediaIds.contains(song.id) {
            seenMediaIds.insert(song.id)
            result.append(
                HeroCardModel(
                    id: "liked_\(song.id)",
                    title: song.title,
                    subtitle: song.artist,
                    thumbnailUrl: song.thumbnail,
                    kind: .keepListening(isLastPlayed: false),
                    songItem: song,
                    initialLabel: HeroLabel(text: "On repeat")
                )
            )
            if result.count >= 5 { break }
        }
    }

    return result
}

public func buildGachaCandidates(
    history: [SongItem],
    liked: [SongItem],
    sections: [HomeSection]
) -> [SongItem] {
    var pool: [SongItem] = []
    var seen = Set<String>()

    for song in (history + liked) where song.thumbnail != nil && !song.thumbnail!.isEmpty {
        if !seen.contains(song.id) {
            seen.insert(song.id)
            pool.append(song)
        }
    }

    for section in sections {
        for item in section.items where item.kind == .song && item.thumbnail != nil && !item.thumbnail!.isEmpty {
            if !seen.contains(item.id) {
                seen.insert(item.id)
                pool.append(item)
            }
        }
    }

    return Array(pool.shuffled().prefix(10))
}

import SwiftUI

@MainActor public struct TurntableCanvas: View {
    let thumbnail: String?
    let title: String
    let isPlaying: Bool
    let progress: Double
    var incomingThumbnail: String? = nil
    var incomingTitle: String? = nil
    var transitionProgress: Double = 0.0
    var onSeek: ((Double) -> Void)? = nil

    @State private var dragFraction: Double?
    @State private var dragActive = false
    @State private var baseAngle: Double = 0.0
    @State private var playStartDate: Date? = nil
    @State private var pauseStartDate: Date? = nil
    @State private var pauseStartAngle: Double = 0.0

    // ponytail: matches Android DiscCoverStack SpinDegreesPerSecond = 26f (13.85s per rev)
    private let spinDegreesPerSecond: Double = 26.0
    private let coastDuration: Double = 1.3

    private let vinylBlack = Color(red: 9/255, green: 9/255, blue: 10/255)
    private let trackGaps: [CGFloat] = [0.665, 0.745, 0.83, 0.905]

    private let armRestDegrees: Double = 77.5
    private let armLeadInDegrees: Double = 92.5
    private let armRunOutDegrees: Double = 112.0

    private var isCoasting: Bool {
        !isPlaying && pauseStartDate != nil && (Date().timeIntervalSince(pauseStartDate!) < coastDuration)
    }

    nonisolated public static func calculateArmGlideAngle(from start: Double, to end: Double, elapsed: Double, duration: Double) -> Double {
        guard duration > 0 else { return end }
        let p = min(max(elapsed / duration, 0.0), 1.0)
        let ease = p * p * (3.0 - 2.0 * p)
        return start + (end - start) * ease
    }

    nonisolated public static func calculateArmDropAngle(from start: Double, to end: Double, elapsed: Double, duration: Double) -> Double {
        guard duration > 0 else { return end }
        let p = min(max(elapsed / duration, 0.0), 1.0)
        let ease = 1.0 - pow(1.0 - p, 3.0)
        return start + (end - start) * ease
    }

    private func currentAngle(at date: Date) -> Double {
        if isPlaying, let start = playStartDate {
            let elapsed = max(0, date.timeIntervalSince(start))
            return (baseAngle + elapsed * spinDegreesPerSecond).truncatingRemainder(dividingBy: 360.0)
        } else if let pStart = pauseStartDate {
            let t = min(max(date.timeIntervalSince(pStart), 0.0), coastDuration)
            let coastElapsed = spinDegreesPerSecond * (t - (t * t) / (2.0 * coastDuration))
            return (pauseStartAngle + coastElapsed).truncatingRemainder(dividingBy: 360.0)
        } else {
            return baseAngle
        }
    }

    public init(thumbnail: String?, title: String, isPlaying: Bool, progress: Double, incomingThumbnail: String? = nil, incomingTitle: String? = nil, transitionProgress: Double = 0.0, onSeek: ((Double) -> Void)? = nil) {
        self.onSeek = onSeek
        self.thumbnail = thumbnail
        self.title = title
        self.isPlaying = isPlaying
        self.progress = progress
        self.incomingThumbnail = incomingThumbnail
        self.incomingTitle = incomingTitle
        self.transitionProgress = transitionProgress
    }

    private var targetDeg: Double {
        if let drag = dragFraction {
            return armLeadInDegrees + drag * (armRunOutDegrees - armLeadInDegrees)
        }
        guard isPlaying else { return armRestDegrees }
        if transitionProgress > 0 {
            let currentArm = armLeadInDegrees + progress * (armRunOutDegrees - armLeadInDegrees)
            return currentArm * (1.0 - transitionProgress) + armLeadInDegrees * transitionProgress
        }
        return armLeadInDegrees + progress * (armRunOutDegrees - armLeadInDegrees)
    }

    private var armHighlightOpacity: Double {
        dragActive ? 0.3 : 0.0
    }

    private var armAnimation: Animation? {
        if dragActive { return nil }
        if isPlaying {
            return .spring(response: 1.25, dampingFraction: 0.86)
        } else {
            return .easeInOut(duration: 1.4)
        }
    }

    public var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: side * 0.44, y: side * 0.50)
            let radius = side * 0.41

            let pivot = CGPoint(x: side * 0.84, y: side * 0.14)

            ZStack {
                // Tonearm drag gesture overlay (invisible, on top)
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let local = value.location
                                let dx = local.x - pivot.x
                                let dy = local.y - pivot.y
                                let angle = atan2(dy, dx) * 180.0 / .pi
                                let deg = angle >= 0 ? angle : angle + 360.0
                                let leadIn = armLeadInDegrees
                                let runOut = armRunOutDegrees
                                let fraction = min(max((deg - leadIn) / (runOut - leadIn), 0.0), 1.0)
                                dragFraction = fraction
                                dragActive = true
                                onSeek?(fraction)
                            }
                            .onEnded { _ in
                                dragActive = false
                                dragFraction = nil
                            }
                    )
                    .frame(width: side, height: side)

                // Base deck slab under arm pivot and arm cradle
                Canvas { ctx, size in
                    drawArmBase(ctx: ctx, side: size.width)
                }

                // Platter drop shadow
                Circle()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: .black.opacity(0.65), location: 0.86),
                                .init(color: .clear, location: 1.0)
                            ],
                            center: .center,
                            startRadius: radius * 0.7,
                            endRadius: radius * 1.08
                        )
                    )
                    .frame(width: radius * 2, height: radius * 2)
                    .position(center)
                    .blur(radius: 12)

                // Vinyl disc with track grooves
                Canvas { ctx, size in
                    drawVinyl(ctx: ctx, side: size.width)
                }
                .frame(width: radius * 2, height: radius * 2)
                .position(center)
                .rotationEffect(.degrees(currentAngle(at: Date())))
                .animation(armAnimation, value: targetDeg)

                // Label on vinyl
                if let thumb = thumbnail, !thumb.isEmpty, let url = URL(string: thumb) {
                    AsyncImage(url: url) { phase in
                        if let img = phase.image {
                            img.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Color.gray.opacity(0.3)
                        }
                    }
                    .frame(width: radius * 0.62, height: radius * 0.62)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.black.opacity(0.3), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                    .position(center)
                } else {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(white: 0.18), Color(white: 0.12)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: radius * 0.62, height: radius * 0.62)
                        .overlay(Circle().stroke(Color.black.opacity(0.3), lineWidth: 0.5))
                        .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                        .position(center)
                }

                // Spindle
                Circle()
                    .fill(Color.black)
                    .frame(width: 8, height: 8)
                    .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                    .position(center)

                // Tonearm
                TonearmView(
                    angleDeg: targetDeg,
                    pivot: pivot,
                    side: side,
                    isShadow: false,
                    highlightOpacity: armHighlightOpacity,
                    armRestDegrees: armRestDegrees,
                    armLeadInDegrees: armLeadInDegrees,
                    armRunOutDegrees: armRunOutDegrees
                )

                // Tonearm shadow
                TonearmView(
                    angleDeg: targetDeg,
                    pivot: pivot,
                    side: side,
                    isShadow: true,
                    highlightOpacity: 0,
                    armRestDegrees: armRestDegrees,
                    armLeadInDegrees: armLeadInDegrees,
                    armRunOutDegrees: armRunOutDegrees
                )
                .offset(x: side * 0.008, y: side * 0.012)
                .blur(radius: 2)

                // Nameplate ring around vinyl
                NamePlateRing(title: title, radius: radius * 1.08)
                    .position(center)
            }
            .frame(width: side, height: side)
            .onAppear {
                if isPlaying, playStartDate == nil {
                    playStartDate = Date()
                    baseAngle = 0
                }
            }
            .onChange(of: isPlaying) { _, newVal in
                if newVal {
                    playStartDate = Date()
                    baseAngle = currentAngle(at: Date())
                    pauseStartDate = nil
                } else {
                    pauseStartDate = Date()
                    pauseStartAngle = currentAngle(at: Date())
                    playStartDate = nil
                }
            }
            .onChange(of: transitionProgress) { _, newVal in
                if newVal >= 1.0 {
                    baseAngle = currentAngle(at: Date())
                }
            }
        }
    }

    private func drawArmBase(ctx: GraphicsContext, side: CGFloat) {
        let u = side * 0.54
        let pivotX = side * 0.84
        let pivotY = side * 0.14

        // Arm rest cradle
        let cradleRect = CGRect(x: pivotX + 0.15 * u, y: pivotY - 0.03 * u, width: 0.16 * u, height: 0.07 * u)
        let cradlePath = Path(roundedRect: cradleRect, cornerRadius: 0.012 * u)
        ctx.fill(cradlePath, with: .color(Color(white: 0.10)))
        ctx.stroke(cradlePath, with: .color(.white.opacity(0.1)), lineWidth: 0.5)

        // Pivot base plate
        let baseRect = CGRect(x: pivotX - 0.06 * u, y: pivotY - 0.06 * u, width: 0.12 * u, height: 0.12 * u)
        let basePath = Path(ellipseIn: baseRect)
        ctx.fill(basePath, with: .color(Color(white: 0.09)))
        ctx.stroke(basePath, with: .color(.white.opacity(0.08)), lineWidth: 0.5)
    }

    private func drawVinyl(ctx: GraphicsContext, side: CGFloat) {
        let center = CGPoint(x: side / 2, y: side / 2)
        let radius = side * 0.41

        // Vinyl base
        let vinylPath = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        ctx.fill(vinylPath, with: .color(vinylBlack))

        // Groove tracks
        for gap in trackGaps {
            let trackPath = Path(ellipseIn: CGRect(
                x: center.x - radius * gap,
                y: center.y - radius * gap,
                width: radius * 2 * gap,
                height: radius * 2 * gap
            ))
            ctx.stroke(trackPath, with: .color(Color(white: 0.18)), style: StrokeStyle(lineWidth: 0.4, dash: [2, 6]))
        }

        // Center label area
        let labelRadius = radius * 0.34
        let labelPath = Path(ellipseIn: CGRect(x: center.x - labelRadius, y: center.y - labelRadius, width: labelRadius * 2, height: labelRadius * 2))
        ctx.fill(labelPath, with: .color(Color(white: 0.10)))
    }

    private struct TonearmView: View {
        let angleDeg: Double
        let pivot: CGPoint
        let side: CGFloat
        let isShadow: Bool
        let highlightOpacity: Double
        let armRestDegrees: Double
        let armLeadInDegrees: Double
        let armRunOutDegrees: Double

        var body: some View {
            Canvas { ctx, size in
                let armScale = side * 0.54
                let armLen = 0.45 * armScale

                var armCtx = ctx
                armCtx.translateBy(x: pivot.x, y: pivot.y)
                armCtx.rotate(by: .degrees(angleDeg))

                // Arm tube (straight portion)
                let tubeFrom = 0.02 * armScale
                let tubeTo = armLen - 0.07 * armScale
                let tubeHalf = 0.015 * armScale

                let tubePath = Path(CGRect(x: tubeFrom, y: -tubeHalf, width: tubeTo - tubeFrom, height: tubeHalf * 2))
                if isShadow {
                    armCtx.fill(tubePath, with: .color(.black.opacity(0.4)))
                } else {
                    armCtx.fill(tubePath, with: .linearGradient(
                        Gradient(colors: [
                            Color(white: 0.35), Color(white: 0.55), Color(white: 0.75), Color(white: 0.85), Color(white: 0.60), Color(white: 0.35)
                        ]),
                        startPoint: CGPoint(x: 0, y: -tubeHalf),
                        endPoint: CGPoint(x: 0, y: tubeHalf)
                    ))
                    if highlightOpacity > 0 {
                        armCtx.fill(tubePath, with: .color(.white.opacity(highlightOpacity)))
                    }
                }

                // Pivot block & counterweight
                let blockRect = CGRect(x: -0.052 * armScale, y: -0.058 * armScale, width: 0.094 * armScale, height: 0.146 * armScale)
                let blockPath = Path(roundedRect: blockRect, cornerRadius: 0.012 * armScale)
                if isShadow {
                    armCtx.fill(blockPath, with: .color(.black.opacity(0.5)))
                } else {
                    armCtx.fill(blockPath, with: .color(Color(white: 0.16)))
                    armCtx.stroke(blockPath, with: .color(.white.opacity(0.15)), lineWidth: 1)
                }

                // Counterweight cap
                let capRect = CGRect(x: -0.10 * armScale, y: -0.026 * armScale, width: 0.06 * armScale, height: 0.084 * armScale)
                let capPath = Path(roundedRect: capRect, cornerRadius: 0.01 * armScale)
                if isShadow {
                    armCtx.fill(capPath, with: .color(.black.opacity(0.5)))
                } else {
                    armCtx.fill(capPath, with: .color(Color(white: 0.20)))
                }

                // Headshell with 27-degree bend
                var headCtx = armCtx
                headCtx.translateBy(x: armLen, y: 0)
                headCtx.rotate(by: .degrees(27))

                let shellRect = CGRect(x: -0.014 * armScale, y: -0.032 * armScale, width: 0.145 * armScale, height: 0.064 * armScale)
                let shellPath = Path(roundedRect: shellRect, cornerRadius: 0.009 * armScale)

                // Cartridge body underneath headshell
                let cartRect = CGRect(x: 0.025 * armScale, y: -0.020 * armScale, width: 0.095 * armScale, height: 0.040 * armScale)
                let cartPath = Path(roundedRect: cartRect, cornerRadius: 0.004 * armScale)

                if isShadow {
                    headCtx.fill(shellPath, with: .color(.black.opacity(0.5)))
                    headCtx.fill(cartPath, with: .color(.black.opacity(0.4)))
                } else {
                    // Headshell metal body
                    headCtx.fill(shellPath, with: .linearGradient(
                        Gradient(colors: [Color(white: 0.22), Color(white: 0.14), Color(white: 0.09)]),
                        startPoint: CGPoint(x: -0.014 * armScale, y: -0.032 * armScale),
                        endPoint: CGPoint(x: 0.131 * armScale, y: 0.032 * armScale)
                    ))
                    headCtx.stroke(shellPath, with: .color(.white.opacity(0.18)), lineWidth: 1)

                    // Premium crimson red cartridge body
                    headCtx.fill(cartPath, with: .linearGradient(
                        Gradient(colors: [Color(red: 0.85, green: 0.18, blue: 0.22), Color(red: 0.55, green: 0.10, blue: 0.12)]),
                        startPoint: CGPoint(x: 0.025 * armScale, y: -0.020 * armScale),
                        endPoint: CGPoint(x: 0.120 * armScale, y: 0.020 * armScale)
                    ))
                    headCtx.stroke(cartPath, with: .color(Color.black.opacity(0.35)), lineWidth: 0.5)

                    // Stylus Cantilever
                    var needlePath = Path()
                    needlePath.move(to: CGPoint(x: 0.110 * armScale, y: 0.0))
                    needlePath.addLine(to: CGPoint(x: 0.128 * armScale, y: 0.002 * armScale))
                    headCtx.stroke(needlePath, with: .color(Color(white: 0.85)), style: StrokeStyle(lineWidth: 0.006 * armScale, lineCap: .round))

                    // Diamond tip dot
                    let tipDot = CGRect(x: 0.126 * armScale, y: -0.003 * armScale, width: 0.006 * armScale, height: 0.006 * armScale)
                    headCtx.fill(Path(ellipseIn: tipDot), with: .color(.white))

                    // Finger lift
                    var liftPath = Path()
                    liftPath.move(to: CGPoint(x: 0.112 * armScale, y: -0.024 * armScale))
                    liftPath.addLine(to: CGPoint(x: 0.127 * armScale, y: -0.067 * armScale))
                    headCtx.stroke(liftPath, with: .color(Color(white: 0.70)), style: StrokeStyle(lineWidth: 0.0105 * armScale, lineCap: .round))
                }
            }
        }
    }

    private struct NamePlateRing: View {
        let title: String
        let radius: CGFloat

        var body: some View {
            Canvas { ctx, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let formatted = (title.trimmingCharacters(in: .whitespaces).uppercased() + "  ·  ")
                let characters = Array(formatted)
                let count = max(characters.count, 1)
                let step = 360.0 / Double(count)

                for (i, ch) in characters.enumerated() {
                    var letterCtx = ctx
                    let angle = Angle.degrees(Double(i) * step)
                    letterCtx.translateBy(x: center.x, y: center.y)
                    letterCtx.rotate(by: angle)
                    letterCtx.translateBy(x: 0, y: -radius)

                    let text = Text(String(ch))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.35))
                    letterCtx.draw(text, at: .zero)
                }
            }
            .frame(width: radius * 2.2, height: radius * 2.2)
        }
    }
}

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

    // ponytail: matches Android DiscCoverStack SpinDegreesPerSecond = 26f (13.85s per rev)
    private let spinDegreesPerSecond: Double = 26.0

    private let vinylBlack = Color(red: 9/255, green: 9/255, blue: 10/255)
    private let trackGaps: [CGFloat] = [0.665, 0.745, 0.83, 0.905]

    private let armRestDegrees: Double = 80.5
    private let armLeadInDegrees: Double = 92.5
    private let armRunOutDegrees: Double = 112.0

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

    private var armDeg: Double {
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

    public var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: side * 0.44, y: side * 0.50)
            let radius = side * 0.41

            let pivot = CGPoint(x: side * 0.84, y: side * 0.14)
            let u = side * 0.54
            let targetDeg = armDeg

            ZStack {
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
                    .frame(width: radius * 2.1, height: radius * 2.1)
                    .position(x: center.x, y: center.y + radius * 0.035)

                // Stationary Platter with Sheen Reflections and Grooves
                Canvas { ctx, _ in
                    drawPlatter(ctx: ctx, center: center, radius: radius)
                }

                // Turning Center Label (Artwork) at 26 deg/sec matching Android DiscCoverStack
                TimelineView(.animation(paused: !isPlaying)) { timeline in
                    let elapsed = (isPlaying && playStartDate != nil) ? max(0, timeline.date.timeIntervalSince(playStartDate!)) : 0
                    let angle = (baseAngle + elapsed * spinDegreesPerSecond).truncatingRemainder(dividingBy: 360.0)

                    ZStack {
                        let labelSize = radius * 0.88

                        ZStack {
                            if let thumbnail {
                                CachedAsyncImage(urlString: thumbnail) { img in
                                    img.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Color(red: 0.12, green: 0.12, blue: 0.14)
                                }
                                .opacity(1.0 - transitionProgress)
                            } else {
                                Color(red: 0.12, green: 0.12, blue: 0.14)
                                    .opacity(1.0 - transitionProgress)
                            }

                            if let incomingThumbnail {
                                CachedAsyncImage(urlString: incomingThumbnail) { img in
                                    img.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Color.clear
                                }
                                .opacity(transitionProgress)
                            }
                        }
                        .frame(width: labelSize, height: labelSize)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                        .rotationEffect(.degrees(angle))

                        // Soft Paper Lighting Overlay (Directional highlight + vignette rim, no spindle hole)
                        Circle()
                            .fill(
                                RadialGradient(
                                    stops: [
                                        .init(color: .white.opacity(0.12), location: 0.0),
                                        .init(color: .clear, location: 1.0)
                                    ],
                                    center: UnitPoint(x: 0.35, y: 0.30),
                                    startRadius: 0,
                                    endRadius: labelSize * 0.55
                                )
                            )
                            .frame(width: labelSize, height: labelSize)

                        Circle()
                            .stroke(
                                RadialGradient(
                                    stops: [
                                        .init(color: .clear, location: 0.80),
                                        .init(color: .black.opacity(0.45), location: 1.0)
                                    ],
                                    center: .center,
                                    startRadius: labelSize * 0.35,
                                    endRadius: labelSize * 0.50
                                ),
                                lineWidth: labelSize * 0.12
                            )
                            .frame(width: labelSize, height: labelSize)

                        // Circular Nameplate text on run-out ring
                        ZStack {
                            if !title.isEmpty {
                                NamePlateRing(title: title, radius: radius * 0.52)
                                    .opacity(1.0 - transitionProgress)
                            }
                            if let incomingTitle, !incomingTitle.isEmpty {
                                NamePlateRing(title: incomingTitle, radius: radius * 0.52)
                                    .opacity(transitionProgress)
                            }
                        }
                        .rotationEffect(.degrees(angle))
                    }
                    .position(center)
                }

                // Brushed Aluminium Tonearm with Cartridge and Arm Cradle
                Canvas { ctx, _ in
                    // Arm shadow
                    drawTonearm(
                        ctx: ctx,
                        pivot: CGPoint(x: pivot.x + side * 0.015, y: pivot.y + side * 0.02),
                        degrees: targetDeg,
                        u: u,
                        isShadow: true
                    )
                    // Arm metal body
                    drawTonearm(
                        ctx: ctx,
                        pivot: pivot,
                        degrees: targetDeg,
                        u: u,
                        isShadow: false
                    )
                }
                .animation(dragActive ? nil : .spring(response: 0.72, dampingFraction: 0.84), value: targetDeg)
            }
            .frame(width: side, height: side)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        guard onSeek != nil else { return }
                        if !dragActive {
                            let rad = armDeg * .pi / 180
                            let len = u * 0.876
                            let tip = CGPoint(x: pivot.x + len * cos(rad), y: pivot.y + len * sin(rad))
                            guard hypot(v.startLocation.x - tip.x, v.startLocation.y - tip.y) < side * 0.16 else { return }
                            dragActive = true
                        }
                        let deg = atan2(v.location.y - pivot.y, v.location.x - pivot.x) * 180 / .pi
                        dragFraction = min(max((deg - armLeadInDegrees) / (armRunOutDegrees - armLeadInDegrees), 0), 1)
                    }
                    .onEnded { _ in
                        if dragActive, let f = dragFraction { onSeek?(f) }
                        dragActive = false
                        dragFraction = nil
                    }
            )
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            .onAppear {
                if isPlaying && playStartDate == nil {
                    playStartDate = Date()
                }
            }
            .onChange(of: isPlaying) { _, playing in
                if playing {
                    playStartDate = Date()
                } else {
                    if let start = playStartDate {
                        baseAngle = (baseAngle + max(0, Date().timeIntervalSince(start)) * spinDegreesPerSecond).truncatingRemainder(dividingBy: 360.0)
                    }
                    playStartDate = nil
                }
            }
        }
    }

    private func drawArmBase(ctx: GraphicsContext, side: CGFloat) {
        let left = side * 0.76
        let top = side * 0.04
        let width = side * 0.18
        let height = side * 0.46
        let round = side * 0.08
        let rect = CGRect(x: left, y: top, width: width, height: height)
        let path = Path(roundedRect: rect, cornerRadius: round)

        for i in 1...4 {
            let grow = side * 0.007 * CGFloat(i)
            let shadowRect = rect.insetBy(dx: -grow, dy: -grow).offsetBy(dx: side * 0.006, dy: side * 0.014)
            ctx.fill(Path(roundedRect: shadowRect, cornerRadius: round + grow), with: .color(.black.opacity(0.08)))
        }

        // Deck plate
        ctx.fill(path, with: .linearGradient(
            Gradient(colors: [Color(white: 0.13), Color(white: 0.08), Color(white: 0.05)]),
            startPoint: CGPoint(x: left, y: top),
            endPoint: CGPoint(x: left + width, y: top + height)
        ))

        ctx.stroke(path, with: .linearGradient(
            Gradient(stops: [
                .init(color: .white.opacity(0.18), location: 0),
                .init(color: .white.opacity(0.04), location: 0.4),
                .init(color: .clear, location: 1)
            ]),
            startPoint: CGPoint(x: left, y: top),
            endPoint: CGPoint(x: left + width, y: top + height * 0.6)
        ), lineWidth: 1)

        // Pivot Gimbal Ring
        let pX = side * 0.84
        let pY = side * 0.14
        let ringR = side * 0.045
        let ringRect = CGRect(x: pX - ringR, y: pY - ringR, width: ringR * 2, height: ringR * 2)
        ctx.fill(Path(ellipseIn: ringRect), with: .linearGradient(
            Gradient(colors: [Color(white: 0.28), Color(white: 0.15), Color(white: 0.08)]),
            startPoint: CGPoint(x: ringRect.minX, y: ringRect.minY),
            endPoint: CGPoint(x: ringRect.maxX, y: ringRect.maxY)
        ))
        ctx.stroke(Path(ellipseIn: ringRect), with: .color(.white.opacity(0.20)), lineWidth: 1)

        // Arm Rest Cradle Stand (Holds tonearm when parked outside record)
        let cradleX = side * 0.865
        let cradleY = side * 0.38
        let postR = side * 0.016
        let postRect = CGRect(x: cradleX - postR, y: cradleY - postR, width: postR * 2, height: postR * 2)
        ctx.fill(Path(ellipseIn: postRect), with: .color(Color(white: 0.25)))
        ctx.stroke(Path(ellipseIn: postRect), with: .color(.white.opacity(0.25)), lineWidth: 1)

        // U-shaped rest cradle
        var uPath = Path()
        uPath.move(to: CGPoint(x: cradleX - postR * 1.5, y: cradleY - postR * 0.8))
        uPath.addLine(to: CGPoint(x: cradleX - postR * 1.5, y: cradleY + postR * 0.5))
        uPath.addQuadCurve(to: CGPoint(x: cradleX + postR * 1.5, y: cradleY + postR * 0.5), control: CGPoint(x: cradleX, y: cradleY + postR * 1.4))
        uPath.addLine(to: CGPoint(x: cradleX + postR * 1.5, y: cradleY - postR * 0.8))
        ctx.stroke(uPath, with: .color(Color(white: 0.65)), style: StrokeStyle(lineWidth: side * 0.005, lineCap: .round))
    }

    private func drawPlatter(ctx: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        ctx.fill(Path(ellipseIn: rect), with: .color(vinylBlack))

        let runOut = radius * (0.44 + 0.055)
        let rimIn = radius * 0.972

        // Grooves sweep gradient sheen
        let bandRect = CGRect(x: center.x - (runOut + rimIn)/2, y: center.y - (runOut + rimIn)/2, width: runOut + rimIn, height: runOut + rimIn)
        ctx.stroke(
            Path(ellipseIn: bandRect),
            with: .conicGradient(
                Gradient(stops: [
                    .init(color: .white.opacity(0.20), location: 0.0),
                    .init(color: .white.opacity(0.02), location: 0.25),
                    .init(color: .white.opacity(0.20), location: 0.50),
                    .init(color: .white.opacity(0.02), location: 0.75),
                    .init(color: .white.opacity(0.20), location: 1.0)
                ]),
                center: center
            ),
            lineWidth: rimIn - runOut
        )

        // Track gaps
        for g in trackGaps {
            let r = radius * g
            let gapRect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
            ctx.stroke(Path(ellipseIn: gapRect), with: .color(.black.opacity(0.4)), lineWidth: max(1.5, radius * 0.005))
            ctx.stroke(Path(ellipseIn: gapRect), with: .color(.white.opacity(0.12)), lineWidth: 0.8)
        }

        // Outer rim bevel
        let outerBevel = CGRect(x: center.x - radius * 0.99, y: center.y - radius * 0.99, width: radius * 1.98, height: radius * 1.98)
        ctx.stroke(Path(ellipseIn: outerBevel), with: .color(.white.opacity(0.25)), lineWidth: 1.2)
    }

    private func drawTonearm(ctx: GraphicsContext, pivot: CGPoint, degrees: Double, u: CGFloat, isShadow: Bool) {
        var copy = ctx
        copy.translateBy(x: pivot.x, y: pivot.y)
        copy.rotate(by: .degrees(degrees))

        let tubeFrom = 0.09 * u
        let armLen = 0.876 * u
        let tubeTo = armLen - (0.05 * u)
        let tubeHalf = 0.0145 * u

        // Arm Tube
        let tubePath = Path(CGRect(x: tubeFrom, y: -tubeHalf, width: tubeTo - tubeFrom, height: tubeHalf * 2))
        if isShadow {
            copy.fill(tubePath, with: .color(.black.opacity(0.4)))
        } else {
            copy.fill(tubePath, with: .linearGradient(
                Gradient(colors: [
                    Color(white: 0.35), Color(white: 0.55), Color(white: 0.75), Color(white: 0.85), Color(white: 0.60), Color(white: 0.35)
                ]),
                startPoint: CGPoint(x: 0, y: -tubeHalf),
                endPoint: CGPoint(x: 0, y: tubeHalf)
            ))
        }

        // Pivot block & counterweight
        let blockRect = CGRect(x: -0.052 * u, y: -0.058 * u, width: 0.094 * u, height: 0.146 * u)
        let blockPath = Path(roundedRect: blockRect, cornerRadius: 0.012 * u)
        if isShadow {
            copy.fill(blockPath, with: .color(.black.opacity(0.5)))
        } else {
            copy.fill(blockPath, with: .color(Color(white: 0.16)))
            copy.stroke(blockPath, with: .color(.white.opacity(0.15)), lineWidth: 1)
        }

        // Counterweight cap
        let capRect = CGRect(x: -0.10 * u, y: -0.026 * u, width: 0.06 * u, height: 0.084 * u)
        let capPath = Path(roundedRect: capRect, cornerRadius: 0.01 * u)
        if isShadow {
            copy.fill(capPath, with: .color(.black.opacity(0.5)))
        } else {
            copy.fill(capPath, with: .color(Color(white: 0.20)))
        }

        // Headshell with 27-degree bend
        var headCtx = copy
        headCtx.translateBy(x: armLen, y: 0)
        headCtx.rotate(by: .degrees(27))

        let shellRect = CGRect(x: -0.014 * u, y: -0.032 * u, width: 0.145 * u, height: 0.064 * u)
        let shellPath = Path(roundedRect: shellRect, cornerRadius: 0.009 * u)

        // Cartridge body underneath headshell
        let cartRect = CGRect(x: 0.025 * u, y: -0.020 * u, width: 0.095 * u, height: 0.040 * u)
        let cartPath = Path(roundedRect: cartRect, cornerRadius: 0.004 * u)

        if isShadow {
            headCtx.fill(shellPath, with: .color(.black.opacity(0.5)))
            headCtx.fill(cartPath, with: .color(.black.opacity(0.4)))
        } else {
            // Headshell metal body
            headCtx.fill(shellPath, with: .linearGradient(
                Gradient(colors: [Color(white: 0.22), Color(white: 0.14), Color(white: 0.09)]),
                startPoint: CGPoint(x: -0.014 * u, y: -0.032 * u),
                endPoint: CGPoint(x: 0.131 * u, y: 0.032 * u)
            ))
            headCtx.stroke(shellPath, with: .color(.white.opacity(0.18)), lineWidth: 1)

            // Premium crimson red cartridge body
            headCtx.fill(cartPath, with: .linearGradient(
                Gradient(colors: [Color(red: 0.85, green: 0.18, blue: 0.22), Color(red: 0.55, green: 0.10, blue: 0.12)]),
                startPoint: CGPoint(x: 0.025 * u, y: -0.020 * u),
                endPoint: CGPoint(x: 0.120 * u, y: 0.020 * u)
            ))
            headCtx.stroke(cartPath, with: .color(Color.black.opacity(0.35)), lineWidth: 0.5)

            // Stylus Cantilever
            var needlePath = Path()
            needlePath.move(to: CGPoint(x: 0.110 * u, y: 0.0))
            needlePath.addLine(to: CGPoint(x: 0.128 * u, y: 0.002 * u))
            headCtx.stroke(needlePath, with: .color(Color(white: 0.85)), style: StrokeStyle(lineWidth: 0.006 * u, lineCap: .round))

            // Diamond tip dot
            let tipDot = CGRect(x: 0.126 * u, y: -0.003 * u, width: 0.006 * u, height: 0.006 * u)
            headCtx.fill(Path(ellipseIn: tipDot), with: .color(.white))

            // Finger lift
            var liftPath = Path()
            liftPath.move(to: CGPoint(x: 0.112 * u, y: -0.024 * u))
            liftPath.addLine(to: CGPoint(x: 0.127 * u, y: -0.067 * u))
            headCtx.stroke(liftPath, with: .color(Color(white: 0.70)), style: StrokeStyle(lineWidth: 0.0105 * u, lineCap: .round))
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

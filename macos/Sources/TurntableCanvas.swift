import SwiftUI

public struct TurntableCanvas: View {
    let thumbnail: String?
    let title: String
    let isPlaying: Bool
    let progress: Double

    private let vinylBlack = Color(red: 9/255, green: 9/255, blue: 10/255)
    private let trackGaps: [CGFloat] = [0.665, 0.745, 0.83, 0.905]

    private let armRestDegrees: Double = 78.0
    private let armLeadInDegrees: Double = 90.5
    private let armRunOutDegrees: Double = 112.0

    public init(thumbnail: String?, title: String, isPlaying: Bool, progress: Double) {
        self.thumbnail = thumbnail
        self.title = title
        self.isPlaying = isPlaying
        self.progress = progress
    }

    public var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: side / 2, y: side / 2)
            let radius = side / 2

            ZStack {
                // Base deck slab under arm pivot
                Canvas { ctx, size in
                    drawArmBase(ctx: ctx, u: size.width)
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
                    .offset(y: radius * 0.035)

                // Stationary Platter with Sheen Reflections and Grooves
                Canvas { ctx, size in
                    drawPlatter(ctx: ctx, center: center, radius: radius)
                }

                // Turning Center Label (Artwork) at 33 1/3 RPM
                TimelineView(.animation(paused: !isPlaying)) { timeline in
                    let angle = isPlaying ? timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.8) / 1.8 * 360.0 : 0.0

                    ZStack {
                        let labelSize = side * 0.44

                        Group {
                            if let thumbnail, let url = URL(string: thumbnail) {
                                AsyncImage(url: url) { phase in
                                    if let img = phase.image {
                                        img.resizable().aspectRatio(contentMode: .fill)
                                    } else {
                                        Color(red: 0.12, green: 0.12, blue: 0.14)
                                    }
                                }
                            } else {
                                Color(red: 0.12, green: 0.12, blue: 0.14)
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
                        if !title.isEmpty {
                            NamePlateRing(title: title, radius: radius * 0.52)
                                .rotationEffect(.degrees(angle))
                        }
                    }
                }

                // Brushed Aluminium Tonearm
                let targetDeg = isPlaying ? (armLeadInDegrees + progress * (armRunOutDegrees - armLeadInDegrees)) : armRestDegrees
                let pivot = CGPoint(x: side * 0.88, y: side * 0.12)
                let u = side * 0.62

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
                .animation(.spring(response: 0.55, dampingFraction: 0.82), value: targetDeg)
            }
            .frame(width: side, height: side)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
    }

    private func drawArmBase(ctx: GraphicsContext, u: CGFloat) {
        let left = (0.885 - 0.11) * u
        let top = 0.02 * u
        let width = 0.22 * u
        let height = 0.40 * u
        let rect = CGRect(x: left, y: top, width: width, height: height)
        let path = Path(roundedRect: rect, cornerRadius: 0.11 * u)

        for i in 1...4 {
            let grow = u * 0.007 * CGFloat(i)
            let shadowRect = rect.insetBy(dx: -grow, dy: -grow).offsetBy(dx: u * 0.008, dy: u * 0.018)
            ctx.fill(Path(roundedRect: shadowRect, cornerRadius: (0.11 * u) + grow), with: .color(.black.opacity(0.07)))
        }

        ctx.fill(path, with: .linearGradient(
            Gradient(colors: [Color(white: 0.10), Color(white: 0.06), Color(white: 0.04)]),
            startPoint: CGPoint(x: left, y: top),
            endPoint: CGPoint(x: left + width, y: top + height)
        ))

        ctx.stroke(path, with: .linearGradient(
            Gradient(stops: [
                .init(color: .white.opacity(0.12), location: 0),
                .init(color: .white.opacity(0.02), location: 0.4),
                .init(color: .clear, location: 1)
            ]),
            startPoint: CGPoint(x: left, y: top),
            endPoint: CGPoint(x: left + width, y: top + height * 0.6)
        ), lineWidth: 1)
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

        // Tube
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
        if isShadow {
            headCtx.fill(shellPath, with: .color(.black.opacity(0.5)))
        } else {
            headCtx.fill(shellPath, with: .color(Color(white: 0.18)))
            headCtx.stroke(shellPath, with: .color(.white.opacity(0.15)), lineWidth: 1)

            // Finger lift
            var liftPath = Path()
            liftPath.move(to: CGPoint(x: 0.112 * u, y: -0.024 * u))
            liftPath.addLine(to: CGPoint(x: 0.127 * u, y: -0.067 * u))
            headCtx.stroke(liftPath, with: .color(Color(white: 0.65)), style: StrokeStyle(lineWidth: 0.0105 * u, lineCap: .round))
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

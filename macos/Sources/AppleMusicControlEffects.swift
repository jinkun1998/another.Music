import SwiftUI

// MARK: - Apple Music Control Button Styles & Components

/// Apple Music tactile spring press style with customizable scale and spring dynamics.
public struct AppleMusicPressButtonStyle: ButtonStyle {
    public var pressedScale: CGFloat
    public var response: Double
    public var dampingFraction: Double

    public init(
        pressedScale: CGFloat = 0.88,
        response: Double = 0.28,
        dampingFraction: Double = 0.62
    ) {
        self.pressedScale = pressedScale
        self.response = response
        self.dampingFraction = dampingFraction
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1.0)
            .animation(.spring(response: response, dampingFraction: dampingFraction), value: configuration.isPressed)
    }
}

/// Circular Play/Pause button with Apple Music fluid symbol morphing, ambient bloom aura, and hover interaction.
public struct AppleMusicPlayPauseButton: View {
    public let isPlaying: Bool
    public var size: CGFloat = 56
    public var iconSize: CGFloat = 24
    public let onToggle: () -> Void

    @State private var isHovered: Bool = false

    public init(
        isPlaying: Bool,
        size: CGFloat = 56,
        iconSize: CGFloat = 24,
        onToggle: @escaping () -> Void
    ) {
        self.isPlaying = isPlaying
        self.size = size
        self.iconSize = iconSize
        self.onToggle = onToggle
    }

    public var body: some View {
        Button(action: onToggle) {
            ZStack {
                // Ambient luminous bloom aura behind the button when playing
                Circle()
                    .fill(Color.white.opacity(isPlaying ? 0.24 : 0.0))
                    .frame(width: size * 1.08, height: size * 1.08)
                    .blur(radius: isPlaying ? 12 : 0)
                    .animation(.easeInOut(duration: 0.35), value: isPlaying)

                // Translucent glass plate with subtle brightened hover state
                Circle()
                    .fill(Color.white.opacity(isHovered ? 0.22 : 0.15))
                    .frame(width: size, height: size)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(isHovered ? 0.32 : 0.18), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(isHovered ? 0.28 : 0.15), radius: 8, y: 3)

                // SF Symbol morphing between play.fill and pause.fill
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: iconSize, weight: .bold))
                    .foregroundColor(.white)
                    .contentTransition(.symbolEffect(.replace.downUp.byLayer))
                    .offset(x: isPlaying ? 0 : 1.5) // Optical centering for play triangle
            }
            .contentShape(Circle())
        }
        .buttonStyle(AppleMusicPressButtonStyle(pressedScale: 0.90))
        .onHover { hovering in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                isHovered = hovering
            }
        }
    }
}

/// Next / Previous skip button with Apple Music directional spring nudge and bounce effect.
public struct AppleMusicSkipButton: View {
    public enum Direction {
        case previous
        case next

        var iconName: String {
            switch self {
            case .previous: return "backward.fill"
            case .next: return "forward.fill"
            }
        }

        var nudgeOffset: CGFloat {
            switch self {
            case .previous: return -3.5
            case .next: return 3.5
            }
        }
    }

    public let direction: Direction
    public var iconSize: CGFloat = 22
    public var plateSize: CGFloat = 38
    public let onAction: () -> Void

    @State private var isHovered: Bool = false
    @State private var triggerCount: Int = 0
    @State private var nudge: CGFloat = 0.0

    public init(
        direction: Direction,
        iconSize: CGFloat = 22,
        plateSize: CGFloat = 38,
        onAction: @escaping () -> Void
    ) {
        self.direction = direction
        self.iconSize = iconSize
        self.plateSize = plateSize
        self.onAction = onAction
    }

    public var body: some View {
        Button(action: {
            triggerCount += 1
            withAnimation(.spring(response: 0.18, dampingFraction: 0.55)) {
                nudge = direction.nudgeOffset
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.65)) {
                    nudge = 0.0
                }
            }
            onAction()
        }) {
            ZStack {
                // Circular hover plate
                Circle()
                    .fill(Color.white.opacity(isHovered ? 0.12 : 0.0))
                    .frame(width: plateSize, height: plateSize)

                Image(systemName: direction.iconName)
                    .font(.system(size: iconSize))
                    .foregroundColor(.white)
                    .symbolEffect(.bounce.byLayer, value: triggerCount)
                    .offset(x: nudge)
            }
            .frame(width: plateSize, height: plateSize)
            .contentShape(Rectangle())
        }
        .buttonStyle(AppleMusicPressButtonStyle(pressedScale: 0.84))
        .onHover { hovering in
            withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                isHovered = hovering
            }
        }
    }
}

/// Shuffle / Repeat toggle button with Apple Music pill backdrop and active pip dot.
public struct AppleMusicTogglePillButton: View {
    public let iconName: String
    public let isActive: Bool
    public var iconSize: CGFloat = 16
    public var plateSize: CGFloat = 36
    public let onToggle: () -> Void

    @State private var isHovered: Bool = false

    public init(
        iconName: String,
        isActive: Bool,
        iconSize: CGFloat = 16,
        plateSize: CGFloat = 36,
        onToggle: @escaping () -> Void
    ) {
        self.iconName = iconName
        self.isActive = isActive
        self.iconSize = iconSize
        self.plateSize = plateSize
        self.onToggle = onToggle
    }

    public var body: some View {
        Button(action: onToggle) {
            ZStack {
                // Apple Music active highlight pill
                Capsule()
                    .fill(Color.white.opacity(isActive ? 0.20 : (isHovered ? 0.09 : 0.0)))
                    .frame(width: plateSize, height: plateSize * 0.88)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(isActive ? 0.25 : 0.0), lineWidth: 1)
                    )

                Image(systemName: iconName)
                    .font(.system(size: iconSize, weight: isActive ? .bold : .regular))
                    .foregroundColor(isActive ? .white : .white.opacity(0.55))
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: isActive)

                // Active dot indicator beneath the icon
                Circle()
                    .fill(Color.white)
                    .frame(width: 3.5, height: 3.5)
                    .offset(y: 13)
                    .opacity(isActive ? 0.9 : 0.0)
            }
            .frame(width: plateSize, height: plateSize)
            .contentShape(Rectangle())
        }
        .buttonStyle(AppleMusicPressButtonStyle(pressedScale: 0.86))
        .onHover { hovering in
            withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                isHovered = hovering
            }
        }
    }
}

/// Reusable trackpad 2-finger swipe / scroll wheel coordinator for smooth sliding of volume and timeline
@MainActor
public final class TwoFingerSwipeHandler: ObservableObject {
    @Published public private(set) var isSwiping: Bool = false
    private var monitor: Any?
    private var debounceEndTask: Task<Void, Never>? = nil

    public var onSwipeTick: ((_ delta: CGFloat, _ phase: NSEvent.Phase, _ isPrecise: Bool) -> Void)?
    public var onSwipeEnd: (() -> Void)?

    public init() {}

    public func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, let window = event.window, window == NSApp.keyWindow || window.isKeyWindow else {
                return event
            }

            let isPrecise = event.hasPreciseScrollingDeltas
            var dx = isPrecise ? event.scrollingDeltaX : (event.deltaX * 12.0)
            var dy = isPrecise ? event.scrollingDeltaY : (event.deltaY * 12.0)

            // When natural scrolling is off on trackpads, invert so physical gesture matches visual direction
            if isPrecise && !event.isDirectionInvertedFromDevice {
                dx = -dx
                dy = -dy
            }

            // Filter out idle noise
            guard abs(dx) > 0.05 || abs(dy) > 0.05 else { return event }

            // Take the dominant movement (supports both horizontal & vertical trackpad swiping)
            let effectiveDelta = abs(dx) >= abs(dy) ? dx : dy

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isSwiping = true
                self.onSwipeTick?(effectiveDelta, event.phase, isPrecise)

                self.debounceEndTask?.cancel()

                if event.phase == .ended || event.phase == .cancelled {
                    self.isSwiping = false
                    self.onSwipeEnd?()
                } else if !isPrecise || event.phase == [] {
                    self.debounceEndTask = Task { @MainActor [weak self] in
                        try? await Task.sleep(nanoseconds: 280_000_000)
                        guard let self, !Task.isCancelled else { return }
                        self.isSwiping = false
                        self.onSwipeEnd?()
                    }
                }
            }

            return nil // Consume scroll event: avoids scrolling the page or triggering dismiss
        }
    }

    public func stop() {
        guard !isSwiping else { return }
        debounceEndTask?.cancel()
        debounceEndTask = nil
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    public func forceStop() {
        isSwiping = false
        debounceEndTask?.cancel()
        debounceEndTask = nil
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    deinit {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

/// Apple Music dynamic expanding scrubber with resting line, expansion on hover/scrub, and animated thumb.
public struct AppleMusicScrubber: View {
    public let progress: Double
    public let positionSec: Double
    public let durationSec: Double
    public let isSeeking: Bool
    public let onSeekStart: (Double) -> Void
    public let onSeekChange: (Double) -> Void
    public let onSeekEnd: (Double) -> Void

    @State private var isHovered: Bool = false
    @State private var showRemainingTime: Bool = false
    @State private var isSwiping: Bool = false
    @State private var swipeProgress: Double = 0.0
    @StateObject private var swipeHandler = TwoFingerSwipeHandler()

    public init(
        progress: Double,
        positionSec: Double,
        durationSec: Double,
        isSeeking: Bool,
        onSeekStart: @escaping (Double) -> Void,
        onSeekChange: @escaping (Double) -> Void,
        onSeekEnd: @escaping (Double) -> Void
    ) {
        self.progress = progress
        self.positionSec = positionSec
        self.durationSec = durationSec
        self.isSeeking = isSeeking
        self.onSeekStart = onSeekStart
        self.onSeekChange = onSeekChange
        self.onSeekEnd = onSeekEnd
    }

    private var activeProgress: Double {
        min(max(progress, 0.0), 1.0)
    }

    private var isExpanded: Bool {
        isHovered || isSeeking || isSwiping
    }

    public var body: some View {
        let displayP = isSwiping ? swipeProgress : activeProgress
        let displaySec = isSwiping ? (swipeProgress * durationSec) : positionSec

        VStack(spacing: 7) {
            GeometryReader { geo in
                let w = geo.size.width
                let trackHeight: CGFloat = isExpanded ? 7 : 4
                let thumbSize: CGFloat = isExpanded ? 15 : 8

                ZStack(alignment: .leading) {
                    // Touch hit-testing expanded area
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 22)

                    // Track background
                    Capsule()
                        .fill(Color.white.opacity(isExpanded ? 0.22 : 0.16))
                        .frame(height: trackHeight)

                    // Played portion with bright gradient
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white,
                                    Color.white.opacity(0.92)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(w * CGFloat(displayP), 0), height: trackHeight)

                    // Floating thumb knob with drop shadow
                    Circle()
                        .fill(Color.white)
                        .frame(width: thumbSize, height: thumbSize)
                        .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 0.5))
                        .shadow(color: .black.opacity(isExpanded ? 0.35 : 0.15), radius: isExpanded ? 5 : 2, y: 1.5)
                        .offset(x: max(min(w * CGFloat(displayP) - thumbSize / 2, w - thumbSize), 0))
                        .opacity(isExpanded ? 1.0 : 0.0)
                }
                .frame(height: 22)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let ratio = min(max(value.location.x / w, 0.0), 1.0)
                            if !isSeeking {
                                onSeekStart(ratio)
                            } else {
                                onSeekChange(ratio)
                            }
                        }
                        .onEnded { value in
                            let ratio = min(max(value.location.x / w, 0.0), 1.0)
                            onSeekEnd(ratio)
                        }
                )
            }
            .frame(height: 22)

            // Time labels
            HStack {
                Text(formatTime(displaySec))
                    .font(.system(size: 11, weight: (isSeeking || isSwiping) ? .bold : .medium))
                    .monospacedDigit()
                    .foregroundColor((isSeeking || isSwiping) ? .white : .white.opacity(0.55))

                Spacer()

                Text(showRemainingTime ? "-\(formatTime(max(durationSec - displaySec, 0)))" : formatTime(durationSec))
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundColor(.white.opacity(0.55))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                            showRemainingTime.toggle()
                        }
                    }
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.spring(response: 0.24, dampingFraction: 0.78)) {
                isHovered = hovering
            }
            if hovering {
                swipeHandler.start()
            } else {
                swipeHandler.stop()
            }
        }
        .onAppear {
            setupSwipeHandlers()
        }
        .onChange(of: progress) { _, newP in
            if !isSwiping {
                swipeProgress = newP
            }
            setupSwipeHandlers()
        }
        .onChange(of: durationSec) { _, _ in
            setupSwipeHandlers()
        }
        .onDisappear {
            swipeHandler.forceStop()
        }
        .animation(.spring(response: 0.24, dampingFraction: 0.78), value: isExpanded)
    }

    private func setupSwipeHandlers() {
        swipeHandler.onSwipeTick = { delta, phase, isPrecise in
            if phase == .began || (!isSwiping && phase == []) {
                isSwiping = true
                swipeProgress = progress
                onSeekStart(swipeProgress)
            }

            let secPerPixel: Double = 0.15
            let progressDelta: Double
            if durationSec > 5.0 {
                let secDelta = Double(delta) * secPerPixel
                progressDelta = secDelta / durationSec
            } else {
                progressDelta = Double(delta) * 0.0015
            }

            let next = min(max(swipeProgress + progressDelta, 0.0), 1.0)
            swipeProgress = next
            onSeekChange(next)
        }

        swipeHandler.onSwipeEnd = {
            isSwiping = false
            onSeekEnd(swipeProgress)
            if !isHovered {
                swipeHandler.forceStop()
            }
        }
    }

    private func formatTime(_ sec: Double) -> String {
        guard sec.isFinite && sec >= 0 else { return "0:00" }
        let total = Int(sec)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}

/// Apple Music dynamic volume control with interactive mute/unmute, max volume jump, and expanding slider.
public struct AppleMusicVolumeControl: View {
    public let volume: Float
    public let onVolumeChange: (Float) -> Void

    @State private var isHovered: Bool = false
    @State private var isDragging: Bool = false
    @State private var isSwiping: Bool = false
    @State private var preMuteVolume: Float = 0.8
    @State private var isVolDownHovered: Bool = false
    @State private var isVolUpHovered: Bool = false
    @StateObject private var swipeHandler = TwoFingerSwipeHandler()

    public init(
        volume: Float,
        onVolumeChange: @escaping (Float) -> Void
    ) {
        self.volume = volume
        self.onVolumeChange = onVolumeChange
    }

    private var isExpanded: Bool {
        isHovered || isDragging || isSwiping
    }

    private var leftIconName: String {
        volume <= 0.001 ? "speaker.slash.fill" : "speaker.fill"
    }

    private var rightIconName: String {
        if volume <= 0.001 {
            return "speaker.wave.1.fill"
        } else if volume < 0.33 {
            return "speaker.wave.1.fill"
        } else if volume < 0.66 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }

    public var body: some View {
        HStack(spacing: 8) {
            // Left speaker: interactive mute toggle
            Button(action: {
                if volume > 0.001 {
                    preMuteVolume = volume
                    onVolumeChange(0.0)
                } else {
                    onVolumeChange(preMuteVolume > 0.05 ? preMuteVolume : 0.7)
                }
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(isVolDownHovered ? 0.14 : 0.0))
                        .frame(width: 22, height: 22)

                    Image(systemName: leftIconName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(volume <= 0.001 ? .white.opacity(0.35) : .white.opacity(0.65))
                        .contentTransition(.symbolEffect(.replace))
                        .symbolEffect(.bounce, value: volume <= 0.001)
                }
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
            }
            .buttonStyle(AppleMusicPressButtonStyle(pressedScale: 0.85))
            .onHover { isVolDownHovered = $0 }

            // Volume Slider track
            GeometryReader { geo in
                let w = geo.size.width
                let trackH: CGFloat = isExpanded ? 6 : 4
                let thumbS: CGFloat = isExpanded ? 13 : 8

                ZStack(alignment: .leading) {
                    // Expanded touch target
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 20)

                    // Track background
                    Capsule()
                        .fill(Color.white.opacity(isExpanded ? 0.22 : 0.15))
                        .frame(height: trackH)

                    // Volume level
                    Capsule()
                        .fill(Color.white)
                        .frame(width: max(w * CGFloat(volume), 0), height: trackH)

                    // Thumb knob on hover/drag
                    Circle()
                        .fill(Color.white)
                        .frame(width: thumbS, height: thumbS)
                        .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
                        .offset(x: max(min(w * CGFloat(volume) - thumbS / 2, w - thumbS), 0))
                        .opacity(isExpanded ? 1.0 : 0.0)
                }
                .frame(height: 20)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            isDragging = true
                            let vol = Float(min(max(v.location.x / w, 0.0), 1.0))
                            onVolumeChange(vol)
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )
            }
            .frame(width: 140, height: 20)

            // Right speaker: jump to 100% volume
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    onVolumeChange(1.0)
                }
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(isVolUpHovered ? 0.14 : 0.0))
                        .frame(width: 22, height: 22)

                    Image(systemName: rightIconName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(volume > 0.001 ? .white.opacity(0.7) : .white.opacity(0.35))
                        .contentTransition(.symbolEffect(.replace))
                }
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
            }
            .buttonStyle(AppleMusicPressButtonStyle(pressedScale: 0.85))
            .onHover { isVolUpHovered = $0 }
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.spring(response: 0.24, dampingFraction: 0.8)) {
                isHovered = hovering
            }
            if hovering {
                swipeHandler.start()
            } else {
                swipeHandler.stop()
            }
        }
        .onAppear {
            setupSwipeHandlers()
        }
        .onChange(of: volume) { _, _ in
            setupSwipeHandlers()
        }
        .onDisappear {
            swipeHandler.forceStop()
        }
        .animation(.spring(response: 0.24, dampingFraction: 0.8), value: isExpanded)
    }

    private func setupSwipeHandlers() {
        swipeHandler.onSwipeTick = { delta, phase, isPrecise in
            if phase == .began || (!isSwiping && phase == []) {
                isSwiping = true
            }

            let deltaVolume: Float
            if isPrecise {
                deltaVolume = Float(delta) * 0.0035
            } else {
                deltaVolume = Float(delta > 0 ? 0.04 : -0.04)
            }

            let newVol = min(max(volume + deltaVolume, 0.0), 1.0)
            onVolumeChange(newVol)
        }

        swipeHandler.onSwipeEnd = {
            isSwiping = false
            if !isHovered {
                swipeHandler.forceStop()
            }
        }
    }
}

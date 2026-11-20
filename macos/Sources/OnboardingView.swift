import SwiftUI
import AppKit

@MainActor
public struct OnboardingView: View {
    public let onComplete: () -> Void

    @ObservedObject private var library = LibraryStore.shared
    @State private var currentStep: Int = 0
    @State private var isGoingBack: Bool = false
    @State private var usernameInput: String = ""
    @State private var selectedPhotoData: Data? = nil
    @State private var selectedPhotoImg: NSImage? = nil
    @State private var autoMixEnabled: Bool = true
    @AppStorage("defaultPlayerStyle") private var defaultPlayerStyle: String = "Vinyl"
    @State private var cardTiltX: Double = 0.0
    @State private var cardTiltY: Double = 0.0

    private let totalSteps = 4

    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .move(edge: isGoingBack ? .leading : .trailing)),
            removal: .opacity.combined(with: .move(edge: isGoingBack ? .trailing : .leading))
        )
    }

    private func goNext(to step: Int) {
        isGoingBack = false
        withAnimation(.spring(response: 0.45, dampingFraction: 0.84)) {
            currentStep = step
        }
    }

    private func goBack(to step: Int) {
        isGoingBack = true
        withAnimation(.spring(response: 0.45, dampingFraction: 0.84)) {
            currentStep = step
        }
    }

    public init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }

    public var body: some View {
        ZStack {
            // Deep obsidian surface
            Color.black
                .ignoresSafeArea()

            // Liquid color blobs for frosted glass refraction
            ambientLiquidBlobs

            // Central Liquid Glass Container
            VStack(spacing: 0) {
                // Top step progress pills
                HStack(spacing: 8) {
                    ForEach(0..<totalSteps, id: \.self) { idx in
                        Capsule()
                            .fill(idx <= currentStep ? Color.white : Color.white.opacity(0.18))
                            .frame(height: 3.5)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentStep)
                    }
                }
                .padding(.horizontal, 48)
                .padding(.top, 36)

                Spacer()

                // Step Pages with bidirectional directional slide
                ZStack {
                    if currentStep == 0 {
                        welcomeStep
                            .transition(stepTransition)
                    } else if currentStep == 1 {
                        importStep
                            .transition(stepTransition)
                    } else if currentStep == 2 {
                        profileStep
                            .transition(stepTransition)
                    } else if currentStep == 3 {
                        preferencesStep
                            .transition(stepTransition)
                    }
                }

                Spacer()
            }
            .frame(maxWidth: 680, maxHeight: 620)
            .liquidGlass(cornerRadius: 36)
            .padding(40)
        }
        .onAppear {
            usernameInput = library.username
            if let path = library.profilePicPath, let img = NSImage(contentsOfFile: path) {
                selectedPhotoImg = img
            }
            autoMixEnabled = AudioPlayerService.shared.transitionMode == .automix
        }
    }

    // MARK: - Liquid Ambient Blobs
    private var ambientLiquidBlobs: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    stops: [.init(color: Color(red: 0.85, green: 0.20, blue: 0.55).opacity(0.28), location: 0), .init(color: .clear, location: 0.7)],
                    center: .center,
                    startRadius: 20,
                    endRadius: 420
                ))
                .frame(width: 650, height: 650)
                .offset(x: -240, y: -180)
                .blur(radius: 80)

            Circle()
                .fill(RadialGradient(
                    stops: [.init(color: Color(red: 0.20, green: 0.45, blue: 0.95).opacity(0.26), location: 0), .init(color: .clear, location: 0.7)],
                    center: .center,
                    startRadius: 20,
                    endRadius: 420
                ))
                .frame(width: 680, height: 680)
                .offset(x: 240, y: 160)
                .blur(radius: 90)

            Circle()
                .fill(RadialGradient(
                    stops: [.init(color: Color(red: 0.55, green: 0.25, blue: 0.85).opacity(0.18), location: 0), .init(color: .clear, location: 0.7)],
                    center: .center,
                    startRadius: 20,
                    endRadius: 350
                ))
                .frame(width: 500, height: 500)
                .offset(x: 0, y: -20)
                .blur(radius: 70)
        }
        .ignoresSafeArea()
    }

    // MARK: - Step 0: Welcome (No Feature Badges)
    private var welcomeStep: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 92, height: 92)
                    .overlay(Circle().stroke(Color.white.opacity(0.20), lineWidth: 1))
                    .shadow(color: .white.opacity(0.15), radius: 20)

                Image(systemName: "music.note.house.fill")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(colors: [.white, Color.white.opacity(0.75)], startPoint: .top, endPoint: .bottom)
                    )
            }

            VStack(spacing: 12) {
                Text("Welcome to anotherMusic")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("A refined listening experience crafted for macOS, featuring bespoke vinyl acoustics, seamless intelligent transitions, and uncompromising privacy.")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.68))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 48)
            }

            Button(action: {
                goNext(to: 1)
            }) {
                HStack(spacing: 8) {
                    Text("Get Started")
                        .font(.system(size: 14, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 13)
                .background(
                    Capsule()
                        .fill(LinearGradient(colors: [Color.white.opacity(0.25), Color.white.opacity(0.14)], startPoint: .top, endPoint: .bottom))
                )
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
                .shadow(color: .black.opacity(0.25), radius: 12, y: 5)
            }
            .buttonStyle(.plain)
            .padding(.top, 14)
        }
        .padding(.horizontal, 36)
    }

    // MARK: - Step 1: Import & Sync
    private var importStep: some View {
        VStack(spacing: 24) {
            stepBadge(icon: "arrow.triangle.2.circlepath")

            VStack(spacing: 6) {
                Text("Sync & Storage")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
                Text("Choose how your music library, favorites, and history are preserved.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                choiceCard(
                    icon: "icloud.fill",
                    title: "iCloud Drive Sync",
                    desc: "Seamlessly mirror your listening stats, liked songs, and profile across all your Macs.",
                    isSelected: library.isSyncEnabled,
                    onClick: { library.isSyncEnabled = true }
                )

                choiceCard(
                    icon: "internaldrive.fill",
                    title: "Local Offline Storage",
                    desc: "Keep all data strictly inside local Application Support directory without iCloud.",
                    isSelected: !library.isSyncEnabled,
                    onClick: { library.isSyncEnabled = false }
                )
            }
            .padding(.horizontal, 20)

            HStack(spacing: 14) {
                Button(action: {
                    goBack(to: 0)
                }) {
                    Text("Back")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button(action: {
                    goNext(to: 2)
                }) {
                    Text("Continue")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 26)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(LinearGradient(colors: [Color.white.opacity(0.24), Color.white.opacity(0.14)], startPoint: .top, endPoint: .bottom))
                        )
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 32)
    }

    private func choiceCard(icon: String, title: String, desc: String, isSelected: Bool, onClick: @escaping () -> Void) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                .frame(width: 44, height: 44)
                .background(isSelected ? Color.white.opacity(0.20) : Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(isSelected ? 0.30 : 0.10), lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text(desc)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18))
                .foregroundColor(isSelected ? .white : .white.opacity(0.3))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isSelected ? Color.white.opacity(0.14) : Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(isSelected ? 0.35 : 0.15),
                            Color.white.opacity(isSelected ? 0.12 : 0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onClick)
    }

    // MARK: - Step 2: Profile ID Card
    private var profileStep: some View {
        VStack(spacing: 20) {
            stepBadge(icon: "person.crop.circle")

            VStack(spacing: 4) {
                Text("Your Profile Card")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
                Text("Tap the avatar to choose a photo, or customize your display name.")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.65))
            }

            // Interactive 3D Profile ID Card
            profileIdCardView
                .frame(width: 380, height: 201)
                .rotation3DEffect(.degrees(cardTiltX), axis: (x: 1, y: 0, z: 0))
                .rotation3DEffect(.degrees(cardTiltY), axis: (x: 0, y: 1, z: 0))
                .shadow(color: .black.opacity(0.4), radius: 24, y: 12)
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let loc):
                        let normX = (loc.x / 380.0) - 0.5
                        let normY = (loc.y / 201.0) - 0.5
                        withAnimation(.easeOut(duration: 0.15)) {
                            cardTiltY = normX * 12.0
                            cardTiltX = -normY * 12.0
                        }
                    case .ended:
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            cardTiltX = 0
                            cardTiltY = 0
                        }
                    }
                }

            // Username input
            HStack(spacing: 10) {
                Text("Display Name:")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))

                TextField("Your name", text: $usernameInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.18), lineWidth: 1))
                    .frame(width: 180)
            }

            HStack(spacing: 14) {
                Button(action: {
                    goBack(to: 1)
                }) {
                    Text("Back")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button(action: {
                    saveProfile()
                    goNext(to: 3)
                }) {
                    Text("Next")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 26)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(LinearGradient(colors: [Color.white.opacity(0.24), Color.white.opacity(0.14)], startPoint: .top, endPoint: .bottom))
                        )
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 32)
    }

    private var profileIdCardView: some View {
        ZStack {
            // Liquid Glass Card Base
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.22).opacity(0.85), Color(white: 0.12).opacity(0.90)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(0.40), location: 0.0),
                                    .init(color: .white.opacity(0.15), location: 0.4),
                                    .init(color: .white.opacity(0.05), location: 1.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )

            VStack(alignment: .leading, spacing: 0) {
                // Top row: App branding & USR tag
                HStack {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color.white.opacity(0.9))
                            .frame(width: 7, height: 7)
                        Text("anotherMusic ID")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .tracking(0.5)
                            .foregroundColor(.white.opacity(0.9))
                    }

                    Spacer()

                    Text("USR#\(library.userTag)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.75))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.20), lineWidth: 0.5))
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)

                Spacer()

                // Center row: Avatar + Name
                HStack(spacing: 14) {
                    ZStack {
                        if let img = selectedPhotoImg {
                            Image(nsImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 58, height: 58)
                                .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color.white.opacity(0.18))
                                .frame(width: 58, height: 58)
                                .overlay(
                                    Text(String(usernameInput.prefix(1)).uppercased())
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.white)
                                )
                        }

                        // Camera overlay badge
                        Circle()
                            .fill(Color.black.opacity(0.70))
                            .frame(width: 22, height: 22)
                            .overlay(
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white)
                            )
                            .offset(x: 20, y: 20)
                    }
                    .contentShape(Circle())
                    .onTapGesture { pickPhoto() }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(usernameInput.isEmpty ? "Your Name" : usernameInput)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text("Passholder · Local Vault")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.60))
                    }

                    Spacer()
                }
                .padding(.horizontal, 18)

                Spacer()

                // Bottom row: Member since & security badge
                HStack {
                    Text("ACTIVE PASS")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(1)
                        .foregroundColor(.white.opacity(0.50))

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 10))
                        Text("Zero Telemetry")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.60))
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
            }
        }
    }

    private func pickPhoto() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url, let data = try? Data(contentsOf: url) {
            selectedPhotoData = data
            selectedPhotoImg = NSImage(data: data)
        }
    }

    private func saveProfile() {
        let trimmed = usernameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            library.updateProfile(name: trimmed, photoData: selectedPhotoData)
        }
    }

    // MARK: - Step 3: Preferences
    private var preferencesStep: some View {
        VStack(spacing: 24) {
            stepBadge(icon: "slider.horizontal.3")

            VStack(spacing: 6) {
                Text("Last One")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
                Text("Set your initial audio transition and turntable player preferences.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                // AutoMix toggle
                HStack(spacing: 14) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.20), lineWidth: 1))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Intelligent AutoMix")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Bass-swap crossover transitions matching Apple Music.")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    }

                    Spacer()

                    Toggle("", isOn: $autoMixEnabled)
                        .toggleStyle(.switch)
                        .onChange(of: autoMixEnabled) { _, on in
                            AudioPlayerService.shared.setTransitionMode(on ? .automix : .off)
                        }
                }
                .padding(14)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.ultraThinMaterial)
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.10), Color.white.opacity(0.03)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(0.35), location: 0.0),
                                    .init(color: .white.opacity(0.14), location: 0.5),
                                    .init(color: .white.opacity(0.05), location: 1.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )

                // Default Player Style selector in Liquid Glass style
                HStack(spacing: 14) {
                    Image(systemName: defaultPlayerStyle == "Vinyl" ? "record.circle" : "square.stack.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.20), lineWidth: 1))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Player Style")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Text(defaultPlayerStyle == "Vinyl" ? "Interactive vinyl physics & tonearm scrubbing." : "Immersive full-bleed artwork & live lyrics.")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    }

                    Spacer()

                    LiquidGlassSegmentedPicker(
                        options: [
                            (id: "Vinyl", title: "Turntable", icon: "record.circle"),
                            (id: "Cover", title: "Cover Art", icon: "square.stack.fill")
                        ],
                        selection: $defaultPlayerStyle
                    )
                }
                .padding(14)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.ultraThinMaterial)
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.10), Color.white.opacity(0.03)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(0.35), location: 0.0),
                                    .init(color: .white.opacity(0.14), location: 0.5),
                                    .init(color: .white.opacity(0.05), location: 1.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
            }
            .padding(.horizontal, 20)

            HStack(spacing: 14) {
                Button(action: {
                    goBack(to: 2)
                }) {
                    Text("Back")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button(action: {
                    saveProfile()
                    onComplete()
                }) {
                    HStack(spacing: 6) {
                        Text("Start Listening")
                            .font(.system(size: 13, weight: .semibold))
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 10)
                    .background(
                        Capsule().fill(LinearGradient(colors: [Color.white.opacity(0.25), Color.white.opacity(0.14)], startPoint: .top, endPoint: .bottom))
                    )
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 32)
    }

    private func stepBadge(icon: String) -> some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 52, height: 52)
                .overlay(Circle().stroke(Color.white.opacity(0.20), lineWidth: 1))

            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

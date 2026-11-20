import SwiftUI
import AppKit

public struct UpdateSheetView: View {
    @ObservedObject var updater = UpdateService.shared
    public let release: AppRelease

    public init(release: AppRelease) {
        self.release = release
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.98, green: 0.28, blue: 0.42),
                                    Color(red: 0.58, green: 0.20, blue: 0.72)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 58, height: 58)
                        .shadow(color: Color(red: 0.98, green: 0.28, blue: 0.42).opacity(0.35), radius: 10, y: 4)

                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Software Update Available")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)

                        if release.isPrerelease {
                            Text("Beta")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.8))
                                .clipShape(Capsule())
                        }
                    }

                    HStack(spacing: 6) {
                        Text("anotherMusic \(release.tagName)")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.85))

                        Text("•")
                            .foregroundColor(.white.opacity(0.4))

                        Text("Current: \(updater.currentVersion)")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.55))
                    }
                }

                Spacer()

                Button(action: { updater.dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)

            Divider()
                .overlay(Color.white.opacity(0.1))

            // Body: Release Notes / Changelog
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("What's New in this Version")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)

                    Text(release.body.isEmpty ? "Performance improvements and bug fixes." : release.body)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.78))
                        .lineSpacing(4)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20)
            }
            .frame(height: 220)
            .background(Color.white.opacity(0.03))

            Divider()
                .overlay(Color.white.opacity(0.1))

            // Footer: Download Progress / Action Buttons
            VStack(spacing: 12) {
                switch updater.status {
                case let .downloading(progress, written, total):
                    VStack(spacing: 8) {
                        HStack {
                            Text("Downloading update...")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))

                            Spacer()

                            Text(formatBytes(written) + " of " + (total > 0 ? formatBytes(total) : "unknown"))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.white.opacity(0.55))
                        }

                        ProgressView(value: progress, total: 1.0)
                            .progressViewStyle(.linear)
                            .tint(Color(red: 0.98, green: 0.28, blue: 0.42))
                    }
                    .padding(.top, 4)

                case let .readyToInstall(dmgUrl):
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.green)

                        Text("Disk image mounted. Drag anotherMusic to Applications to finish!")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))

                        Spacer()

                        Button("Reveal in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([dmgUrl])
                        }
                        .buttonStyle(.borderedProminent)
                    }

                case let .failed(error):
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(2)
                        Spacer()
                        Button("Retry") {
                            updater.downloadAndInstall(release: release)
                        }
                        .buttonStyle(.bordered)
                    }

                default:
                    HStack(spacing: 12) {
                        Button("View on GitHub") {
                            updater.openReleaseInBrowser(release)
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        Button("Remind Me Later") {
                            updater.dismiss()
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 8)

                        Button(action: {
                            updater.downloadAndInstall(release: release)
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.down.circle")
                                    .font(.system(size: 13, weight: .bold))
                                Text("Download & Install")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.98, green: 0.28, blue: 0.42),
                                                Color(red: 0.88, green: 0.22, blue: 0.38)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            )
                        }
                        .buttonStyle(AppleMusicPressButtonStyle(pressedScale: 0.94))
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
        }
        .frame(width: 520)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 0.12, green: 0.12, blue: 0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.55), radius: 30, y: 15)
        )
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

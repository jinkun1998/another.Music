import SwiftUI
import Sparkle
import Combine

public enum SoftwareUpdateChannel: String, CaseIterable, Identifiable {
    case stable = "Stable"
    case beta = "Beta"

    public var id: String { rawValue }
}

public final class SoftwareUpdateDelegate: NSObject, SPUUpdaterDelegate {
    public static let shared = SoftwareUpdateDelegate()

    public func allowedChannels(for updater: SPUUpdater) -> Set<String> {
        let channel = UserDefaults.standard.string(forKey: "softwareUpdateChannel") ?? "Beta"
        return channel.lowercased() == "beta" ? ["beta"] : []
    }
}

@MainActor
public final class SoftwareUpdater: ObservableObject {
    public static let shared = SoftwareUpdater()

    public let updaterController: SPUStandardUpdaterController
    public var updater: SPUUpdater { updaterController.updater }

    @Published public var canCheckForUpdates: Bool = false

    private init() {
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: SoftwareUpdateDelegate.shared,
            userDriverDelegate: nil
        )

        self.updaterController.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    public func checkForUpdates() {
        updater.checkForUpdates()
    }
}

public struct CheckForUpdatesView: View {
    @ObservedObject private var updaterModel = SoftwareUpdater.shared

    public init() {}

    public var body: some View {
        Button(action: {
            updaterModel.checkForUpdates()
        }) {
            HStack(spacing: 6) {
                Text("Check for Updates…")
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 11, weight: .semibold))
            }
        }
        .buttonStyle(.bordered)
        .disabled(!updaterModel.canCheckForUpdates)
    }
}

public struct SoftwareUpdateChannelPicker: View {
    @AppStorage("softwareUpdateChannel") private var updateChannel: String = "Beta"

    public init() {}

    public var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Release Channel")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Text("Choose between Stable and Beta prerelease builds")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.55))
            }

            Spacer()

            Picker("", selection: $updateChannel) {
                Text("Stable").tag("Stable")
                Text("Beta").tag("Beta")
            }
            .pickerStyle(.segmented)
            .frame(width: 150)
        }
    }
}

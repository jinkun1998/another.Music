import Foundation
import SwiftUI
import AppKit

// MARK: - Semantic Version Comparison

public struct SemVer: Comparable, Equatable, Sendable {
    public let major: Int
    public let minor: Int
    public let patch: Int
    public let prerelease: String?

    public init(_ raw: String) {
        var str = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if str.lowercased().hasPrefix("v") {
            str.removeFirst()
        }

        let parts = str.components(separatedBy: "-")
        let verPart = parts[0]
        let prePart = parts.count > 1 ? parts.dropFirst().joined(separator: "-") : nil

        let numbers = verPart.components(separatedBy: ".").compactMap(Int.init)
        self.major = numbers.count > 0 ? numbers[0] : 0
        self.minor = numbers.count > 1 ? numbers[1] : 0
        self.patch = numbers.count > 2 ? numbers[2] : 0
        self.prerelease = (prePart?.isEmpty == false) ? prePart : nil
    }

    public static func < (lhs: SemVer, rhs: SemVer) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }

        // Both major.minor.patch are equal:
        // A standard release with NO prerelease is NEWER than a prerelease version (e.g. 8.4.1 > 8.4.1-beta.1)
        if lhs.prerelease == nil && rhs.prerelease != nil {
            return false // lhs is stable release, rhs is beta -> lhs > rhs
        }
        if lhs.prerelease != nil && rhs.prerelease == nil {
            return true  // lhs is beta, rhs is stable release -> lhs < rhs
        }
        if let lp = lhs.prerelease, let rp = rhs.prerelease {
            return lp.compare(rp, options: .numeric) == .orderedAscending
        }
        return false
    }
}

// MARK: - GitHub Release Models

public struct GitHubReleaseAsset: Identifiable, Sendable {
    public let id: Int
    public let name: String
    public let browserDownloadUrl: String
    public let size: Int64
    public let contentType: String

    public init(id: Int, name: String, browserDownloadUrl: String, size: Int64, contentType: String) {
        self.id = id
        self.name = name
        self.browserDownloadUrl = browserDownloadUrl
        self.size = size
        self.contentType = contentType
    }
}

public struct AppRelease: Identifiable, Sendable {
    public let id: Int
    public let tagName: String
    public let version: String
    public let name: String
    public let body: String
    public let htmlUrl: String
    public let publishedAt: Date?
    public let isPrerelease: Bool
    public let assets: [GitHubReleaseAsset]

    public var dmgAsset: GitHubReleaseAsset? {
        assets.first(where: {
            $0.name.lowercased().hasSuffix(".dmg") || $0.contentType == "application/x-apple-diskimage"
        }) ?? assets.first(where: { $0.name.lowercased().hasSuffix(".zip") })
    }

    public init(
        id: Int,
        tagName: String,
        version: String,
        name: String,
        body: String,
        htmlUrl: String,
        publishedAt: Date?,
        isPrerelease: Bool,
        assets: [GitHubReleaseAsset]
    ) {
        self.id = id
        self.tagName = tagName
        self.version = version
        self.name = name
        self.body = body
        self.htmlUrl = htmlUrl
        self.publishedAt = publishedAt
        self.isPrerelease = isPrerelease
        self.assets = assets
    }
}

// MARK: - Update Status

public enum UpdateStatus: Equatable, Sendable {
    case idle
    case checking
    case upToDate(version: String)
    case available(AppRelease)
    case downloading(progress: Double, bytesWritten: Int64, totalBytes: Int64)
    case readyToInstall(dmgURL: URL)
    case installing(message: String)
    case failed(error: String)

    public static func == (lhs: UpdateStatus, rhs: UpdateStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.checking, .checking):
            return true
        case let (.upToDate(v1), .upToDate(v2)):
            return v1 == v2
        case let (.available(r1), .available(r2)):
            return r1.id == r2.id
        case let (.downloading(p1, b1, t1), .downloading(p2, b2, t2)):
            return p1 == p2 && b1 == b2 && t1 == t2
        case let (.readyToInstall(u1), .readyToInstall(u2)):
            return u1 == u2
        case let (.installing(m1), .installing(m2)):
            return m1 == m2
        case let (.failed(e1), .failed(e2)):
            return e1 == e2
        default:
            return false
        }
    }
}

// MARK: - Update Service

@MainActor
public final class UpdateService: ObservableObject {
    public static let shared = UpdateService()

    @Published public private(set) var status: UpdateStatus = .idle
    @Published public private(set) var latestRelease: AppRelease? = nil
    @Published public var showUpdateSheet: Bool = false
    @Published public private(set) var lastCheckedDate: Date? = nil

    private let repoUrl = "https://api.github.com/repos/jinkun1998/another.Music/releases"
    private var downloadTask: Task<Void, Never>? = nil

    public var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "8.4.1-beta.6"
    }

    public var currentBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "75"
    }

    public var autoCheckEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: "autoCheckForUpdates") == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: "autoCheckForUpdates")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "autoCheckForUpdates")
        }
    }

    private init() {}

    /// Checks GitHub Releases for a version newer than currentVersion.
    public func checkForUpdates(silent: Bool = false) async {
        guard status != .checking else { return }
        self.status = .checking
        self.lastCheckedDate = Date()

        guard let url = URL(string: repoUrl) else {
            self.status = .failed(error: "Invalid repository endpoint")
            return
        }

        var req = URLRequest(url: url)
        req.setValue("anotherMusic-macOS/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        req.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 12

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                self.status = .failed(error: "GitHub API responded with code \(code)")
                return
            }

            guard let list = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                self.status = .failed(error: "Invalid release response format")
                return
            }

            let releases = list.compactMap { parseRelease($0) }
            guard let latest = releases.first else {
                self.status = .upToDate(version: currentVersion)
                return
            }

            let curVer = SemVer(currentVersion)
            let remVer = SemVer(latest.version)

            if curVer < remVer {
                self.latestRelease = latest
                self.status = .available(latest)
                self.showUpdateSheet = true
            } else {
                self.status = .upToDate(version: currentVersion)
                if !silent {
                    // Feedback when manually checking
                    self.showUpdateSheet = false
                }
            }
        } catch {
            self.status = .failed(error: error.localizedDescription)
        }
    }

    /// Downloads the DMG asset or opens the release page in browser.
    public func downloadAndInstall(release: AppRelease) {
        guard let asset = release.dmgAsset, let downloadUrl = URL(string: asset.browserDownloadUrl) else {
            openReleaseInBrowser(release)
            return
        }

        downloadTask?.cancel()
        downloadTask = Task { [weak self] in
            guard let self else { return }
            do {
                self.status = .downloading(progress: 0.0, bytesWritten: 0, totalBytes: asset.size)

                let delegate = DownloadProgressDelegate { [weak self] progress, written, total in
                    Task { @MainActor in
                        self?.status = .downloading(progress: progress, bytesWritten: written, totalBytes: total)
                    }
                }

                let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
                var req = URLRequest(url: downloadUrl)
                req.setValue("anotherMusic-macOS/\(self.currentVersion)", forHTTPHeaderField: "User-Agent")

                let (tempUrl, response) = try await session.download(for: req)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                    self.status = .failed(error: "Download failed with status \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                    return
                }

                // Move downloaded file to temporary directory
                let tempFolder = FileManager.default.temporaryDirectory
                let destinationUrl = tempFolder.appendingPathComponent("anotherMusic_update_\(UUID().uuidString).dmg")

                try? FileManager.default.removeItem(at: destinationUrl)
                try FileManager.default.moveItem(at: tempUrl, to: destinationUrl)

                self.status = .readyToInstall(dmgURL: destinationUrl)

                // Seamlessly auto-install, close running app, and relaunch new version
                self.performAutoInstallAndRelaunch(dmgURL: destinationUrl)
            } catch {
                if !Task.isCancelled {
                    self.status = .failed(error: error.localizedDescription)
                }
            }
        }
    }

    /// Automatically installs the update from the downloaded DMG, closes this app, and relaunches the new version.
    public func performAutoInstallAndRelaunch(dmgURL: URL) {
        self.status = .installing(message: "Installing update & restarting...")

        Task.detached(priority: .userInitiated) {
            let pid = ProcessInfo.processInfo.processIdentifier
            let fileManager = FileManager.default

            let runningPath = await MainActor.run { Bundle.main.bundlePath }
            let targetAppPath: String
            if runningPath.hasPrefix("/Volumes/") || runningPath.contains("/.build/") {
                targetAppPath = "/Applications/anotherMusic.app"
            } else {
                targetAppPath = runningPath
            }

            let stagingDir = fileManager.temporaryDirectory.appendingPathComponent("anotherMusic_staged_\(UUID().uuidString)")
            let mountDir = fileManager.temporaryDirectory.appendingPathComponent("anotherMusic_mount_\(UUID().uuidString)")

            do {
                try? fileManager.removeItem(at: stagingDir)
                try? fileManager.removeItem(at: mountDir)
                try fileManager.createDirectory(at: stagingDir, withIntermediateDirectories: true)
                try fileManager.createDirectory(at: mountDir, withIntermediateDirectories: true)

                // 1. Mount DMG silently without opening Finder
                let mountProcess = Process()
                mountProcess.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                mountProcess.arguments = ["attach", dmgURL.path, "-nobrowse", "-readonly", "-mountpoint", mountDir.path]
                try mountProcess.run()
                mountProcess.waitUntilExit()

                guard mountProcess.terminationStatus == 0 else {
                    throw NSError(domain: "UpdateService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to mount update image."])
                }

                // 2. Locate .app inside mount point
                let contents = try fileManager.contentsOfDirectory(atPath: mountDir.path)
                guard let appName = contents.first(where: { $0.hasSuffix(".app") }) else {
                    let unmountProcess = Process()
                    unmountProcess.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                    unmountProcess.arguments = ["detach", mountDir.path, "-force"]
                    try? unmountProcess.run()
                    throw NSError(domain: "UpdateService", code: 2, userInfo: [NSLocalizedDescriptionKey: "No application found in update package."])
                }

                let sourceApp = mountDir.appendingPathComponent(appName)
                let stagedApp = stagingDir.appendingPathComponent(appName)

                // 3. Copy app to staging directory
                let copyProcess = Process()
                copyProcess.executableURL = URL(fileURLWithPath: "/bin/cp")
                copyProcess.arguments = ["-R", sourceApp.path, stagedApp.path]
                try copyProcess.run()
                copyProcess.waitUntilExit()

                // 4. Detach DMG and delete downloaded file
                let unmountProcess = Process()
                unmountProcess.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                unmountProcess.arguments = ["detach", mountDir.path, "-force"]
                try? unmountProcess.run()
                unmountProcess.waitUntilExit()
                try? fileManager.removeItem(at: mountDir)
                try? fileManager.removeItem(at: dmgURL)

                // 5. Create detached updater script
                let scriptPath = fileManager.temporaryDirectory.appendingPathComponent("anothermusic_updater_\(pid).sh")
                let scriptContent = """
                #!/bin/sh
                PID=\(pid)
                SRC="\(stagedApp.path)"
                DST="\(targetAppPath)"
                STAGING="\(stagingDir.path)"
                SCRIPT="$0"

                # Wait up to 15 seconds for host app to exit
                for i in $(seq 1 150); do
                    if ! kill -0 $PID 2>/dev/null; then
                        break
                    fi
                    sleep 0.1
                done

                # Atomically replace application bundle
                rm -rf "$DST"
                cp -R "$SRC" "$DST"
                xattr -rd com.apple.quarantine "$DST" 2>/dev/null || true
                rm -rf "$STAGING"

                # Relaunch updated application
                sleep 0.2
                open "$DST"

                # Self-remove script
                rm -f "$SCRIPT"
                exit 0
                """

                try scriptContent.write(to: scriptPath, atomically: true, encoding: .utf8)
                try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath.path)

                // 6. Launch updater script in background detached
                let launchProcess = Process()
                launchProcess.executableURL = URL(fileURLWithPath: "/bin/sh")
                launchProcess.arguments = [scriptPath.path]
                try launchProcess.run()

                // 7. Terminate current application cleanly
                try await Task.sleep(nanoseconds: 350_000_000)
                await MainActor.run {
                    NSApp.terminate(nil)
                }
            } catch {
                await MainActor.run {
                    self.status = .failed(error: error.localizedDescription)
                }
            }
        }
    }

    public func openReleaseInBrowser(_ release: AppRelease) {
        if let url = URL(string: release.htmlUrl) {
            NSWorkspace.shared.open(url)
        }
    }

    public func dismiss() {
        self.showUpdateSheet = false
    }

    // MARK: - JSON Parser
    private func parseRelease(_ dict: [String: Any]) -> AppRelease? {
        guard let id = dict["id"] as? Int,
              let tagName = dict["tag_name"] as? String,
              let htmlUrl = dict["html_url"] as? String else {
            return nil
        }

        let name = (dict["name"] as? String) ?? tagName
        let body = (dict["body"] as? String) ?? ""
        let isPrerelease = (dict["prerelease"] as? Bool) ?? false

        var versionStr = tagName
        if versionStr.lowercased().hasPrefix("v") {
            versionStr.removeFirst()
        }

        var publishedAt: Date? = nil
        if let dateStr = dict["published_at"] as? String {
            let formatter = ISO8601DateFormatter()
            publishedAt = formatter.date(from: dateStr)
        }

        let rawAssets = (dict["assets"] as? [[String: Any]]) ?? []
        let assets = rawAssets.compactMap { aDict -> GitHubReleaseAsset? in
            guard let aId = aDict["id"] as? Int,
                  let aName = aDict["name"] as? String,
                  let aUrl = aDict["browser_download_url"] as? String else {
                return nil
            }
            let size = (aDict["size"] as? Int64) ?? (aDict["size"] as? Int).map(Int64.init) ?? 0
            let cType = (aDict["content_type"] as? String) ?? ""
            return GitHubReleaseAsset(id: aId, name: aName, browserDownloadUrl: aUrl, size: size, contentType: cType)
        }

        return AppRelease(
            id: id,
            tagName: tagName,
            version: versionStr,
            name: name,
            body: body,
            htmlUrl: htmlUrl,
            publishedAt: publishedAt,
            isPrerelease: isPrerelease,
            assets: assets
        )
    }
}

// MARK: - URLSession Download Progress Delegate

private final class DownloadProgressDelegate: NSObject, URLSessionDownloadDelegate, Sendable {
    private let onProgress: @Sendable (Double, Int64, Int64) -> Void

    init(onProgress: @escaping @Sendable (Double, Int64, Int64) -> Void) {
        self.onProgress = onProgress
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let progress = totalBytesExpectedToWrite > 0
            ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            : 0.0
        onProgress(progress, totalBytesWritten, totalBytesExpectedToWrite)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
}

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
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "8.4.1-beta.1"
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

                // Move downloaded file to Downloads folder
                let downloadsFolder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
                    ?? FileManager.default.temporaryDirectory
                let destinationUrl = downloadsFolder.appendingPathComponent(asset.name)

                try? FileManager.default.removeItem(at: destinationUrl)
                try FileManager.default.moveItem(at: tempUrl, to: destinationUrl)

                self.status = .readyToInstall(dmgURL: destinationUrl)

                // Mount / open the disk image
                NSWorkspace.shared.open(destinationUrl)
                NSWorkspace.shared.activateFileViewerSelecting([destinationUrl])
            } catch {
                if !Task.isCancelled {
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

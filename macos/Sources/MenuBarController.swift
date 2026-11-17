import SwiftUI
import AppKit

@MainActor
final class MenuBarStatusItem: ObservableObject {
    static let shared = MenuBarStatusItem()
    
    private var statusItem: NSStatusItem?
    private var hostingView: NSHostingView<MenuBarPopover>?
    private var popover: NSPopover?
    
    @Published var isPlaying: Bool = false
    @Published var title: String = "anotherMusic"
    @Published var artist: String = ""
    @Published var progress: Double = 0.0
    
    private init() {
        setupStatusItem()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }
        
        button.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "anotherMusic")
        button.image?.isTemplate = true
        button.action = #selector(togglePopover(_:))
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }
    
    func updateState(isPlaying: Bool, title: String, artist: String, progress: Double) {
        self.isPlaying = isPlaying
        self.title = title
        self.artist = artist
        self.progress = progress
        
        // Update status bar icon
        if let button = statusItem?.button {
            let imageName = isPlaying ? "play.circle.fill" : "music.note"
            button.image = NSImage(systemSymbolName: imageName, accessibilityDescription: "anotherMusic")
            button.image?.isTemplate = true
            
            // Show progress in tooltip
            if isPlaying {
                let percent = Int(progress * 100)
                button.toolTip = "\(title) — \(artist) (\(percent)%)"
            } else {
                button.toolTip = "anotherMusic"
            }
        }
        
        // Update popover if open
        if let hostingView = hostingView {
            hostingView.rootView = MenuBarPopover(
                title: title,
                artist: artist,
                progress: progress,
                isPlaying: isPlaying,
                onPlayPause: { AudioPlayerService.shared.togglePlayPause() },
                onPrevious: { AudioPlayerService.shared.previous() },
                onNext: { AudioPlayerService.shared.next() },
                onOpenApp: { self.openApp() },
                onQuit: { NSApp.terminate(nil) }
            )
        }
    }
    
    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        _ = NSApp.currentEvent
        
        if let popover = popover, popover.isShown {
            popover.performClose(sender)
            return
        }
        
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        
        let contentView = MenuBarPopover(
            title: title,
            artist: artist,
            progress: progress,
            isPlaying: isPlaying,
            onPlayPause: { AudioPlayerService.shared.togglePlayPause() },
            onPrevious: { AudioPlayerService.shared.previous() },
            onNext: { AudioPlayerService.shared.next() },
            onOpenApp: { self.openApp(); popover.performClose(sender) },
            onQuit: { NSApp.terminate(nil) }
        )
        
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 280, height: 180)
        self.hostingView = hostingView
        
        popover.contentViewController = NSViewController()
        popover.contentViewController?.view = hostingView
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        
        self.popover = popover
    }
    
    private func openApp() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows {
            window.makeKeyAndOrderFront(nil)
        }
    }
}

struct MenuBarPopover: View {
    let title: String
    let artist: String
    let progress: Double
    let isPlaying: Bool
    let onPlayPause: () -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onOpenApp: () -> Void
    let onQuit: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Track info
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .foregroundColor(.primary)
                
                Text(artist)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 4)
                    
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: max(0, geo.size.width * progress), height: 4)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 16)
            
            // Controls
            HStack(spacing: 28) {
                Button(action: onPrevious) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                
                Button(action: onPlayPause) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(" ")
                
                Button(action: onNext) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
            
            Divider()
                .padding(.horizontal, 16)
            
            // Footer actions
            HStack {
                Button("Open anotherMusic", action: onOpenApp)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Quit", action: onQuit)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .frame(width: 280, height: 180)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// Keep the old MenuBarController for compatibility with MenuBarExtra
struct MenuBarController: View {
    @ObservedObject var player: AudioPlayerService
    
    var body: some View {
        MenuBarPopover(
            title: player.currentTrack?.title ?? "Not playing",
            artist: player.currentTrack?.artist ?? "",
            progress: player.progress,
            isPlaying: player.isPlaying,
            onPlayPause: { player.togglePlayPause() },
            onPrevious: { player.previous() },
            onNext: { player.next() },
            onOpenApp: { NSApp.activate(ignoringOtherApps: true); NSApp.windows.first?.makeKeyAndOrderFront(nil) },
            onQuit: { NSApp.terminate(nil) }
        )
    }
}

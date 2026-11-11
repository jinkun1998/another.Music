import SwiftUI
import AppKit

public struct AccountScreen: View {
    var onPlay: ((SongItem, [SongItem]) -> Void)? = nil

    @ObservedObject private var library = LibraryStore.shared
    @State private var showingEditSheet: Bool = false
    @State private var showingSettingsSheet: Bool = false
    @State private var editName: String = ""

    public init(onPlay: ((SongItem, [SongItem]) -> Void)? = nil) {
        self.onPlay = onPlay
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 32) {
                // Top Inset to align with other screens
                Color.clear.frame(height: 20)

                // Profile Header (Matches Android UserProfilePage + ProfileIdCard)
                HStack(alignment: .center, spacing: 24) {
                    // Profile Avatar (Click to change)
                    Button(action: pickAvatarImage) {
                        ZStack {
                            if let pic = library.profilePicPath,
                               let img = NSImage(contentsOfFile: pic) {
                                Image(nsImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 92, height: 92)
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.25), Color.white.opacity(0.08)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 92, height: 92)

                                Text(String(library.username.prefix(1)).uppercased())
                                    .font(.system(size: 38, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }

                            // Camera badge overlay
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Circle()
                                        .fill(Color.black.opacity(0.8))
                                        .frame(width: 28, height: 28)
                                        .overlay(
                                            Image(systemName: "camera.fill")
                                                .font(.system(size: 12))
                                                .foregroundColor(.white)
                                        )
                                }
                            }
                            .frame(width: 92, height: 92)
                        }
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 14) {
                            Text(library.username)
                                .font(.system(size: 38, weight: .bold, design: .rounded))
                                .tracking(-0.8)
                                .foregroundColor(.white)

                            Text("USR#\(library.userTag)")
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.45))
                        }

                        HStack(spacing: 12) {
                            // Edit Profile Pill
                            Button(action: {
                                editName = library.username
                                showingEditSheet = true
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 11, weight: .semibold))
                                    Text("Edit Profile")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                            }
                            .buttonStyle(.plain)

                            // iCloud Sync Badge & Reveal
                            Button(action: { library.revealInFinder() }) {
                                HStack(spacing: 6) {
                                    Image(systemName: library.isICloudSyncing ? "icloud.fill" : "folder.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(library.isICloudSyncing ? Color.green : .white.opacity(0.6))
                                    Text(library.isICloudSyncing ? "iCloud Synced" : "Local Storage")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white.opacity(0.85))
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 9))
                                        .foregroundColor(.white.opacity(0.4))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.06))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Spacer()

                    Button(action: { showingSettingsSheet = true }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                            .frame(width: 38, height: 38)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .help("Settings (⌘,)")
                }
                .padding(.horizontal, 36)

                // Listening Stats Row (Matches Android ListensRow)
                HStack(spacing: 16) {
                    StatCard(
                        title: "LISTENING TIME",
                        value: formatListeningTime(library.totalPlayTimeSec),
                        icon: "clock.fill"
                    )

                    StatCard(
                        title: "TRACKS PLAYED",
                        value: "\(library.history.count)",
                        icon: "play.circle.fill"
                    )

                    StatCard(
                        title: "FAVORITES",
                        value: "\(library.likedSongs.count)",
                        icon: "heart.fill"
                    )
                }
                .padding(.horizontal, 36)

                // Recently Played Section
                if !library.history.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Recently Played")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 36)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(library.history.prefix(20)) { song in
                                    ProfileSongCard(song: song, onPlay: {
                                        onPlay?(song, library.history)
                                    })
                                }
                            }
                            .padding(.horizontal, 36)
                        }
                    }
                }

                // Top Artists Shelf
                if !library.topArtists.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Top Artists")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 36)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(library.topArtists, id: \.artist) { item in
                                    HStack(spacing: 10) {
                                        Circle()
                                            .fill(Color.white.opacity(0.12))
                                            .frame(width: 32, height: 32)
                                            .overlay(
                                                Text(String(item.artist.prefix(1)).uppercased())
                                                    .font(.system(size: 13, weight: .bold))
                                                    .foregroundColor(.white)
                                            )

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.artist)
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                            Text("\(item.count) plays")
                                                .font(.system(size: 11))
                                                .foregroundColor(.white.opacity(0.5))
                                        }
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                            }
                            .padding(.horizontal, 36)
                        }
                    }
                }

                Color.clear.frame(height: 120)
            }
            .padding(.top, 24)
        }
        .sheet(isPresented: $showingEditSheet) {
            EditProfileView(name: $editName) { newName in
                library.updateProfile(name: newName, photoData: nil)
                showingEditSheet = false
            } onCancel: {
                showingEditSheet = false
            }
        }
        .sheet(isPresented: $showingSettingsSheet) {
            ZStack(alignment: .topTrailing) {
                SettingsView()

                Button(action: { showingSettingsSheet = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.85))
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(14)
            }
            .frame(width: 780, height: 530)
        }
    }

    private func pickAvatarImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.jpeg, .png]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        panel.title = "Select Profile Picture"

        if panel.runModal() == .OK, let url = panel.url, let data = try? Data(contentsOf: url) {
            library.updateProfile(name: library.username, photoData: data)
        }
    }

    private func formatListeningTime(_ sec: Int) -> String {
        let mins = sec / 60
        if mins < 60 {
            return "\(mins) min"
        }
        let hours = Double(mins) / 60.0
        return String(format: "%.1f hrs", hours)
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.6)
                    .foregroundColor(.white.opacity(0.45))
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.35))
            }

            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}

private struct ProfileSongCard: View {
    let song: SongItem
    let onPlay: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let thumb = song.thumbnail, let url = URL(string: thumb) {
                AsyncImage(url: url) { phase in
                    if let img = phase.image {
                        img.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Color.gray.opacity(0.3)
                    }
                }
                .frame(width: 140, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.35), radius: 6)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(song.artist)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }
            .frame(width: 140, alignment: .leading)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onPlay)
    }
}

private struct EditProfileView: View {
    @Binding var name: String
    let onSave: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Edit Profile")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            TextField("Display Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)

            HStack(spacing: 14) {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)

                Button("Save") { onSave(name) }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(28)
        .frame(width: 320)
    }
}

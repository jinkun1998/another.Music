import SwiftUI

public struct AccountScreen: View {
    public var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color(red: 1.0, green: 0.18, blue: 0.34).opacity(0.15))
                    .frame(width: 90, height: 90)
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(Color(red: 1.0, green: 0.18, blue: 0.34))
            }

            VStack(spacing: 6) {
                Text("another.Music Native macOS")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                Text("Pure SwiftUI & AVFoundation (Apple Silicon)")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
            }

            HStack(spacing: 12) {
                Label("Zero Java Runtime", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.green)
                Label("Native AVPlayer", systemImage: "speaker.wave.3.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.blue)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.06))
            .clipShape(Capsule())

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

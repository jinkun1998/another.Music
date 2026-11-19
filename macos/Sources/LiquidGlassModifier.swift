import SwiftUI

public struct LiquidGlassModifier: ViewModifier {
    let cornerRadius: CGFloat

    public func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.12),
                                    Color.white.opacity(0.02)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                stops: [
                                    .init(color: Color.white.opacity(0.40), location: 0.0),
                                    .init(color: Color.white.opacity(0.15), location: 0.45),
                                    .init(color: Color.white.opacity(0.05), location: 1.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .shadow(color: Color.black.opacity(0.45), radius: 24, x: 0, y: 12)
    }
}

public extension View {
    func liquidGlass(cornerRadius: CGFloat = 30) -> some View {
        modifier(LiquidGlassModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - Native macOS Liquid Glass Animated Segmented Picker
public struct LiquidGlassSegmentedPicker: View {
    public let options: [(id: String, title: String, icon: String)]
    @Binding public var selection: String

    public init(options: [(id: String, title: String, icon: String)], selection: Binding<String>) {
        self.options = options
        self._selection = selection
    }

    private var selectedIndex: Int {
        options.firstIndex(where: { $0.id == selection }) ?? 0
    }

    public var body: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let totalHeight = geo.size.height
            let padding: CGFloat = 3
            let count = CGFloat(max(options.count, 1))
            let segmentWidth = (totalWidth - (padding * 2)) / count
            let thumbHeight = totalHeight - (padding * 2)

            ZStack(alignment: .leading) {
                // Outer Liquid Glass Channel Track
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .fill(Color.black.opacity(0.32))
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                LinearGradient(
                                    stops: [
                                        .init(color: Color.white.opacity(0.28), location: 0.0),
                                        .init(color: Color.white.opacity(0.12), location: 0.5),
                                        .init(color: Color.white.opacity(0.06), location: 1.0)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )

                // Sliding Liquid Glass Capsule Thumb
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.32),
                                Color.white.opacity(0.16)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                LinearGradient(
                                    stops: [
                                        .init(color: Color.white.opacity(0.60), location: 0.0),
                                        .init(color: Color.white.opacity(0.24), location: 0.45),
                                        .init(color: Color.white.opacity(0.10), location: 1.0)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 8, x: 0, y: 3)
                    .frame(width: segmentWidth, height: thumbHeight)
                    .offset(x: padding + (CGFloat(selectedIndex) * segmentWidth), y: 0)
                    .animation(.spring(response: 0.36, dampingFraction: 0.76), value: selectedIndex)

                // Options Row
                HStack(spacing: 0) {
                    ForEach(options, id: \.id) { opt in
                        let isSelected = selection == opt.id
                        Button(action: {
                            withAnimation(.spring(response: 0.36, dampingFraction: 0.76)) {
                                selection = opt.id
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: opt.icon)
                                    .font(.system(size: 11, weight: .semibold))
                                Text(opt.title)
                                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                            }
                            .foregroundColor(isSelected ? .white : .white.opacity(0.60))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(padding)
            }
        }
        .frame(width: 236, height: 36)
    }
}



import AppKit

@MainActor
public final class ImageCache {
    public static let shared = ImageCache()
    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 150
        cache.totalCostLimit = 64 * 1024 * 1024
    }

    public func image(for urlString: String) -> NSImage? {
        cache.object(forKey: urlString as NSString)
    }

    public func insert(_ image: NSImage, for urlString: String) {
        cache.setObject(image, forKey: urlString as NSString)
    }

    public func preload(urlString: String) {
        guard let url = URL(string: urlString), image(for: urlString) == nil else { return }
        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let img = NSImage(data: data) else { return }
            await MainActor.run {
                self.insert(img, for: urlString)
            }
        }
    }
}

public struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let urlString: String?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    @State private var loadedImage: NSImage?

    public init(
        urlString: String?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.urlString = urlString
        self.content = content
        self.placeholder = placeholder
        if let urlString, let cached = ImageCache.shared.image(for: urlString) {
            _loadedImage = State(initialValue: cached)
        }
    }

    public var body: some View {
        Group {
            if let loaded = loadedImage {
                content(Image(nsImage: loaded))
            } else {
                placeholder()
            }
        }
        .onAppear { load() }
        .onChange(of: urlString) { _, _ in load() }
    }

    private func load() {
        guard let urlString, !urlString.isEmpty else {
            loadedImage = nil
            return
        }
        if let cached = ImageCache.shared.image(for: urlString) {
            loadedImage = cached
            return
        }
        guard let url = URL(string: urlString) else { return }
        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let img = NSImage(data: data) else { return }
            await MainActor.run {
                ImageCache.shared.insert(img, for: urlString)
                if self.urlString == urlString {
                    self.loadedImage = img
                }
            }
        }
    }
}

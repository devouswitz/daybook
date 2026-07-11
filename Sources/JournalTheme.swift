import SwiftUI
import AppKit

enum JournalTheme {
    static let accent = Color(red: 0.36, green: 0.32, blue: 0.91)
    static let accentSoft = dynamic(
        light: NSColor(calibratedRed: 0.91, green: 0.90, blue: 1.0, alpha: 1),
        dark: NSColor(calibratedRed: 0.17, green: 0.15, blue: 0.28, alpha: 1)
    )
    static let canvas = dynamic(
        light: NSColor(calibratedRed: 0.96, green: 0.95, blue: 0.93, alpha: 1),
        dark: NSColor(calibratedRed: 0.065, green: 0.065, blue: 0.075, alpha: 1)
    )
    static let surface = dynamic(
        light: NSColor(calibratedWhite: 0.995, alpha: 1),
        dark: NSColor(calibratedRed: 0.115, green: 0.115, blue: 0.13, alpha: 1)
    )
    static let surfaceRaised = dynamic(
        light: NSColor(calibratedRed: 0.985, green: 0.98, blue: 0.97, alpha: 1),
        dark: NSColor(calibratedRed: 0.15, green: 0.15, blue: 0.17, alpha: 1)
    )
    static let surfaceMuted = dynamic(
        light: NSColor(calibratedRed: 0.92, green: 0.915, blue: 0.90, alpha: 1),
        dark: NSColor(calibratedRed: 0.19, green: 0.19, blue: 0.21, alpha: 1)
    )
    static let stroke = dynamic(
        light: NSColor(calibratedWhite: 0.1, alpha: 0.075),
        dark: NSColor(calibratedWhite: 1, alpha: 0.095)
    )
    static let strongStroke = dynamic(
        light: NSColor(calibratedWhite: 0.1, alpha: 0.13),
        dark: NSColor(calibratedWhite: 1, alpha: 0.16)
    )

    private static func dynamic(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }
}

extension EntryType {
    var color: Color {
        switch self {
        case .general: return Color(red: 0.10, green: 0.63, blue: 0.61)
        case .reflection: return Color(red: 0.96, green: 0.52, blue: 0.20)
        case .dream: return Color(red: 0.40, green: 0.39, blue: 0.88)
        case .fitness: return Color(red: 0.19, green: 0.72, blue: 0.38)
        case .travel: return Color(red: 0.15, green: 0.56, blue: 0.91)
        case .reading: return Color(red: 0.62, green: 0.43, blue: 0.30)
        }
    }
}

private struct JournalCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let radius: CGFloat
    let shadow: CGFloat

    func body(content: Content) -> some View {
        content
            .background(JournalTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(JournalTheme.stroke, lineWidth: 1)
            }
            .shadow(
                color: .black.opacity(colorScheme == .dark ? shadow * 1.5 : shadow),
                radius: shadow * 16,
                y: shadow * 7
            )
    }
}

extension View {
    func journalCard(radius: CGFloat = 20, shadow: CGFloat = 0.07) -> some View {
        modifier(JournalCardModifier(radius: radius, shadow: shadow))
    }
}

struct JournalIconButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    var isSelected = false
    var size: CGFloat = 36

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(isSelected ? JournalTheme.accent : Color.primary)
            .frame(width: size, height: size)
            .background(isSelected ? JournalTheme.accentSoft : JournalTheme.surfaceRaised)
            .clipShape(Circle())
            .overlay {
                Circle().stroke(isSelected ? JournalTheme.accent.opacity(0.22) : JournalTheme.stroke)
            }
            .shadow(
                color: .black.opacity(colorScheme == .dark ? 0.18 : 0.06),
                radius: 5,
                y: 2
            )
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct JournalPhotoCollage: View {
    @EnvironmentObject private var store: JournalStore
    let names: [String]
    var height: CGFloat = 210

    var body: some View {
        GeometryReader { proxy in
            let gap: CGFloat = 3
            if names.count == 1 {
                photo(names[0])
                    .frame(width: proxy.size.width, height: height)
            } else if names.count == 2 {
                HStack(spacing: gap) {
                    photo(names[0])
                        .frame(width: (proxy.size.width - gap) / 2, height: height)
                    photo(names[1])
                        .frame(width: (proxy.size.width - gap) / 2, height: height)
                }
            } else if names.count >= 3 {
                let leadingWidth = (proxy.size.width - gap) * 0.62
                let trailingWidth = proxy.size.width - gap - leadingWidth
                HStack(spacing: gap) {
                    photo(names[0])
                        .frame(width: leadingWidth, height: height)
                    VStack(spacing: gap) {
                        photo(names[1])
                            .frame(width: trailingWidth, height: (height - gap) / 2)
                        ZStack {
                            photo(names[2])
                            if names.count > 3 {
                                Color.black.opacity(0.34)
                                Text("+\(names.count - 3)")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(width: trailingWidth, height: (height - gap) / 2)
                    }
                }
            }
        }
        .frame(height: height)
        .clipped()
    }

    @ViewBuilder
    private func photo(_ name: String) -> some View {
        if let image = NSImage(contentsOf: store.photoURL(name)) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .clipped()
        } else {
            ZStack {
                JournalTheme.surfaceMuted
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

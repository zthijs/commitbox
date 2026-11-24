import SwiftUI
import WidgetKit

private nonisolated enum ContributionPalette {
    static let accent = Color(hex: 0x39D353)
    static let green: [Color] = [.white.opacity(0.07), Color(hex: 0x0E4429), Color(hex: 0x006D32), Color(hex: 0x26A641), accent]
    static let monochrome = [0.12, 0.3, 0.5, 0.75, 1].map { Color.primary.opacity($0) }

    static func colors(for renderingMode: WidgetRenderingMode) -> [Color] {
        renderingMode == .fullColor ? green : monochrome
    }

    static func accent(for renderingMode: WidgetRenderingMode) -> Color {
        renderingMode == .fullColor ? accent : .primary
    }
}

private extension Color {
    nonisolated init(hex: Int) {
        self.init(red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

struct ContributionGlassBackground: View {
    var body: some View {
        let glow = ContributionPalette.accent

        ZStack {
            LinearGradient(colors: [Color(hex: 0x11301F), Color(hex: 0x050E09)], startPoint: .topLeading, endPoint: .bottomTrailing)
            EllipticalGradient(colors: [glow.opacity(0.26), .clear], center: .bottomTrailing, endRadiusFraction: 0.8)
            EllipticalGradient(colors: [glow.opacity(0.12), .clear], center: .topLeading, endRadiusFraction: 0.6)
            LinearGradient(colors: [.white.opacity(0.08), .clear], startPoint: .top, endPoint: .center)
            ContainerRelativeShape()
                .strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.3), .white.opacity(0.04), glow.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
        }
    }
}

struct ContributionCard: View {
    let calendar: ContributionCalendar

    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        VStack(spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    title
                    Spacer(minLength: 0)
                    badges
                }
                VStack(alignment: .leading, spacing: 6) {
                    title
                    badges
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            ContributionGraph(calendar: calendar)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var accent: Color {
        ContributionPalette.accent(for: renderingMode)
    }

    private var title: some View {
        HStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(accent)
                .frame(width: 10, height: 10)
                .widgetAccentable()
            Text("@\(calendar.username)")
                .font(.system(size: 15, weight: .bold))
                .lineLimit(1)
        }
    }

    private var badges: some View {
        HStack(spacing: 6) {
            badge(calendar.yearTotal, systemImage: "square.grid.3x3.fill", tint: accent,
                  label: "\(calendar.yearTotal) contributions in \(calendar.year)")
            badge(calendar.currentStreak, systemImage: "flame.fill", tint: calendar.currentStreak > 0 ? accent : .secondary,
                  label: "\(calendar.currentStreak)-day streak")
        }
    }

    private func badge(_ value: Int, systemImage: String, tint: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(tint)
                .widgetAccentable()
            Text(value, format: .number.grouping(.never))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.08), in: .capsule)
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5))
        .lineLimit(1)
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }
}

struct ContributionGraph: View {
    let calendar: ContributionCalendar

    @Environment(\.widgetRenderingMode) private var renderingMode

    private let gap: CGFloat = 0.22

    var body: some View {
        let weeks = calendar.weeks
        let colors = ContributionPalette.colors(for: renderingMode)

        Canvas { context, size in
            guard size.width > 0, size.height > 0, !weeks.isEmpty else { return }

            let pitchForHeight = size.height / (7 - gap)
            let columns = min(weeks.count, Int((size.width / pitchForHeight + gap).rounded(.up)))
            let pitch = min(pitchForHeight, size.width / (CGFloat(columns) - gap))
            let cell = pitch * (1 - gap)
            let origin = CGPoint(
                x: (size.width - (CGFloat(columns) - gap) * pitch) / 2,
                y: (size.height - (7 - gap) * pitch) / 2
            )

            for (column, week) in weeks.suffix(columns).enumerated() {
                for (row, day) in week.enumerated() {
                    guard let day else { continue }
                    let rect = CGRect(x: origin.x + CGFloat(column) * pitch, y: origin.y + CGFloat(row) * pitch, width: cell, height: cell)
                    context.fill(Path(roundedRect: rect, cornerRadius: cell * 0.3, style: .continuous), with: .color(colors[day.level]))
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Contribution graph")
        .accessibilityValue("\(calendar.yearTotal) contributions in \(String(calendar.year))")
    }
}

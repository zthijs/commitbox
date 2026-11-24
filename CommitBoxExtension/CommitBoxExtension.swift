import SwiftUI
import WidgetKit

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ContributionEntry {
        ContributionEntry(content: .loaded(.sample))
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> ContributionEntry {
        if context.isPreview && configuration.enteredUsername == nil {
            return placeholder(in: context)
        }
        return ContributionEntry(content: await load(configuration).content)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<ContributionEntry> {
        let (content, policy) = await load(configuration)
        return Timeline(entries: [ContributionEntry(content: content)], policy: policy)
    }

    private func load(_ configuration: ConfigurationAppIntent) async -> (content: ContributionEntry.Content, policy: TimelineReloadPolicy) {
        guard let username = configuration.enteredUsername else {
            return (.needsUsername, .never)
        }
        do {
            let calendar = try await ContributionService.fetch(username: username)
            ContributionCache.save(calendar)
            return (.loaded(calendar), .after(.now.addingTimeInterval(60 * 60)))
        } catch {
            let retry = TimelineReloadPolicy.after(.now.addingTimeInterval(15 * 60))
            if let cached = ContributionCache.load(username: username) {
                return (.loaded(cached), retry)
            }
            return (.failed(error.localizedDescription), retry)
        }
    }
}

struct ContributionEntry: TimelineEntry {
    enum Content {
        case needsUsername
        case loaded(ContributionCalendar)
        case failed(String)
    }

    var date = Date.now
    let content: Content
}

private enum ContributionCache {
    static func save(_ calendar: ContributionCalendar) {
        UserDefaults.standard.set(try? JSONEncoder().encode(calendar), forKey: key(for: calendar.username))
    }

    static func load(username: String) -> ContributionCalendar? {
        guard let data = UserDefaults.standard.data(forKey: key(for: username)) else { return nil }
        return try? JSONDecoder().decode(ContributionCalendar.self, from: data)
    }

    private static func key(for username: String) -> String {
        "calendar." + ((try? ContributionService.normalized(username)) ?? username).lowercased()
    }
}

struct ContributionWidgetView: View {
    let entry: ContributionEntry

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        Group {
            switch entry.content {
            case .loaded(let calendar):
                ContributionCard(calendar: calendar)
            case .needsUsername:
                message("Add your GitHub username", detail: "Right-click this widget and choose Edit.", systemImage: "person.crop.circle.badge.plus")
            case .failed(let reason):
                message("Couldn't load contributions", detail: reason, systemImage: "exclamationmark.triangle")
            }
        }
        .environment(\.colorScheme, renderingMode == .fullColor ? .dark : colorScheme)
    }

    private func message(_ title: String, detail: String, systemImage: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ContributionWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "ContributionWidget", intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            ContributionWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    ContributionGlassBackground()
                }
        }
        .configurationDisplayName("GitHub Contributions")
        .description("Your recent contributions, this year's total, and your current streak.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemExtraLarge])
    }
}

#Preview(as: .systemMedium) {
    ContributionWidget()
} timeline: {
    ContributionEntry(content: .loaded(.sample))
    ContributionEntry(content: .needsUsername)
}

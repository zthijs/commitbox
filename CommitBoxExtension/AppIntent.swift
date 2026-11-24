import AppIntents
import WidgetKit

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "GitHub Account" }
    static var description: IntentDescription { "Choose whose contribution graph to show." }

    @Parameter(
        title: "Username",
        inputOptions: String.IntentInputOptions(capitalizationType: .none, autocorrect: false, smartQuotes: false, smartDashes: false)
    )
    var username: String?

    var enteredUsername: String? {
        guard let username, !username.allSatisfy(\.isWhitespace) else { return nil }
        return username
    }
}

import SafariServices
import SwiftUI

struct ContentView: View {
    @StateObject private var blocker = BlockerStatus()

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: blocker.isEnabled ? "checkmark.shield.fill" : "shield")
                .font(.system(size: 56))
                .foregroundStyle(blocker.isEnabled ? .green : .secondary)

            Text("Hush")
                .font(.title.bold())

            Text(blocker.message)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.secondary)

            Button("Check Again") {
                blocker.refresh()
            }
            .buttonStyle(.borderedProminent)

            if blocker.isEnabled {
                Button("Reload Safari’s Rules") {
                    blocker.reload()
                }
                .buttonStyle(.bordered)
            }

            if let rules = blocker.rules {
                Text(rules.summary)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(.secondary)
            }

            Text(instructions)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(minWidth: 320, minHeight: 360)
        .onAppear { blocker.refresh() }
    }

    private var instructions: String {
        #if os(macOS)
        "Enable the extension in Safari → Settings → Extensions."
        #else
        "Enable the extension in Settings → Apps → Safari → Extensions."
        #endif
    }
}

struct RulesInfo: Decodable {
    let generated: Date
    let ruleCount: Int
    let sources: [String]

    static let bundled: RulesInfo? = {
        guard let url = Bundle.main.url(forResource: "rules-metadata", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(RulesInfo.self, from: data)
    }()

    var summary: String {
        let list = ListFormatter.localizedString(byJoining: sources)
        return "\(ruleCount.formatted()) rules from \(list), updated \(generated.formatted(date: .abbreviated, time: .omitted))."
    }
}

@MainActor
final class BlockerStatus: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var message = "Checking Safari…"

    let rules = RulesInfo.bundled

    private let extensionIdentifier = "sh.saad.hush.ContentBlocker"
    private let loadedRulesKey = "loadedRulesStamp"

    /// Identifies the bundled rules so Safari is only asked to recompile when they actually change.
    private var rulesStamp: String {
        if let rules { return rules.generated.ISO8601Format() }
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
    }

    func refresh() {
        message = "Checking Safari…"
        SFContentBlockerManager.getStateOfContentBlocker(withIdentifier: extensionIdentifier) { [weak self] state, error in
            let enabled = state?.isEnabled == true
            let errorMessage = error?.localizedDescription
            Task { @MainActor in
                guard let self else { return }
                if let errorMessage {
                    self.isEnabled = false
                    self.message = "Unable to read Safari’s setting: \(errorMessage)"
                } else {
                    self.isEnabled = enabled
                    if enabled && UserDefaults.standard.string(forKey: self.loadedRulesKey) != self.rulesStamp {
                        self.reload()
                    } else {
                        self.message = enabled
                            ? "Ad blocking is enabled."
                            : "Ad blocking is not enabled yet."
                    }
                }
            }
        }
    }

    func reload() {
        message = "Reloading rules…"
        SFContentBlockerManager.reloadContentBlocker(withIdentifier: extensionIdentifier) { [weak self] error in
            let errorMessage = error?.localizedDescription
            Task { @MainActor in
                guard let self else { return }
                if let errorMessage {
                    self.message = "Reload failed: \(errorMessage)"
                } else {
                    UserDefaults.standard.set(self.rulesStamp, forKey: self.loadedRulesKey)
                    self.message = "Rules reloaded."
                }
            }
        }
    }
}

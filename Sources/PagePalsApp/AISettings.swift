import Foundation
import Security

/// Opt-in settings for letting an AI model work out answer keys while importing.
/// Off by default. The API key is kept in the macOS Keychain, never in the project or the book data.
final class AISettings: ObservableObject {
    static let shared = AISettings()

    @Published var enabled: Bool { didSet { UserDefaults.standard.set(enabled, forKey: "pagepals.ai.enabled") } }
    @Published var model: String { didSet { UserDefaults.standard.set(model, forKey: "pagepals.ai.model") } }
    @Published var apiKey: String {
        didSet { Keychain.write(account: "anthropic-api-key", value: apiKey) }
    }

    /// Ready to use: switched on and a key is present (the `ANTHROPIC_API_KEY` environment variable also counts).
    var isReady: Bool { enabled && !effectiveKey.isEmpty }

    var effectiveKey: String {
        if !apiKey.isEmpty { return apiKey }
        return ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
    }

    private init() {
        enabled = UserDefaults.standard.bool(forKey: "pagepals.ai.enabled")
        model = UserDefaults.standard.string(forKey: "pagepals.ai.model") ?? "claude-sonnet-5-5"
        apiKey = Keychain.read(account: "anthropic-api-key") ?? ""
    }
}

enum Keychain {
    private static let service = "com.maxkerro.pagepals"

    static func read(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func write(account: String, value: String) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(base as CFDictionary)
        guard !value.isEmpty, let data = value.data(using: .utf8) else { return }
        var add = base
        add[kSecValueData as String] = data
        SecItemAdd(add as CFDictionary, nil)
    }
}

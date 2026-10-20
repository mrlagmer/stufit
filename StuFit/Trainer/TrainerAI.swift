//
//  TrainerAI.swift
//  StuFit
//
//  Routes trainer generations to GPT-6 Luna when an OpenAI key is saved,
//  falling back to Apple's on-device model when there's no key, no signal,
//  or the API errors — so a session can always be planned at the gym.
//

import Foundation
import FoundationModels
import Security

// MARK: - OpenAI key storage

/// The OpenAI API key lives in the Keychain (this device only), never in
/// UserDefaults or the binary.
nonisolated enum OpenAIKeychain {
    private static let service = "com.stufit.openai"
    private static let account = "api-key"

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    static var apiKey: String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8),
              !key.isEmpty else { return nil }
        return key
    }

    @discardableResult
    static func save(_ key: String) -> Bool {
        delete()
        var query = baseQuery
        query[kSecValueData as String] = Data(key.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func delete() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}

// MARK: - Model routing

enum TrainerModelProvider: String {
    case luna
    case onDevice

    var label: String {
        switch self {
        case .luna: return "GPT-6 Luna"
        case .onDevice: return "On-device"
        }
    }
}

enum TrainerAIError: LocalizedError {
    case noModelAvailable

    var errorDescription: String? {
        "No AI model is available. Add an OpenAI key in Settings, or turn on Apple Intelligence."
    }
}

@MainActor
final class TrainerAI {
    static let modelIDKey = "trainerModelID"

    /// Why the last Luna attempt fell back, surfaced in Settings.
    private(set) var lastLunaError: String?

    var modelID: String {
        let saved = UserDefaults.standard.string(forKey: Self.modelIDKey) ?? ""
        return saved.isEmpty ? LunaModel.defaultModelID : saved
    }

    var hasLunaKey: Bool { OpenAIKeychain.apiKey != nil }

    var isOnDeviceAvailable: Bool { SystemLanguageModel.default.isAvailable }

    /// Generates structured output, trying Luna first and the on-device
    /// model second. Throws only when neither can produce a result.
    func generate<Content: Generable>(
        _ type: Content.Type,
        instructions: String,
        prompt: String
    ) async throws -> (content: Content, provider: TrainerModelProvider) {
        if let key = OpenAIKeychain.apiKey {
            do {
                let session = LanguageModelSession(
                    model: LunaModel(apiKey: key, modelID: modelID),
                    instructions: instructions
                )
                let response = try await session.respond(to: prompt, generating: type)
                lastLunaError = nil
                return (response.content, .luna)
            } catch {
                lastLunaError = error.localizedDescription
                print("Luna failed, falling back to on-device: \(error.localizedDescription)")
            }
        }

        guard isOnDeviceAvailable else { throw TrainerAIError.noModelAvailable }
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: prompt, generating: type)
        return (response.content, .onDevice)
    }

    /// Round-trips a tiny request to Luna only — used by Settings to check
    /// the key without silently passing via the on-device fallback.
    func testLuna() async -> String? {
        guard let key = OpenAIKeychain.apiKey else { return "No key saved." }
        do {
            let session = LanguageModelSession(
                model: LunaModel(apiKey: key, modelID: modelID),
                instructions: "Reply briefly."
            )
            _ = try await session.respond(to: "Say ready.", generating: ConnectionCheck.self)
            lastLunaError = nil
            return nil
        } catch {
            lastLunaError = error.localizedDescription
            return error.localizedDescription
        }
    }
}

@Generable
nonisolated struct ConnectionCheck {
    var reply: String
}

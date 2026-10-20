//
//  LunaLanguageModel.swift
//  StuFit
//
//  OpenAI GPT-6 Luna as a Foundation Models provider. Conforming to
//  `LanguageModel` lets a regular `LanguageModelSession` run on Luna, so the
//  trainer uses the same `respond(to:generating:)` + `@Generable` code path
//  whether the plan comes from Luna or Apple's on-device model.
//
//  Only guided generation is implemented — the trainer passes everything it
//  knows in the prompt, so there's no tool calling to bridge.
//

import Foundation
import FoundationModels

nonisolated struct LunaModel: LanguageModel {
    typealias Executor = LunaExecutor

    static let defaultModelID = "gpt-6-luna"

    let apiKey: String
    var modelID: String = LunaModel.defaultModelID

    var capabilities: LanguageModelCapabilities {
        LanguageModelCapabilities([.guidedGeneration])
    }

    var executorConfiguration: LunaExecutor.Configuration {
        LunaExecutor.Configuration(apiKey: apiKey, modelID: modelID)
    }
}

nonisolated enum LunaError: LocalizedError {
    case http(status: Int, message: String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .http(let status, let message):
            return "OpenAI returned \(status): \(message)"
        case .emptyResponse:
            return "OpenAI returned no text."
        }
    }
}

nonisolated struct LunaExecutor: LanguageModelExecutor {
    typealias Model = LunaModel

    struct Configuration: Hashable, Sendable {
        let apiKey: String
        let modelID: String
    }

    private static let endpoint = URL(string: "https://api.openai.com/v1/responses")!
    private let configuration: Configuration

    init(configuration: Configuration) throws {
        self.configuration = configuration
    }

    nonisolated(nonsending) func respond(
        to request: LanguageModelExecutorGenerationRequest,
        model: LunaModel,
        streamingInto channel: LanguageModelExecutorGenerationChannel
    ) async throws {
        let body = try Self.requestBody(for: request, modelID: configuration.modelID)

        var urlRequest = URLRequest(url: Self.endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 45
        urlRequest.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]

        guard (200..<300).contains(status) else {
            let message = (json["error"] as? [String: Any])?["message"] as? String
                ?? String(decoding: data.prefix(300), as: UTF8.self)
            throw LunaError.http(status: status, message: message)
        }

        let text = Self.outputText(from: json)
        guard !text.isEmpty else { throw LunaError.emptyResponse }

        let usage = json["usage"] as? [String: Any]
        let inputTokens = usage?["input_tokens"] as? Int ?? 0
        let outputTokens = usage?["output_tokens"] as? Int ?? 0

        await channel.send(.response(action: .appendText(text, tokenCount: outputTokens)))
        await channel.send(.response(action: .updateUsage(
            input: .init(totalTokenCount: inputTokens, cachedTokenCount: 0),
            output: .init(totalTokenCount: outputTokens, reasoningTokenCount: 0)
        )))
    }

    // MARK: - Request mapping

    /// Maps the session transcript onto an OpenAI Responses API request.
    private static func requestBody(
        for request: LanguageModelExecutorGenerationRequest,
        modelID: String
    ) throws -> [String: Any] {
        var instructions: [String] = []
        var input: [[String: Any]] = []

        for entry in request.transcript {
            switch entry {
            case .instructions(let value):
                instructions.append(text(of: value.segments))
            case .prompt(let value):
                input.append(["role": "user", "content": text(of: value.segments)])
            case .response(let value):
                input.append(["role": "assistant", "content": text(of: value.segments)])
            default:
                // Tool calls and reasoning never appear — the trainer
                // registers no tools and Luna's reasoning isn't round-tripped.
                break
            }
        }

        var body: [String: Any] = [
            "model": modelID,
            "input": input,
            "store": false
        ]
        if !instructions.isEmpty {
            body["instructions"] = instructions.joined(separator: "\n\n")
        }
        if let maxTokens = request.generationOptions.maximumResponseTokens {
            body["max_output_tokens"] = maxTokens
        }
        if let schema = request.schema {
            body["text"] = [
                "format": [
                    "type": "json_schema",
                    "name": schemaName(schema),
                    "schema": try jsonSchema(schema),
                    // Non-strict keeps range/count keywords from being
                    // rejected; the session validates the output itself.
                    "strict": false
                ] as [String: Any]
            ]
        }
        return body
    }

    private static func text(of segments: [Transcript.Segment]) -> String {
        segments.map { segment -> String in
            switch segment {
            case .text(let text): return text.content
            case .structure(let structure): return structure.content.jsonString
            default: return ""
            }
        }
        .joined(separator: "\n")
    }

    /// GenerationSchema encodes as JSON Schema; drop Apple's `x-` extension
    /// keys, which OpenAI doesn't recognise.
    private static func jsonSchema(_ schema: GenerationSchema) throws -> Any {
        let data = try JSONEncoder().encode(schema)
        return stripExtensionKeys(try JSONSerialization.jsonObject(with: data))
    }

    private static func stripExtensionKeys(_ value: Any) -> Any {
        if let dict = value as? [String: Any] {
            return dict
                .filter { !$0.key.hasPrefix("x-") }
                .mapValues { stripExtensionKeys($0) }
        }
        if let array = value as? [Any] {
            return array.map { stripExtensionKeys($0) }
        }
        return value
    }

    private static func schemaName(_ schema: GenerationSchema) -> String {
        let cleaned = schema.name.filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
        return cleaned.isEmpty ? "response" : String(cleaned.prefix(64))
    }

    // MARK: - Response mapping

    private static func outputText(from json: [String: Any]) -> String {
        let output = json["output"] as? [[String: Any]] ?? []
        return output
            .filter { $0["type"] as? String == "message" }
            .flatMap { $0["content"] as? [[String: Any]] ?? [] }
            .filter { $0["type"] as? String == "output_text" }
            .compactMap { $0["text"] as? String }
            .joined()
    }
}

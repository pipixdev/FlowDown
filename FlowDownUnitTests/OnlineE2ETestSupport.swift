@testable import FlowDown
import Foundation
import Storage

enum OnlineE2ETestSupport {
    private static let embeddedFixture = EmbeddedCloudModelFixture(
        modelIdentifier: "moonshotai/kimi-k2.5",
        endpoint: "https://openrouter.ai/api/v1/chat/completions",
        headers: [
            "HTTP-Referer": "https://flowdown.ai/",
            "X-Title": "FlowDown",
        ],
        bodyFields: "",
        context: .medium_64k,
        capabilities: [.tool],
        comment: "online-e2e",
        name: "Embedded Online E2E Model",
    )

    static let isEnabled: Bool = {
        let environment = ProcessInfo.processInfo.environment
        if environment["FLOWDOWN_RUN_ONLINE_E2E"] == "0" {
            return false
        }
        return runtimeToken(in: environment) != nil
    }()

    static func runtimeCloudModel() throws -> CloudModel {
        let environment = ProcessInfo.processInfo.environment
        guard let token = runtimeToken(in: environment) else {
            throw NSError(
                domain: "OnlineE2ETestSupport",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: """
                    No online E2E API token was found. Set FLOWDOWN_ONLINE_E2E_TOKEN or OPENROUTER_API_KEY, or place the token in ~/.testing/openrouter.sk.
                    """,
                ],
            )
        }

        let fixture = embeddedFixture.overriding(with: environment)
        let responseFormat = CloudModel.ResponseFormat.inferredFormat(fromEndpoint: fixture.endpoint) ?? .default

        return CloudModel(
            deviceId: Storage.deviceId,
            model_identifier: fixture.modelIdentifier,
            model_list_endpoint: responseFormat.defaultModelListEndpoint,
            creation: .now,
            endpoint: fixture.endpoint,
            token: token,
            headers: fixture.headers,
            bodyFields: fixture.bodyFields,
            context: fixture.context,
            capabilities: fixture.capabilities,
            comment: fixture.comment,
            name: fixture.name,
            response_format: responseFormat,
        )
    }

    private static func runtimeToken(in environment: [String: String]) -> String? {
        if let token = trimmedNonEmpty(environment["FLOWDOWN_ONLINE_E2E_TOKEN"]) {
            return token
        }
        if let token = trimmedNonEmpty(environment["OPENROUTER_API_KEY"]) {
            return token
        }
        return tokenFromSecretFiles()
    }

    private static func tokenFromSecretFiles() -> String? {
        for url in secretFileCandidates() {
            guard let token = try? String(contentsOf: url, encoding: .utf8) else {
                continue
            }
            if let token = trimmedNonEmpty(token) {
                return token
            }
        }
        return nil
    }

    private static func secretFileCandidates() -> [URL] {
        let currentHome = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        let hostHome = URL(fileURLWithPath: "/Users", isDirectory: true)
            .appendingPathComponent(NSUserName(), isDirectory: true)

        var seenPaths = Set<String>()
        return [currentHome, hostHome]
            .map { $0.appendingPathComponent(".testing").appendingPathComponent("openrouter.sk") }
            .filter { seenPaths.insert($0.standardizedFileURL.path).inserted }
    }

    private static func trimmedNonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct EmbeddedCloudModelFixture {
    let modelIdentifier: String
    let endpoint: String
    let headers: [String: String]
    let bodyFields: String
    let context: ModelContextLength
    let capabilities: Set<ModelCapabilities>
    let comment: String
    let name: String

    func overriding(with environment: [String: String]) -> Self {
        Self(
            modelIdentifier: environment["FLOWDOWN_ONLINE_E2E_MODEL_ID"] ?? modelIdentifier,
            endpoint: environment["FLOWDOWN_ONLINE_E2E_ENDPOINT"] ?? endpoint,
            headers: headers,
            bodyFields: environment["FLOWDOWN_ONLINE_E2E_BODY_FIELDS"] ?? bodyFields,
            context: context,
            capabilities: capabilities,
            comment: comment,
            name: name,
        )
    }
}

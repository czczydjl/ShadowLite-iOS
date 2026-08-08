import Foundation

enum ShadowsocksURIParser {
    static func parseSubscription(_ input: String) -> [ProxyNode] {
        let normalized = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidateText: String

        if normalized.contains("ss://") {
            candidateText = normalized
        } else {
            candidateText = decodeBase64String(normalized) ?? normalized
        }

        return candidateText
            .components(separatedBy: .newlines)
            .flatMap { $0.components(separatedBy: CharacterSet.whitespaces) }
            .compactMap(parse)
    }

    static func parse(_ rawValue: String) -> ProxyNode? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("ss://") else { return nil }

        let withoutScheme = String(trimmed.dropFirst("ss://".count))
        let fragmentSplit = withoutScheme.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
        let encodedBody = String(fragmentSplit[0])
        let nodeName = fragmentSplit.count > 1
            ? String(fragmentSplit[1]).removingPercentEncoding
            : nil

        let bodyWithoutQuery = encodedBody.split(separator: "?", maxSplits: 1).first.map(String.init) ?? encodedBody

        if let node = parseSIP002(bodyWithoutQuery, fallbackName: nodeName) {
            return node
        }

        guard let decoded = decodeBase64String(bodyWithoutQuery) else { return nil }
        return parseUserInfo(decoded, fallbackName: nodeName)
    }

    private static func parseSIP002(_ body: String, fallbackName: String?) -> ProxyNode? {
        guard body.contains("@") else { return nil }

        let parts = body.split(separator: "@", maxSplits: 1)
        guard parts.count == 2 else { return nil }

        let userInfo = decodeBase64String(String(parts[0])) ?? String(parts[0])
        let endpoint = String(parts[1])
        return parseUserInfo("\(userInfo)@\(endpoint)", fallbackName: fallbackName)
    }

    private static func parseUserInfo(_ value: String, fallbackName: String?) -> ProxyNode? {
        let parts = value.split(separator: "@", maxSplits: 1)
        guard parts.count == 2 else { return nil }

        let credentials = String(parts[0])
        let endpoint = String(parts[1])
        let credentialParts = credentials.split(separator: ":", maxSplits: 1)
        let endpointParts = endpoint.split(separator: ":", maxSplits: 1)

        guard credentialParts.count == 2,
              endpointParts.count == 2,
              let port = Int(endpointParts[1]) else {
            return nil
        }

        let method = String(credentialParts[0]).removingPercentEncoding ?? String(credentialParts[0])
        let password = String(credentialParts[1]).removingPercentEncoding ?? String(credentialParts[1])
        let host = String(endpointParts[0]).removingPercentEncoding ?? String(endpointParts[0])
        let name = fallbackName?.removingPercentEncoding ?? host

        return ProxyNode(
            name: name,
            host: host,
            port: port,
            password: password,
            method: method
        )
    }

    private static func decodeBase64String(_ value: String) -> String? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let padding = base64.count % 4
        if padding > 0 {
            base64 += String(repeating: "=", count: 4 - padding)
        }

        guard let data = Data(base64Encoded: base64) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

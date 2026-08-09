import Foundation

enum ClashSubscriptionParser {
    static func parse(_ input: String) -> [ProxyNode] {
        var nodes: [ProxyNode] = []
        var current: [String: String]?
        var inRealityOptions = false

        for rawLine in input.components(separatedBy: .newlines) {
            let line = rawLine.replacingOccurrences(of: "\t", with: "    ")
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.hasPrefix("- name:") {
                appendNode(from: current, to: &nodes)
                current = [:]
                current?["name"] = cleanValue(String(trimmed.dropFirst("- name:".count)))
                inRealityOptions = false
                continue
            }

            guard current != nil, !trimmed.isEmpty, !trimmed.hasPrefix("#") else {
                continue
            }

            if trimmed == "reality-opts:" {
                inRealityOptions = true
                continue
            }

            guard let separator = trimmed.firstIndex(of: ":") else {
                continue
            }

            let key = String(trimmed[..<separator]).trimmingCharacters(in: .whitespaces)
            let valueStart = trimmed.index(after: separator)
            let value = cleanValue(String(trimmed[valueStart...]))
            let normalizedKey = inRealityOptions ? "reality-\(key)" : key
            current?[normalizedKey] = value

            if !line.hasPrefix("    ") && key != "reality-opts" {
                inRealityOptions = false
            }
        }

        appendNode(from: current, to: &nodes)
        return nodes
    }

    private static func appendNode(from values: [String: String]?, to nodes: inout [ProxyNode]) {
        guard let values,
              values["type"]?.lowercased() == "vless",
              let name = values["name"],
              let host = values["server"],
              let portString = values["port"],
              let port = Int(portString),
              let uuid = values["uuid"],
              !uuid.isEmpty else {
            return
        }

        nodes.append(ProxyNode(
            name: name,
            host: host,
            port: port,
            protocolKind: .vless,
            password: "",
            method: "",
            uuid: uuid,
            flow: values["flow"] ?? "",
            tlsEnabled: parseBool(values["tls"]) ?? true,
            serverName: values["servername"] ?? host,
            fingerprint: values["client-fingerprint"] ?? "chrome",
            realityPublicKey: values["reality-public-key"] ?? "",
            realityShortID: values["reality-short-id"] ?? ""
        ))
    }

    private static func parseBool(_ value: String?) -> Bool? {
        guard let value else { return nil }
        switch value.lowercased() {
        case "true", "yes", "1":
            return true
        case "false", "no", "0":
            return false
        default:
            return nil
        }
    }

    private static func cleanValue(_ rawValue: String) -> String {
        var value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
            value.removeFirst()
            value.removeLast()
        } else if value.hasPrefix("'"), value.hasSuffix("'"), value.count >= 2 {
            value.removeFirst()
            value.removeLast()
        }
        return value
    }
}


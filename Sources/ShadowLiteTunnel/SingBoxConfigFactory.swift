import Foundation

enum SingBoxConfigFactory {
    static let localProxyPort = 20808

    static func makeConfig(configuration: TunnelConfiguration) throws -> String {
        let inbound: [String: Any] = [
            "type": "mixed",
            "tag": "mixed-in",
            "listen": "127.0.0.1",
            "listen_port": localProxyPort
        ]

        let outbound: [String: Any]
        switch configuration.protocolKind {
        case .vless:
            outbound = [
                "type": "vless",
                "tag": "proxy",
                "server": configuration.host,
                "server_port": configuration.port,
                "uuid": configuration.uuid,
                "flow": configuration.flow,
                "tls": [
                    "enabled": configuration.tlsEnabled,
                    "server_name": configuration.serverName.isEmpty ? configuration.host : configuration.serverName,
                    "utls": [
                        "enabled": true,
                        "fingerprint": configuration.fingerprint.isEmpty ? "chrome" : configuration.fingerprint
                    ],
                    "reality": [
                        "enabled": !configuration.realityPublicKey.isEmpty,
                        "public_key": configuration.realityPublicKey,
                        "short_id": configuration.realityShortID
                    ]
                ]
            ]
        case .shadowsocks:
            outbound = [
                "type": "shadowsocks",
                "tag": "proxy",
                "server": configuration.host,
                "server_port": configuration.port,
                "method": configuration.method,
                "password": configuration.password
            ]
        }

        let config: [String: Any] = [
            "log": [
                "level": "info",
                "timestamp": true
            ],
            "inbounds": [inbound],
            "outbounds": [
                outbound,
                [
                    "type": "direct",
                    "tag": "direct"
                ]
            ],
            "route": [
                "final": "proxy",
                "auto_detect_interface": true
            ]
        ]

        let data = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys])
        guard let json = String(data: data, encoding: .utf8) else {
            throw TunnelError.invalidProviderConfiguration
        }
        return json
    }
}

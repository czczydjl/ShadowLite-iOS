import SwiftUI

struct NodeEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: NodeStore

    let node: ProxyNode?

    @State private var name: String
    @State private var host: String
    @State private var port: String
    @State private var protocolKind: ProxyNode.ProtocolKind
    @State private var password: String
    @State private var method: String
    @State private var uuid: String
    @State private var flow: String
    @State private var tlsEnabled: Bool
    @State private var serverName: String
    @State private var fingerprint: String
    @State private var realityPublicKey: String
    @State private var realityShortID: String

    private let methods = [
        "aes-256-gcm",
        "chacha20-ietf-poly1305",
        "2022-blake3-aes-128-gcm",
        "2022-blake3-chacha20-poly1305"
    ]

    init(node: ProxyNode? = nil) {
        self.node = node
        _name = State(initialValue: node?.name ?? "")
        _host = State(initialValue: node?.host ?? "")
        _port = State(initialValue: node.map { String($0.port) } ?? "8388")
        _protocolKind = State(initialValue: node?.protocolKind ?? .vless)
        _password = State(initialValue: node?.password ?? "")
        _method = State(initialValue: node?.method ?? "aes-256-gcm")
        _uuid = State(initialValue: node?.uuid ?? "")
        _flow = State(initialValue: node?.flow ?? "xtls-rprx-vision")
        _tlsEnabled = State(initialValue: node?.tlsEnabled ?? true)
        _serverName = State(initialValue: node?.serverName ?? "")
        _fingerprint = State(initialValue: node?.fingerprint ?? "chrome")
        _realityPublicKey = State(initialValue: node?.realityPublicKey ?? "")
        _realityShortID = State(initialValue: node?.realityShortID ?? "")
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Server") {
                    TextField("Name", text: $name)
                    Picker("Protocol", selection: $protocolKind) {
                        ForEach(ProxyNode.ProtocolKind.allCases, id: \.self) { item in
                            Text(item.displayName).tag(item)
                        }
                    }
                    TextField("Host or IP", text: $host)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    TextField("Port", text: $port)
                        .keyboardType(.numberPad)
                }

                if protocolKind == .shadowsocks {
                    Section("Shadowsocks") {
                        SecureField("Password", text: $password)
                        Picker("Method", selection: $method) {
                            ForEach(methods, id: \.self, content: Text.init)
                        }
                    }
                } else {
                    Section("VLESS Reality") {
                        TextField("UUID", text: $uuid)
                            .textInputAutocapitalization(.never)
                        TextField("Flow", text: $flow)
                            .textInputAutocapitalization(.never)
                        Toggle("TLS", isOn: $tlsEnabled)
                        TextField("Server Name / SNI", text: $serverName)
                            .textInputAutocapitalization(.never)
                        TextField("Fingerprint", text: $fingerprint)
                            .textInputAutocapitalization(.never)
                        TextField("Reality Public Key", text: $realityPublicKey)
                            .textInputAutocapitalization(.never)
                        TextField("Reality Short ID", text: $realityShortID)
                            .textInputAutocapitalization(.never)
                    }
                }
            }
            .navigationTitle(node == nil ? "Add Node" : "Edit Node")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save", action: save)
                        .disabled(!isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Int(port) != nil &&
        (
            (protocolKind == .shadowsocks && !password.isEmpty && !method.isEmpty) ||
            (protocolKind == .vless && !uuid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        )
    }

    private func save() {
        guard let portNumber = Int(port) else { return }

        let updatedNode = ProxyNode(
            id: node?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            host: host.trimmingCharacters(in: .whitespacesAndNewlines),
            port: portNumber,
            protocolKind: protocolKind,
            password: password,
            method: method,
            uuid: uuid.trimmingCharacters(in: .whitespacesAndNewlines),
            flow: flow.trimmingCharacters(in: .whitespacesAndNewlines),
            tlsEnabled: tlsEnabled,
            serverName: serverName.trimmingCharacters(in: .whitespacesAndNewlines),
            fingerprint: fingerprint.trimmingCharacters(in: .whitespacesAndNewlines),
            realityPublicKey: realityPublicKey.trimmingCharacters(in: .whitespacesAndNewlines),
            realityShortID: realityShortID.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        if node == nil {
            store.add(updatedNode)
        } else {
            store.update(updatedNode)
        }

        dismiss()
    }
}

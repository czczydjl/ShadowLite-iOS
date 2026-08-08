import SwiftUI

struct NodeEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: NodeStore

    let node: ProxyNode?

    @State private var name: String
    @State private var host: String
    @State private var port: String
    @State private var password: String
    @State private var method: String

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
        _password = State(initialValue: node?.password ?? "")
        _method = State(initialValue: node?.method ?? "aes-256-gcm")
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Server") {
                    TextField("Name", text: $name)
                    TextField("Host or IP", text: $host)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    TextField("Port", text: $port)
                        .keyboardType(.numberPad)
                }

                Section("Authentication") {
                    SecureField("Password", text: $password)
                    Picker("Method", selection: $method) {
                        ForEach(methods, id: \.self, content: Text.init)
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
        !password.isEmpty
    }

    private func save() {
        guard let portNumber = Int(port) else { return }

        let updatedNode = ProxyNode(
            id: node?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            host: host.trimmingCharacters(in: .whitespacesAndNewlines),
            port: portNumber,
            password: password,
            method: method
        )

        if node == nil {
            store.add(updatedNode)
        } else {
            store.update(updatedNode)
        }

        dismiss()
    }
}

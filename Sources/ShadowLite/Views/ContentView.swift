import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: NodeStore
    @EnvironmentObject private var vpn: VPNManager
    @State private var showingNodeEditor = false
    @State private var showingImporter = false
    @State private var editingNode: ProxyNode?

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                connectionPanel

                List {
                    Section("Nodes") {
                        if store.nodes.isEmpty {
                            Text("Import a VLESS Reality or Shadowsocks node to get started.")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(store.nodes) { node in
                                Button {
                                    store.select(node)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(node.name)
                                                .foregroundColor(.primary)
                                            Text("\(node.protocolKind.displayName) · \(node.host):\(node.port)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        if node.id == store.selectedNodeID {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.accentColor)
                                        }
                                    }
                                }
                                .swipeActions(edge: .trailing) {
                                    Button {
                                        editingNode = node
                                        showingNodeEditor = true
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                            }
                            .onDelete(perform: store.delete)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("ShadowLite")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingImporter = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .accessibilityLabel("Import subscription")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        editingNode = nil
                        showingNodeEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add node")
                }
            }
            .sheet(isPresented: $showingNodeEditor) {
                NodeEditorView(node: editingNode)
                    .environmentObject(store)
            }
            .sheet(isPresented: $showingImporter) {
                ImportSubscriptionView()
                    .environmentObject(store)
            }
        }
    }

    private var connectionPanel: some View {
        VStack(spacing: 12) {
            Image(systemName: vpn.state == .connected ? "lock.shield.fill" : "lock.shield")
                .font(.system(size: 42))
                .foregroundColor(vpn.state == .connected ? .green : .accentColor)

            Text(statusText)
                .font(.headline)

            Button {
                guard let node = store.selectedNode else { return }
                if vpn.state == .connected {
                    vpn.disconnect()
                } else {
                    Task {
                        await vpn.connect(using: node)
                    }
                }
            } label: {
                Text(vpn.state == .connected ? "Disconnect" : "Connect")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.selectedNode == nil || vpn.state == .connecting)

            if let errorMessage = vpn.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal)
        .padding(.top)
    }

    private var statusText: String {
        switch vpn.state {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .failed: return "Connection failed"
        }
    }
}

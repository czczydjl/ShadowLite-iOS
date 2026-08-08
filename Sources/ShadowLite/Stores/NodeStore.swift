import Foundation

@MainActor
final class NodeStore: ObservableObject {
    @Published private(set) var nodes: [ProxyNode] = []
    @Published var selectedNodeID: UUID?

    private let nodesKey = "shadowlite.nodes"
    private let selectedNodeKey = "shadowlite.selectedNode"

    init() {
        load()
    }

    var selectedNode: ProxyNode? {
        guard let selectedNodeID else { return nil }
        return nodes.first { $0.id == selectedNodeID }
    }

    func add(_ node: ProxyNode) {
        nodes.append(node)
        selectedNodeID = node.id
        save()
    }

    func addMany(_ importedNodes: [ProxyNode]) -> Int {
        var inserted = 0
        for node in importedNodes where !containsEquivalentNode(node) {
            nodes.append(node)
            inserted += 1
        }

        if selectedNodeID == nil {
            selectedNodeID = nodes.first?.id
        }

        save()
        return inserted
    }

    func update(_ node: ProxyNode) {
        guard let index = nodes.firstIndex(where: { $0.id == node.id }) else { return }
        nodes[index] = node
        save()
    }

    func delete(at offsets: IndexSet) {
        nodes.remove(atOffsets: offsets)
        if let selectedNodeID, !nodes.contains(where: { $0.id == selectedNodeID }) {
            self.selectedNodeID = nodes.first?.id
        }
        save()
    }

    func select(_ node: ProxyNode) {
        selectedNodeID = node.id
        save()
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: nodesKey),
           let decoded = try? JSONDecoder().decode([ProxyNode].self, from: data) {
            nodes = decoded
        }

        if let idString = UserDefaults.standard.string(forKey: selectedNodeKey) {
            selectedNodeID = UUID(uuidString: idString)
        } else {
            selectedNodeID = nodes.first?.id
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(nodes) {
            UserDefaults.standard.set(data, forKey: nodesKey)
        }
        UserDefaults.standard.set(selectedNodeID?.uuidString, forKey: selectedNodeKey)
    }

    private func containsEquivalentNode(_ node: ProxyNode) -> Bool {
        nodes.contains {
            $0.host == node.host &&
            $0.port == node.port &&
            $0.method == node.method &&
            $0.password == node.password
        }
    }
}

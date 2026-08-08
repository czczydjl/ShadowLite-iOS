import SwiftUI
import UIKit

struct ImportSubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: NodeStore

    @State private var text = ""
    @State private var message: String?
    @State private var parsedNodes: [ProxyNode] = []
    @State private var isLoading = false

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                TextEditor(text: $text)
                    .font(.system(.body, design: .monospaced))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.25))
                    )
                    .padding(.horizontal)

                HStack {
                    Button("Paste") {
                        text = UIPasteboard.general.string ?? text
                    }
                    .buttonStyle(.bordered)

                    Spacer()
                }
                .padding(.horizontal)

                if let message {
                    Text(message)
                        .font(.footnote)
                        .foregroundColor(parsedNodes.isEmpty ? .red : .secondary)
                        .padding(.horizontal)
                }

                Button {
                    Task {
                        await importNodes()
                    }
                } label: {
                    Text(isLoading ? "Importing..." : "Import Nodes")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            }
            .padding(.vertical)
            .navigationTitle("Import")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func importNodes() async {
        isLoading = true
        defer { isLoading = false }

        let importText: String
        do {
            importText = try await resolveImportText(text)
        } catch {
            parsedNodes = []
            message = error.localizedDescription
            return
        }

        let nodes = ShadowsocksURIParser.parseSubscription(importText)
        parsedNodes = nodes

        guard !nodes.isEmpty else {
            message = "No valid ss:// nodes were found."
            return
        }

        let inserted = store.addMany(nodes)
        message = "Imported \(inserted) new node(s)."
        if inserted > 0 {
            dismiss()
        }
    }

    private func resolveImportText(_ value: String) async throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              ["http", "https"].contains(url.scheme?.lowercased()) else {
            return value
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw ImportError.badStatus(httpResponse.statusCode)
        }

        guard let body = String(data: data, encoding: .utf8) else {
            throw ImportError.invalidText
        }

        return body
    }
}

private enum ImportError: LocalizedError {
    case badStatus(Int)
    case invalidText

    var errorDescription: String? {
        switch self {
        case .badStatus(let statusCode):
            return "Subscription request failed with HTTP \(statusCode)."
        case .invalidText:
            return "Subscription response is not valid UTF-8 text."
        }
    }
}

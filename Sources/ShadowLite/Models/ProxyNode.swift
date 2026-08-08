import Foundation

struct ProxyNode: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var host: String
    var port: Int
    var password: String
    var method: String

    init(
        id: UUID = UUID(),
        name: String,
        host: String,
        port: Int,
        password: String,
        method: String
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.password = password
        self.method = method
    }
}

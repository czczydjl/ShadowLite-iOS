import SwiftUI

@main
struct ShadowLiteApp: App {
    @StateObject private var store = NodeStore()
    @StateObject private var vpn = VPNManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(vpn)
        }
    }
}

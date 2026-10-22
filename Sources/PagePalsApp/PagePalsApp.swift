import SwiftUI
import AppKit
import PagePalsCore

@main
struct PagePalsApp: App {
    init() {
        // Needed when started from `swift run` (no app bundle); harmless inside PagePals.app.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup("PagePals") {
            RootView()
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            ContentView()
                .tabItem { Label("Play", systemImage: "gamecontroller") }
            ImportView()
                .tabItem { Label("Import", systemImage: "doc.viewfinder") }
        }
        .frame(minWidth: 900, minHeight: 640)
    }
}

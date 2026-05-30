import SwiftUI

@main
struct BrioToneApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(model)
        } label: {
            Image(systemName: "camera.aperture")
        }
        .menuBarExtraStyle(.window)
    }
}

import SwiftUI

@main
struct MacWallV2App: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window("MacWall v2", id: "main") {
            ContentView(model: model)
        }
        .defaultSize(width: 960, height: 720)
    }
}

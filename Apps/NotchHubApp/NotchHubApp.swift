import NotchActions
import NotchCore
import NotchDomain
import NotchIPC
import NotchSurface
import NotchUI
import SwiftUI

@main
struct NotchHubApp: App {
    var body: some Scene {
        WindowGroup("NotchHub") {
            ContentUnavailableView(
                "Foundation scaffold",
                systemImage: "macbook",
                description: Text("The app shell starts in F1.")
            )
        }
    }
}

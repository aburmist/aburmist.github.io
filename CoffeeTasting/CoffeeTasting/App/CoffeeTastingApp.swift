import SwiftData
import SwiftUI

@main
struct CoffeeTastingApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        .modelContainer(for: TastingNote.self)
    }
}

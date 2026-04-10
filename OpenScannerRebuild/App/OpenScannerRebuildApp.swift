import SwiftUI

@main
struct OpenScannerRebuildApp: App {
    private let dependencies = AppDependencies.live()

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: dependencies)
                .environment(\.managedObjectContext, dependencies.persistenceController.viewContext)
        }
    }
}

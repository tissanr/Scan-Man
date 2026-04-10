//
//  OpenScannerRebuildApp.swift
//  OpenScannerRebuild
//
//  Created by Stephan Reiter on 2026-04-10.
//

import SwiftUI
import CoreData

@main
struct OpenScannerRebuildApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}

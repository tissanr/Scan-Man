import SwiftUI

struct RootView: View {
    let dependencies: AppDependencies

    @Environment(\.scenePhase) private var scenePhase
    @State private var homeViewModel: HomeViewModel?

    private var settings: AppSettings { dependencies.settings }
    private var appLock: AppLockController { dependencies.appLock }

    var body: some View {
        ZStack {
            content

            if appLock.isLocked {
                LockView(appLock: appLock)
                    .transition(.opacity)
            } else if scenePhase != .active && settings.appLockEnabled {
                // Hide document contents in the app switcher.
                PrivacyCoverView()
            }
        }
        .environment(dependencies.settings)
        .environment(dependencies.events)
        .environment(dependencies.ocrCoordinator)
        .environment(dependencies.appLock)
        .task {
            await dependencies.prepareForLaunch()
            homeViewModel = dependencies.makeHomeViewModel()
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            switch phase {
            case .background:
                appLock.sceneDidEnterBackground()
            case .active:
                Task { await appLock.unlock() }
            default:
                break
            }
        }
        .sheet(isPresented: Binding(
            get: { homeViewModel != nil && !settings.hasCompletedOnboarding },
            set: { presented in
                if !presented { settings.hasCompletedOnboarding = true }
            }
        )) {
            OnboardingView(importFolderPath: dependencies.importInbox.importFolderDisplayPath) {
                settings.hasCompletedOnboarding = true
            }
            .interactiveDismissDisabled()
        }
    }

    @ViewBuilder
    private var content: some View {
        if dependencies.persistenceController.loadError != nil {
            ContentUnavailableView(
                "Library Unavailable",
                systemImage: "exclamationmark.triangle",
                description: Text("Scan Man could not open its library. Restart the app; if this keeps happening, free up storage space and try again.")
            )
        } else if let homeViewModel {
            HomeView(viewModel: homeViewModel) { scanID in
                ScanDetailView(viewModel: dependencies.makeScanDetailViewModel(scanID: scanID))
            }
        } else {
            ProgressView()
        }
    }
}

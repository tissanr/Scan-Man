import SwiftUI

struct RootView: View {
    let dependencies: AppDependencies
    @StateObject private var homeViewModel: HomeViewModel

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _homeViewModel = StateObject(wrappedValue: HomeViewModel(
            repository: dependencies.repository,
            titleSuggester: dependencies.titleSuggester,
            ocrProcessor: dependencies.ocrProcessor,
            scanDeviceSupport: dependencies.scanDeviceSupport,
            scanImporter: dependencies.scanImporter,
            importInbox: dependencies.importInbox
        ))
    }

    var body: some View {
        HomeView(
            viewModel: homeViewModel,
            detailFactory: { [homeViewModel] scan in
                ScanDetailView(
                    viewModel: ScanDetailViewModel(
                        scan: scan,
                        repository: dependencies.repository,
                        pdfExporter: dependencies.pdfExporter,
                        onScanUpdated: { updatedScan in
                            homeViewModel.applyUpdatedScan(updatedScan)
                        }
                    )
                )
            }
        )
    }
}

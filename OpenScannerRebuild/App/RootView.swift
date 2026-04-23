import SwiftUI

struct RootView: View {
    let dependencies: AppDependencies

    var body: some View {
        HomeView(
            viewModel: HomeViewModel(
                repository: dependencies.repository,
                titleSuggester: dependencies.titleSuggester,
                ocrProcessor: dependencies.ocrProcessor,
                scanDeviceSupport: dependencies.scanDeviceSupport,
                scanImporter: dependencies.scanImporter,
                importInbox: dependencies.importInbox
            ),
            detailFactory: { scan in
                ScanDetailView(
                    viewModel: ScanDetailViewModel(
                        scan: scan,
                        repository: dependencies.repository,
                        pdfExporter: dependencies.pdfExporter
                    )
                )
            }
        )
    }
}

import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct HomeView<Detail: View>: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Environment(LibraryEvents.self) private var events
    @Environment(OCRCoordinator.self) private var ocrCoordinator

    @State private var viewModel: HomeViewModel
    @State private var navigationPath: [UUID] = []
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isShowingPDFImporter = false
    @State private var isShowingSettings = false
    let detailFactory: (UUID) -> Detail

    init(viewModel: HomeViewModel, detailFactory: @escaping (UUID) -> Detail) {
        _viewModel = State(initialValue: viewModel)
        self.detailFactory = detailFactory
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if viewModel.filteredScans.isEmpty, viewModel.searchText.isEmpty {
                    ContentUnavailableView {
                        Label("No Scans Yet", systemImage: "doc.viewfinder")
                    } description: {
                        Text("Scan paper documents or import photos and PDFs. Everything stays on this device.")
                    }
                } else if viewModel.filteredScans.isEmpty {
                    ContentUnavailableView.search(text: viewModel.searchText)
                } else {
                    scanList
                }
            }
            .navigationTitle("Scans")
            .searchable(text: $viewModel.searchText, prompt: "Search scans")
            .navigationDestination(for: UUID.self) { scanID in
                detailFactory(scanID)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .accessibilityIdentifier("Settings")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            addBar
        }
        .task {
            await viewModel.load()
        }
        .onChange(of: events.revision) {
            Task { await viewModel.reload() }
        }
        .onChange(of: scenePhase) {
            guard scenePhase == .active else { return }
            Task { await viewModel.refreshImportSources() }
        }
        .onChange(of: viewModel.pendingNavigationScanID) {
            guard let scanID = viewModel.consumePendingNavigation() else { return }
            navigationPath.append(scanID)
        }
        .fullScreenCover(isPresented: Binding(
            get: { viewModel.isShowingScanner },
            set: { if !$0 { viewModel.handleScanCancel() } }
        )) {
            DocumentScannerView(
                onFinish: { images in
                    Task { await viewModel.handleScan(images: images) }
                },
                onCancel: { viewModel.handleScanCancel() },
                onFailure: { error in viewModel.handleScanFailure(error) }
            )
            .ignoresSafeArea()
        }
        .fileImporter(
            isPresented: $isShowingPDFImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task { await importPDF(at: url) }
            case .failure(let error):
                viewModel.handleScanFailure(error)
            }
        }
        .onChange(of: selectedPhotoItems) {
            let items = selectedPhotoItems
            guard !items.isEmpty else { return }
            selectedPhotoItems = []
            Task { await viewModel.importPhotos(from: await PhotoLoader.loadData(from: items)) }
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
        .alert(
            "Scan Man",
            isPresented: Binding(
                get: { viewModel.activeErrorMessage != nil },
                set: { if !$0 { viewModel.dismissError() } }
            ),
            actions: {
                if viewModel.errorOffersSettingsLink {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                        viewModel.dismissError()
                    }
                }
                Button("OK", role: .cancel) {
                    viewModel.dismissError()
                }
            },
            message: {
                Text(viewModel.activeErrorMessage ?? "")
            }
        )
    }

    private var scanList: some View {
        List {
            ForEach(viewModel.filteredScans) { scan in
                NavigationLink(value: scan.id) {
                    ScanListRow(scan: scan, isRecognizingText: ocrCoordinator.isRecognizing(scanID: scan.id))
                }
                .accessibilityLabel("Open \(scan.title)")
                .swipeActions {
                    Button(role: .destructive) {
                        Task { await viewModel.delete(scan) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private var addBar: some View {
        VStack(spacing: 8) {
            Menu {
                Button {
                    viewModel.beginScan()
                } label: {
                    Label("Scan Document", systemImage: "doc.viewfinder")
                }

                PhotosPicker(
                    selection: $selectedPhotoItems,
                    maxSelectionCount: 50,
                    selectionBehavior: .ordered,
                    matching: .images
                ) {
                    Label("Import Photos", systemImage: "photo.on.rectangle")
                }

                Button {
                    isShowingPDFImporter = true
                } label: {
                    Label("Import PDF", systemImage: "doc.richtext")
                }
            } label: {
                Label(viewModel.isImporting ? "Working…" : "Add Scan", systemImage: "plus.viewfinder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.isImporting)
            .accessibilityLabel(viewModel.scanButtonAccessibilityLabel)
            .accessibilityIdentifier("AddScan")

            if let scanSupportMessage = viewModel.scanSupportMessage {
                Text(scanSupportMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("Scanning availability")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(.bar)
    }

    private func importPDF(at url: URL) async {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess { url.stopAccessingSecurityScopedResource() }
        }

        do {
            let data = try Data(contentsOf: url)
            await viewModel.handleImportedPDF(data)
        } catch {
            viewModel.handleScanFailure(error)
        }
    }
}

/// Loads picked photos in selection order.
enum PhotoLoader {
    static func loadData(from items: [PhotosPickerItem]) async -> [Data] {
        var results: [Data] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                results.append(data)
            }
        }
        return results
    }
}

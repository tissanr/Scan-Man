import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct HomeView<Detail: View>: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel: HomeViewModel
    @State private var navigationPath: [ScanDocument] = []
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isShowingPDFImporter = false
    let detailFactory: (ScanDocument) -> Detail

    init(viewModel: HomeViewModel, detailFactory: @escaping (ScanDocument) -> Detail) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.detailFactory = detailFactory
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if viewModel.filteredScans.isEmpty, viewModel.searchText.isEmpty {
                    EmptyLibraryView(
                        title: "No Scans Yet",
                        message: "Scan paper documents and keep everything stored locally on this device.",
                        systemImage: "doc.viewfinder"
                    )
                } else if viewModel.filteredScans.isEmpty {
                    EmptyLibraryView(
                        title: "No Results",
                        message: "Try a different search term.",
                        systemImage: "magnifyingglass"
                    )
                } else {
                    List {
                        ForEach(viewModel.filteredScans) { scan in
                            NavigationLink(value: scan) {
                                ScanListRow(scan: scan)
                            }
                            .accessibilityLabel("Open \(scan.title)")
                            .swipeActions {
                                Button(role: .destructive) {
                                    Task {
                                        await viewModel.delete(scan)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Scans")
            .searchable(text: Binding(
                get: { viewModel.searchText },
                set: { viewModel.searchText = $0 }
            ), prompt: "Search scans")
            .navigationDestination(for: ScanDocument.self) { scan in
                detailFactory(scan)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Menu {
                    Button {
                        viewModel.beginScan()
                    } label: {
                        Label("Scan Document", systemImage: "plus.viewfinder")
                    }

                    PhotosPicker(
                        selection: $selectedPhotoItems,
                        maxSelectionCount: 24,
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
                    Label(viewModel.isImporting ? "Working..." : "Add Scan", systemImage: "plus.viewfinder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isImporting)
                .accessibilityLabel(viewModel.scanButtonAccessibilityLabel)

                if let scanSupportMessage = viewModel.scanSupportMessage {
                    Text(scanSupportMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .accessibilityLabel("Scanning availability")
                }

                Text("Import folder: \(viewModel.importFolderDisplayPath)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("Import folder path")
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .background(.bar)
        }
        .task {
            await viewModel.load()
        }
        .onChange(of: scenePhase) {
            guard scenePhase == .active else {
                return
            }

            Task {
                await viewModel.refreshImportSources()
            }
        }
        .onChange(of: viewModel.pendingNavigationScan) {
            let scan = viewModel.pendingNavigationScan
            guard let scan else {
                return
            }

            navigationPath.append(scan)
            _ = viewModel.consumePendingNavigation()
        }
        .sheet(isPresented: Binding(
            get: { viewModel.isShowingScanner },
            set: { isPresented in
                if !isPresented {
                    viewModel.handleScanCancel()
                }
            }
        )) {
            DocumentScannerView(
                onFinish: { images in
                    Task {
                        await viewModel.handleScan(images: images)
                    }
                },
                onCancel: {
                    viewModel.handleScanCancel()
                },
                onFailure: { error in
                    viewModel.handleScanFailure(error)
                }
            )
        }
        .fileImporter(
            isPresented: $isShowingPDFImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else {
                    return
                }

                Task {
                    await importPDF(at: url)
                }
            case .failure(let error):
                viewModel.handleScanFailure(error)
            }
        }
        .onChange(of: selectedPhotoItems) {
            let items = selectedPhotoItems
            guard !items.isEmpty else {
                return
            }

            Task {
                await importPhotos(from: items)
                selectedPhotoItems = []
            }
        }
        .alert(
            "Open Scanner",
            isPresented: Binding(
                get: { viewModel.activeErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        viewModel.dismissError()
                    }
                }
            ),
            actions: {
                Button("OK", role: .cancel) {
                    viewModel.dismissError()
                }
            },
            message: {
                Text(viewModel.activeErrorMessage ?? "")
            }
        )
    }

    private func importPhotos(from items: [PhotosPickerItem]) async {
        let loadedData = await withTaskGroup(of: Data?.self) { group in
            for item in items {
                group.addTask {
                    try? await item.loadTransferable(type: Data.self)
                }
            }

            var results: [Data] = []
            for await data in group {
                if let data {
                    results.append(data)
                }
            }
            return results
        }

        await viewModel.importPhotos(from: loadedData)
    }

    private func importPDF(at url: URL) async {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            await viewModel.handleImportedPDF(data)
        } catch {
            viewModel.handleScanFailure(error)
        }
    }
}

private struct EmptyLibraryView: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 42))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.title3.weight(.semibold))

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

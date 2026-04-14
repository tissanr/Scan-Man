import SwiftUI

struct HomeView<Detail: View>: View {
    @StateObject private var viewModel: HomeViewModel
    @State private var navigationPath: [ScanDocument] = []
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
                Button {
                    viewModel.beginScan()
                } label: {
                    Label("Scan", systemImage: "plus.viewfinder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel(viewModel.scanButtonAccessibilityLabel)

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
        .task {
            await viewModel.load()
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

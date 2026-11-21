import PhotosUI
import SwiftUI
import UIKit

struct ScanDetailView: View {
    @Environment(LibraryEvents.self) private var events
    @Environment(\.openURL) private var openURL
    @State private var viewModel: ScanDetailViewModel
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isSavingNotes = false
    @FocusState private var isTitleFocused: Bool

    init(viewModel: ScanDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Group {
            if viewModel.scan != nil {
                content
            } else if viewModel.isLoaded {
                ContentUnavailableView("Scan Deleted", systemImage: "trash", description: Text("This scan is no longer in your library."))
            } else {
                ProgressView()
            }
        }
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
        .onChange(of: events.revision) {
            Task { await viewModel.load() }
        }
        .onChange(of: isTitleFocused) {
            if !isTitleFocused {
                Task { await viewModel.saveTitle() }
            }
        }
        .onDisappear {
            Task { await viewModel.saveTitle() }
        }
        .onChange(of: selectedPhotoItems) {
            let items = selectedPhotoItems
            guard !items.isEmpty else { return }
            selectedPhotoItems = []
            Task { await viewModel.appendPages(fromImageData: await PhotoLoader.loadData(from: items)) }
        }
        .fullScreenCover(isPresented: Binding(
            get: { viewModel.isShowingScanner },
            set: { if !$0 { viewModel.cancelScanningPages() } }
        )) {
            DocumentScannerView(
                onFinish: { images in Task { await viewModel.appendScannedImages(images) } },
                onCancel: { viewModel.cancelScanningPages() },
                onFailure: { viewModel.handleScanFailure($0) }
            )
            .ignoresSafeArea()
        }
        .sheet(isPresented: Binding(
            get: { viewModel.exportedFile != nil },
            set: { if !$0 { viewModel.dismissShareSheet() } }
        )) {
            if let exportedFile = viewModel.exportedFile {
                ShareSheet(activityItems: [exportedFile.url])
            }
        }
        .alert(
            "Scan Man",
            isPresented: Binding(
                get: { viewModel.activeErrorMessage != nil },
                set: { if !$0 { viewModel.dismissError() } }
            ),
            actions: {
                Button("OK", role: .cancel) { viewModel.dismissError() }
            },
            message: {
                Text(viewModel.activeErrorMessage ?? "")
            }
        )
    }

    private var content: some View {
        List {
            Section("Title") {
                TextField("Scan title", text: $viewModel.titleDraft)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .focused($isTitleFocused)
                    .onSubmit { Task { await viewModel.saveTitle() } }
            }

            Section {
                TextEditor(text: $viewModel.notesDraft)
                    .frame(minHeight: 100)
                    .accessibilityLabel("Scan notes editor")

                Button(isSavingNotes ? "Saving…" : "Save Notes") {
                    Task {
                        isSavingNotes = true
                        await viewModel.saveNotes()
                        isSavingNotes = false
                    }
                }
                .disabled(isSavingNotes || !viewModel.hasUnsavedNotes)
                .accessibilityLabel("Save notes")
            } header: {
                Text("Notes")
            } footer: {
                Text("Notes stay on this device and are included in search.")
            }

            Section {
                ForEach(viewModel.pages) { page in
                    NavigationLink {
                        ScanPageDetailView(viewModel: viewModel, pageID: page.id)
                    } label: {
                        PageRow(page: page, position: (viewModel.pages.firstIndex(of: page) ?? 0) + 1)
                    }
                    .accessibilityLabel("Open page \((viewModel.pages.firstIndex(of: page) ?? 0) + 1)")
                    .contextMenu {
                        pageContextMenu(for: page)
                    }
                }
                .onMove { source, destination in
                    Task { await viewModel.movePages(from: source, to: destination) }
                }
                .onDelete { offsets in
                    Task { await viewModel.deletePages(at: offsets) }
                }
                .deleteDisabled(!viewModel.canDeletePages)
            } header: {
                HStack {
                    Text("Pages")
                    Spacer()
                    if viewModel.isRecognizingText {
                        Label("Reading text…", systemImage: "text.viewfinder")
                            .labelStyle(.titleAndIcon)
                            .textCase(nil)
                    }
                }
            } footer: {
                Text("Tap Edit to reorder or delete pages. Touch and hold a page for more options.")
            }

            Section("Share") {
                Button("Share PDF") {
                    Task { await viewModel.exportPDF(mode: .imageOnly) }
                }
                .accessibilityLabel("Share as PDF")

                Button("Share Searchable PDF") {
                    Task { await viewModel.exportPDF(mode: .searchable) }
                }
                .accessibilityLabel("Share as searchable PDF")

                Button("Share Text") {
                    Task { await viewModel.exportText() }
                }
                .accessibilityLabel("Share extracted text")
            }
            .disabled(viewModel.isWorking)
        }
        .overlay {
            if viewModel.isWorking {
                ProgressView()
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Button {
                        viewModel.beginScanningPages()
                    } label: {
                        Label("Scan Pages", systemImage: "doc.viewfinder")
                    }

                    PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 50,
                                 selectionBehavior: .ordered, matching: .images) {
                        Label("Add Photos", systemImage: "photo.on.rectangle")
                    }
                } label: {
                    Label("Add Pages", systemImage: "plus")
                }
                .accessibilityIdentifier("AddPages")
                .disabled(viewModel.isWorking)

                EditButton()
            }
        }
    }

    @ViewBuilder
    private func pageContextMenu(for page: ScanPage) -> some View {
        Button {
            Task { await viewModel.rotatePage(page.id, clockwise: false) }
        } label: {
            Label("Rotate Left", systemImage: "rotate.left")
        }
        Button {
            Task { await viewModel.rotatePage(page.id, clockwise: true) }
        } label: {
            Label("Rotate Right", systemImage: "rotate.right")
        }
        Button(role: .destructive) {
            Task { await viewModel.deletePage(page.id) }
        } label: {
            Label("Delete Page", systemImage: "trash")
        }
        .disabled(!viewModel.canDeletePages)
    }
}

private struct PageRow: View {
    let page: ScanPage
    let position: Int

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Group {
                if let image = UIImage(data: page.thumbnailData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle().fill(Color.secondary.opacity(0.15))
                }
            }
            .frame(width: 64, height: 84)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text("Page \(position)")
                    .font(.headline)

                if page.previewText.isEmpty {
                    Text("Tap to view full page")
                        .foregroundStyle(.secondary)
                } else {
                    Text(page.previewText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

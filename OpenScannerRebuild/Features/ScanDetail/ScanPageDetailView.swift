import SwiftUI

struct ScanPageDetailView: View {
    let viewModel: ScanDetailViewModel
    let pageID: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var editedText = ""
    @State private var loadedText: String?
    @State private var selectedObservationID: String?
    @State private var isSaving = false
    @State private var cropRequest: CropRequest?
    @FocusState private var isEditingText: Bool

    private var page: ScanPage? {
        viewModel.page(for: pageID)
    }

    private var position: Int {
        (viewModel.pages.firstIndex { $0.id == pageID } ?? 0) + 1
    }

    var body: some View {
        Group {
            if let page {
                content(for: page)
            } else {
                ContentUnavailableView("Page Deleted", systemImage: "doc", description: Text("This page is no longer part of the scan."))
            }
        }
        .navigationTitle("Page \(position)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: syncText)
        .onChange(of: page?.recognizedText) { syncText() }
        .sheet(item: $cropRequest) { request in
            CropView(imageData: request.imageData, initialQuad: request.quad) { quad in
                cropRequest = nil
                Task { await viewModel.cropPage(pageID, to: quad) }
            } onCancel: {
                cropRequest = nil
            }
        }
    }

    private func content(for page: ScanPage) -> some View {
        List {
            Section("Preview") {
                PagePreviewView(page: page, selectedObservationID: selectedObservationID)
                    .frame(minHeight: 320)
                    .listRowInsets(EdgeInsets())
                    .accessibilityLabel("Page preview")
            }

            Section("Detected Layout") {
                if page.hasOCRLayout {
                    Text("Detected lines are highlighted on the page and listed in reading order.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    ForEach(Array(page.orderedTextObservations.enumerated()), id: \.offset) { index, observation in
                        Button {
                            selectedObservationID = observation.layoutID
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 24, alignment: .leading)

                                Text(observation.text)
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(10)
                            .background(observation.layoutID == selectedObservationID ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Highlight detected text \(index + 1)")
                    }
                } else if viewModel.isRecognizingText {
                    Label("Reading text…", systemImage: "text.viewfinder")
                        .foregroundStyle(.secondary)
                } else {
                    Text("No layout is available for this page. You can still review and edit the text below.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Extracted Text") {
                TextEditor(text: $editedText)
                    .frame(minHeight: 180)
                    .focused($isEditingText)
                    .accessibilityLabel("Extracted text editor")

                Button(isSaving ? "Saving…" : "Save Text") {
                    isEditingText = false
                    Task { await save() }
                }
                .disabled(isSaving || editedText.normalizedOCRText == page.recognizedText)
                .accessibilityLabel("Save extracted text")
            }
        }
        .overlay {
            if viewModel.isWorking {
                ProgressView()
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                pageActions(for: page)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isEditingText = false }
                    .accessibilityIdentifier("DismissKeyboard")
            }
        }
    }

    private func pageActions(for page: ScanPage) -> some View {
        Menu {
            Button {
                Task { await viewModel.rotatePage(pageID, clockwise: false) }
            } label: {
                Label("Rotate Left", systemImage: "rotate.left")
            }

            Button {
                Task { await viewModel.rotatePage(pageID, clockwise: true) }
            } label: {
                Label("Rotate Right", systemImage: "rotate.right")
            }

            Button {
                Task {
                    let detected = await viewModel.detectDocument(in: pageID)
                    cropRequest = CropRequest(imageData: page.imageData, quad: detected ?? .fullImage)
                }
            } label: {
                Label("Crop…", systemImage: "crop")
            }

            Picker(selection: Binding(
                get: { page.enhancement },
                set: { enhancement in Task { await viewModel.setEnhancement(enhancement, for: pageID) } }
            )) {
                ForEach(ImageEnhancement.allCases) { enhancement in
                    Text(enhancement.displayName).tag(enhancement)
                }
            } label: {
                Label("Filter", systemImage: "camera.filters")
            }
            .pickerStyle(.menu)

            Divider()

            Button(role: .destructive) {
                Task {
                    await viewModel.deletePage(pageID)
                    if viewModel.page(for: pageID) == nil {
                        dismiss()
                    }
                }
            } label: {
                Label("Delete Page", systemImage: "trash")
            }
            .disabled(!viewModel.canDeletePages)
        } label: {
            Label("Page Actions", systemImage: "ellipsis.circle")
        }
        .accessibilityIdentifier("PageActions")
        .disabled(viewModel.isWorking)
    }

    /// Follows the stored text unless the user has unsaved edits.
    private func syncText() {
        guard let stored = page?.recognizedText else { return }
        if loadedText == nil || editedText.normalizedOCRText == loadedText {
            editedText = stored
        }
        loadedText = stored
    }

    private func save() async {
        isSaving = true
        let didSave = await viewModel.updateRecognizedText(for: pageID, text: editedText)
        isSaving = false
        if didSave, let stored = page?.recognizedText {
            editedText = stored
            loadedText = stored
        }
    }
}

private struct CropRequest: Identifiable {
    let id = UUID()
    let imageData: Data
    let quad: DocumentQuad
}

extension OCRTextObservation {
    /// Stable identifier for highlighting a line in the preview.
    var layoutID: String {
        "\(text)|\(boundingBox.x)|\(boundingBox.y)|\(boundingBox.width)|\(boundingBox.height)"
    }
}

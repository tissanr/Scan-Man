import SwiftUI

struct ScanPageDetailView: View {
    let saveRecognizedText: (String) async -> Bool
    let reloadPage: () -> ScanPage?

    @State private var currentPage: ScanPage
    @State private var editedText: String
    @State private var selectedObservationID: String?
    @State private var isSaving = false
    @State private var activeErrorMessage: String?

    init(
        page: ScanPage,
        saveRecognizedText: @escaping (String) async -> Bool,
        reloadPage: @escaping () -> ScanPage?
    ) {
        self.saveRecognizedText = saveRecognizedText
        self.reloadPage = reloadPage
        _currentPage = State(initialValue: page)
        _editedText = State(initialValue: page.recognizedText)
    }

    var body: some View {
        List {
            Section("Preview") {
                PagePreviewView(
                    page: currentPage,
                    selectedObservationID: selectedObservationID
                )
                .frame(minHeight: 320)
                .listRowInsets(EdgeInsets())
                .accessibilityLabel("Page preview")
            }

            if currentPage.hasOCRLayout {
                Section("Detected Layout") {
                    Text("Stored OCR geometry is shown on the page preview and lines are ordered for reading.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    ForEach(Array(currentPage.orderedTextObservations.enumerated()), id: \.offset) { index, observation in
                        Button {
                            selectedObservationID = observation.id
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
                            .background(observation.id == selectedObservationID ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Highlight detected text \(index + 1)")
                    }
                }
            } else {
                Section("Detected Layout") {
                    Text("Layout highlights are unavailable for this page. You can still review and edit the extracted text below.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Extracted Text") {
                TextEditor(text: $editedText)
                    .frame(minHeight: 180)
                    .accessibilityLabel("Extracted text editor")

                Button(isSaving ? "Saving..." : "Save Text") {
                    Task {
                        await save()
                    }
                }
                .disabled(isSaving || editedText.normalizedOCRText == currentPage.recognizedText)
                .accessibilityLabel("Save extracted text")
            }
        }
        .navigationTitle("Page \(currentPage.order + 1)")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "Open Scanner",
            isPresented: Binding(
                get: { activeErrorMessage != nil },
                set: { presented in
                    if !presented {
                        activeErrorMessage = nil
                    }
                }
            ),
            actions: {
                Button("OK", role: .cancel) {
                    activeErrorMessage = nil
                }
            },
            message: {
                Text(activeErrorMessage ?? "")
            }
        )
    }

    @MainActor
    private func save() async {
        isSaving = true
        let didSave = await saveRecognizedText(editedText)
        isSaving = false

        guard didSave else {
            activeErrorMessage = "Open Scanner could not save the edited text."
            return
        }

        let refreshedPage = reloadPage() ?? currentPage
        currentPage = refreshedPage
        editedText = refreshedPage.recognizedText
    }
}

private extension OCRTextObservation {
    var id: String {
        "\(text)|\(boundingBox.x)|\(boundingBox.y)|\(boundingBox.width)|\(boundingBox.height)"
    }
}

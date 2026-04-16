import SwiftUI
import UIKit

struct ScanDetailView: View {
    @StateObject private var viewModel: ScanDetailViewModel
    @State private var notesDraft = ""
    @State private var isSavingNotes = false

    init(viewModel: ScanDetailViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        List {
            Section("Title") {
                TextField("Scan title", text: Binding(
                    get: { viewModel.title },
                    set: { viewModel.title = $0 }
                ))
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .onSubmit {
                        Task {
                            await viewModel.saveTitle()
                        }
                    }
            }

            Section("Notes") {
                TextEditor(text: $notesDraft)
                    .frame(minHeight: 120)
                    .accessibilityLabel("Scan notes editor")

                Text("Lightweight notes stay local and become searchable with the rest of the scan.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button(isSavingNotes ? "Saving..." : "Save Notes") {
                    Task {
                        viewModel.notes = notesDraft
                        isSavingNotes = true
                        let didSave = await viewModel.saveNotes()
                        isSavingNotes = false
                        if didSave {
                            notesDraft = viewModel.notes
                        }
                    }
                }
                .disabled(isSavingNotes || normalizedNotesDraft == normalizedStoredNotes)
                .accessibilityLabel("Save notes")
            }

            Section("Pages") {
                ForEach(viewModel.scan.pages.sorted(by: { $0.order < $1.order })) { page in
                    NavigationLink {
                        ScanPageDetailView(
                            page: page,
                            saveRecognizedText: { updatedText in
                                await viewModel.updateRecognizedText(for: page.id, text: updatedText)
                            },
                            reloadPage: {
                                viewModel.page(for: page.id)
                            }
                        )
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            previewImage(for: page)
                                .frame(width: 64, height: 84)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Page \(page.order + 1)")
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
                    }
                    .accessibilityLabel("Open page \(page.order + 1)")
                    .padding(.vertical, 4)
                }
            }

            Section("Share") {
                Button("Share PDF") {
                    viewModel.exportPDF(mode: .imageOnly)
                }
                .accessibilityLabel("Share as PDF")

                Button("Share Searchable PDF") {
                    viewModel.exportPDF(mode: .searchable)
                }
                .accessibilityLabel("Share as searchable PDF")

                Button("Share Text") {
                    viewModel.exportText()
                }
                .accessibilityLabel("Share extracted text")
            }
        }
        .navigationTitle(viewModel.scan.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.refresh()
            notesDraft = viewModel.notes
        }
        .sheet(
            isPresented: Binding(
                get: { viewModel.exportedFile != nil },
                set: { presented in
                    if !presented {
                        viewModel.dismissShareSheet()
                    }
                }
            )
        ) {
            if let exportedFile = viewModel.exportedFile {
                ShareSheet(activityItems: [exportedFile.url])
            }
        }
        .alert(
            "Open Scanner",
            isPresented: Binding(
                get: { viewModel.activeErrorMessage != nil },
                set: { presented in
                    if !presented {
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

    @ViewBuilder
    private func previewImage(for page: ScanPage) -> some View {
        if let image = UIImage(data: page.thumbnailData.isEmpty ? page.imageData : page.thumbnailData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Rectangle()
                .fill(Color.secondary.opacity(0.15))
        }
    }

    private var normalizedNotesDraft: String {
        notesDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedStoredNotes: String {
        viewModel.notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

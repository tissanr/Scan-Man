import SwiftUI
import UIKit

struct ScanDetailView: View {
    @StateObject private var viewModel: ScanDetailViewModel

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

            Section("Pages") {
                ForEach(viewModel.scan.pages.sorted(by: { $0.order < $1.order })) { page in
                    NavigationLink {
                        PagePreviewView(page: page)
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
}

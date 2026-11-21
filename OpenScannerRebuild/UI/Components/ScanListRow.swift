import SwiftUI
import UIKit

struct ScanListRow: View {
    let scan: ScanSummary
    var isRecognizingText = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            thumbnail
                .frame(width: 56, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(scan.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("ScanTitle")

                Text("\(scan.updatedAt.scanTimestampLabel) · \(scan.pageCount) \(scan.pageCount == 1 ? "page" : "pages")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if isRecognizingText {
                    Label("Reading text…", systemImage: "text.viewfinder")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if !scan.previewText.isEmpty {
                    Text(scan.previewText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let data = scan.thumbnailData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Rectangle()
                .fill(Color.secondary.opacity(0.1))
                .overlay {
                    Image(systemName: "doc.text.image")
                        .foregroundStyle(.secondary)
                }
        }
    }
}

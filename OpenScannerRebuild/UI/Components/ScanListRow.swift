import SwiftUI
import UIKit

struct ScanListRow: View {
    let scan: ScanDocument

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            thumbnail
                .frame(width: 56, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 6) {
                Text(scan.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("ScanTitle")

                Text(scan.updatedAt.scanTimestampLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if !scan.previewText.isEmpty {
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
        if let page = scan.pages.sorted(by: { $0.order < $1.order }).first,
           let image = UIImage(data: page.thumbnailData.isEmpty ? page.imageData : page.thumbnailData) {
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

import SwiftUI
import UIKit

struct PagePreviewView: View {
    let page: ScanPage
    var selectedObservationID: String? = nil

    var body: some View {
        Group {
            if let image = UIImage(data: page.imageData) {
                GeometryReader { geometry in
                    ZoomableScrollView {
                        ZStack {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.black)

                            OCRLayoutOverlay(
                                page: page,
                                imageSize: image.size,
                                containerSize: geometry.size,
                                selectedObservationID: selectedObservationID
                            )
                            .accessibilityIdentifier("Detected Layout")
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black)
                    }
                }
                .accessibilityIdentifier("Page preview")
                .background(Color.black.ignoresSafeArea())
            } else {
                ContentUnavailableStateView(
                    title: "Preview Unavailable",
                    message: "Open Scanner could not load this page image.",
                    systemImage: "photo"
                )
            }
        }
        .navigationTitle("Page \(page.order + 1)")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.black)
    }
}

private struct OCRLayoutOverlay: View {
    let page: ScanPage
    let imageSize: CGSize
    let containerSize: CGSize
    let selectedObservationID: String?

    var body: some View {
        let imageRect = fittedRect(for: imageSize, in: CGRect(origin: .zero, size: containerSize))

        ZStack(alignment: .topLeading) {
            ForEach(Array(page.orderedTextObservations.enumerated()), id: \.offset) { _, observation in
                let rect = observationRect(for: observation.boundingBox, in: imageRect)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(observation.id == selectedObservationID ? Color.accentColor : Color.yellow.opacity(0.8), lineWidth: observation.id == selectedObservationID ? 3 : 1)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(observation.id == selectedObservationID ? Color.accentColor.opacity(0.18) : Color.yellow.opacity(0.10))
                    )
                    .frame(width: rect.width, height: rect.height)
                    .offset(x: rect.minX, y: rect.minY)
                    .accessibilityHidden(true)
            }
        }
    }

    private func fittedRect(for imageSize: CGSize, in bounds: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return bounds
        }

        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: bounds.midX - (size.width / 2),
            y: bounds.midY - (size.height / 2),
            width: size.width,
            height: size.height
        )
    }

    private func observationRect(for boundingBox: OCRBoundingBox, in drawnImageRect: CGRect) -> CGRect {
        CGRect(
            x: drawnImageRect.minX + (drawnImageRect.width * boundingBox.x),
            y: drawnImageRect.minY + (drawnImageRect.height * (1 - boundingBox.y - boundingBox.height)),
            width: drawnImageRect.width * boundingBox.width,
            height: drawnImageRect.height * boundingBox.height
        )
    }
}

private extension OCRTextObservation {
    var id: String {
        "\(text)|\(boundingBox.x)|\(boundingBox.y)|\(boundingBox.width)|\(boundingBox.height)"
    }
}

private struct ZoomableScrollView<Content: View>: UIViewRepresentable {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(hostingController: UIHostingController(rootView: content))
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 4
        scrollView.bouncesZoom = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.backgroundColor = .black

        let hostedView = context.coordinator.hostingController.view!
        hostedView.translatesAutoresizingMaskIntoConstraints = false
        hostedView.backgroundColor = .black

        scrollView.addSubview(hostedView)

        NSLayoutConstraint.activate([
            hostedView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hostedView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hostedView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hostedView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            hostedView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            hostedView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.hostingController.rootView = content
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        let hostingController: UIHostingController<Content>

        init(hostingController: UIHostingController<Content>) {
            self.hostingController = hostingController
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            hostingController.view
        }
    }
}

private struct ContentUnavailableStateView: View {
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

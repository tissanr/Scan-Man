import SwiftUI
import UIKit

/// Lets the user drag the four document corners; applying straightens the page.
struct CropView: View {
    let imageData: Data
    let onApply: (DocumentQuad) -> Void
    let onCancel: () -> Void

    @State private var quad: DocumentQuad
    private let image: UIImage?

    init(imageData: Data, initialQuad: DocumentQuad, onApply: @escaping (DocumentQuad) -> Void, onCancel: @escaping () -> Void) {
        self.imageData = imageData
        self.onApply = onApply
        self.onCancel = onCancel
        self.image = UIImage(data: imageData)
        _quad = State(initialValue: initialQuad)
    }

    private static let cornerNames = ["Top left corner", "Top right corner", "Bottom right corner", "Bottom left corner"]

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                if let image {
                    let rect = Self.fittedRect(for: image.size, in: CGRect(origin: .zero, size: geometry.size).insetBy(dx: 24, dy: 24))
                    let points = quad.corners.map { CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height) }

                    ZStack(alignment: .topLeading) {
                        Image(uiImage: image)
                            .resizable()
                            .frame(width: rect.width, height: rect.height)
                            .position(x: rect.midX, y: rect.midY)
                            .accessibilityHidden(true)

                        QuadShape(points: points)
                            .fill(Color.accentColor.opacity(0.15))
                        QuadShape(points: points)
                            .stroke(Color.accentColor, lineWidth: 2)

                        ForEach(0..<4, id: \.self) { index in
                            Circle()
                                .fill(Color.accentColor)
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                                .frame(width: 28, height: 28)
                                .contentShape(Circle().inset(by: -16))
                                .position(points[index])
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            let normalized = CGPoint(
                                                x: (value.location.x - rect.minX) / rect.width,
                                                y: (value.location.y - rect.minY) / rect.height
                                            )
                                            quad = quad.settingCorner(index, to: normalized).clamped()
                                        }
                                )
                                .accessibilityLabel(Self.cornerNames[index])
                        }
                    }
                } else {
                    ContentUnavailableView("Image Unavailable", systemImage: "photo")
                }
            }
            .background(Color.black)
            .navigationTitle("Crop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { onApply(quad) }
                        .disabled(image == nil)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("Reset to Full Page") { quad = .fullImage }
                }
            }
        }
    }

    static func fittedRect(for imageSize: CGSize, in bounds: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, bounds.width > 0, bounds.height > 0 else {
            return bounds
        }
        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2, width: size.width, height: size.height)
    }
}

private struct QuadShape: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        points.dropFirst().forEach { path.addLine(to: $0) }
        path.closeSubpath()
        return path
    }
}

extension DocumentQuad {
    /// Returns a copy with one corner moved (0 = top left, clockwise).
    func settingCorner(_ index: Int, to point: CGPoint) -> DocumentQuad {
        var copy = self
        switch index {
        case 0: copy.topLeft = point
        case 1: copy.topRight = point
        case 2: copy.bottomRight = point
        default: copy.bottomLeft = point
        }
        return copy
    }
}

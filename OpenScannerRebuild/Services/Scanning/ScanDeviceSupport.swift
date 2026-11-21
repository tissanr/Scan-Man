import AVFoundation
import Foundation
import VisionKit

nonisolated enum CameraAccess: Sendable {
    case authorized
    case notDetermined
    case denied
}

@MainActor
protocol ScanDeviceSupporting {
    var canScanDocuments: Bool { get }
    var unavailableMessage: String { get }
    var cameraAccess: CameraAccess { get }
}

struct ScanDeviceSupport: ScanDeviceSupporting {
    var canScanDocuments: Bool {
        VNDocumentCameraViewController.isSupported
    }

    var unavailableMessage: String {
        "Document scanning requires a supported iPhone or iPad camera. The rest of the app still works in the simulator."
    }

    var cameraAccess: CameraAccess {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: .authorized
        case .notDetermined: .notDetermined
        default: .denied
        }
    }
}

import Foundation
import VisionKit

protocol ScanDeviceSupporting {
    var canScanDocuments: Bool { get }
    var unavailableMessage: String { get }
}

struct ScanDeviceSupport: ScanDeviceSupporting {
    var canScanDocuments: Bool {
        VNDocumentCameraViewController.isSupported
    }

    var unavailableMessage: String {
        "Document scanning requires a supported iPhone or iPad camera. The rest of the app still works in the simulator."
    }
}

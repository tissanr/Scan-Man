import Foundation

extension ScanEntity {
    var orderedPages: [ScanPageEntity] {
        let pageSet = pages as? Set<ScanPageEntity> ?? []
        return pageSet.sorted { $0.order < $1.order }
    }
}

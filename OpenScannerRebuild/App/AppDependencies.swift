import Foundation

struct AppDependencies {
    let persistenceController: PersistenceController
    let repository: ScanRepository
    let ocrService: OCRRecognizing
    let pdfExporter: PDFExporting
    let titleSuggester: TitleSuggesting
    let scanDeviceSupport: ScanDeviceSupporting
    let scanImporter: ScanImporting

    static func live() -> AppDependencies {
        let persistenceController = PersistenceController()
        let repository = CoreDataScanRepository(persistenceController: persistenceController)
        let titleSuggester = TitleSuggestionService()
        return AppDependencies(
            persistenceController: persistenceController,
            repository: repository,
            ocrService: VisionOCRService(),
            pdfExporter: PDFExportService(),
            titleSuggester: titleSuggester,
            scanDeviceSupport: ScanDeviceSupport(),
            scanImporter: ScanImportService()
        )
    }
}

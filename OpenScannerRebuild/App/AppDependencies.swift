import Foundation

struct AppDependencies {
    let persistenceController: PersistenceController
    let repository: ScanRepository
    let ocrService: OCRRecognizing
    let pdfExporter: PDFExporting
    let titleSuggester: TitleSuggesting
    let ocrProcessor: ScanOCRProcessing
    let scanDeviceSupport: ScanDeviceSupporting
    let scanImporter: ScanImporting
    let importInbox: ImportInboxManaging

    static func live() -> AppDependencies {
        let persistenceController = PersistenceController()
        let repository = CoreDataScanRepository(persistenceController: persistenceController)
        let titleSuggester = TitleSuggestionService()
        let ocrService = VisionOCRService()
        return AppDependencies(
            persistenceController: persistenceController,
            repository: repository,
            ocrService: ocrService,
            pdfExporter: PDFExportService(),
            titleSuggester: titleSuggester,
            ocrProcessor: ScanOCRProcessor(recognizer: ocrService, titleSuggester: titleSuggester),
            scanDeviceSupport: ScanDeviceSupport(),
            scanImporter: ScanImportService(),
            importInbox: ImportInboxService()
        )
    }
}

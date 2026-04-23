import Foundation

/// A container for the application's core service dependencies.
///
/// This struct centralizes the creation and management of services used throughout the app,
/// supporting both live production and mock/testing configurations.
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

    /// Creates a new instance of dependencies.
    ///
    /// - Note: Prefer using ``live()`` for production or a custom init for testing.
    init(
        persistenceController: PersistenceController,
        repository: ScanRepository,
        ocrService: OCRRecognizing,
        pdfExporter: PDFExporting,
        titleSuggester: TitleSuggesting,
        ocrProcessor: ScanOCRProcessing,
        scanDeviceSupport: ScanDeviceSupporting,
        scanImporter: ScanImporting,
        importInbox: ImportInboxManaging
    ) {
        self.persistenceController = persistenceController
        self.repository = repository
        self.ocrService = ocrService
        self.pdfExporter = pdfExporter
        self.titleSuggester = titleSuggester
        self.ocrProcessor = ocrProcessor
        self.scanDeviceSupport = scanDeviceSupport
        self.scanImporter = scanImporter
        self.importInbox = importInbox
    }

    /// Provides the live production configuration of dependencies.
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

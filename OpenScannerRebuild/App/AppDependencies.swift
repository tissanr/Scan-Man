import Foundation

/// The single dependency container. Views and view models get services from here; there are no singletons.
@MainActor
struct AppDependencies {
    let persistenceController: PersistenceController
    let repository: ScanRepository
    let imageProcessor: ImageProcessing
    let pdfExporter: PDFExporting
    let ocrProcessor: ScanOCRProcessing
    let scanDeviceSupport: ScanDeviceSupporting
    let scanImporter: ScanImporting
    let importInbox: ImportInboxManaging
    let settings: AppSettings
    let events: LibraryEvents
    let ocrCoordinator: OCRCoordinator
    let appLock: AppLockController

    init(
        persistenceController: PersistenceController,
        repository: ScanRepository,
        imageProcessor: ImageProcessing,
        pdfExporter: PDFExporting,
        ocrProcessor: ScanOCRProcessing,
        scanDeviceSupport: ScanDeviceSupporting,
        scanImporter: ScanImporting,
        importInbox: ImportInboxManaging,
        settings: AppSettings
    ) {
        self.persistenceController = persistenceController
        self.repository = repository
        self.imageProcessor = imageProcessor
        self.pdfExporter = pdfExporter
        self.ocrProcessor = ocrProcessor
        self.scanDeviceSupport = scanDeviceSupport
        self.scanImporter = scanImporter
        self.importInbox = importInbox
        self.settings = settings
        let events = LibraryEvents()
        self.events = events
        self.ocrCoordinator = OCRCoordinator(repository: repository, processor: ocrProcessor, events: events)
        self.appLock = AppLockController(settings: settings)
    }

    /// Production services backed by the on-disk store.
    static func live() -> AppDependencies {
        make(persistenceController: PersistenceController(), settings: AppSettings())
    }

    /// Real services over a throwaway store, for previews and integration tests.
    static func inMemory(settings: AppSettings? = nil) -> AppDependencies {
        let suite = UserDefaults(suiteName: "ScanMan.InMemory.\(UUID().uuidString)") ?? .standard
        return make(persistenceController: PersistenceController(inMemory: true), settings: settings ?? AppSettings(defaults: suite))
    }

    private static func make(persistenceController: PersistenceController, settings: AppSettings) -> AppDependencies {
        let repository = CoreDataScanRepository(persistenceController: persistenceController)
        let imageProcessor = CoreImageProcessor()
        return AppDependencies(
            persistenceController: persistenceController,
            repository: repository,
            imageProcessor: imageProcessor,
            pdfExporter: PDFExportService(imageProcessor: imageProcessor),
            ocrProcessor: ScanOCRProcessor(recognizer: VisionOCRService(), titleSuggester: TitleSuggestionService()),
            scanDeviceSupport: ScanDeviceSupport(),
            scanImporter: ScanImportService(imageProcessor: imageProcessor),
            importInbox: ImportInboxService(),
            settings: settings
        )
    }

    // MARK: - Factories

    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(
            repository: repository,
            ocrCoordinator: ocrCoordinator,
            scanDeviceSupport: scanDeviceSupport,
            scanImporter: scanImporter,
            importInbox: importInbox,
            settings: settings,
            events: events
        )
    }

    func makeScanDetailViewModel(scanID: UUID) -> ScanDetailViewModel {
        ScanDetailViewModel(
            scanID: scanID,
            repository: repository,
            pdfExporter: pdfExporter,
            imageProcessor: imageProcessor,
            scanImporter: scanImporter,
            ocrCoordinator: ocrCoordinator,
            scanDeviceSupport: scanDeviceSupport,
            settings: settings,
            events: events
        )
    }

    /// One-time work before the library is shown.
    func prepareForLaunch() async {
        ExportDirectory.cleanUp()
        AppSeeder.applyLaunchArguments(to: settings)
        do {
            try await repository.rebuildDerivedFieldsIfNeeded()
        } catch {
            // The library still loads; summaries fall back to titles until the next launch.
        }
        await AppSeeder.seedIfNeeded(using: repository)
    }
}

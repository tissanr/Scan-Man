import CoreGraphics
import Foundation
import UIKit
import Testing
@testable import OpenScannerRebuild

@MainActor
struct HomeViewModelTests {
    @Test
    func searchMatchesTitleTextAndNotes() async {
        let repository = StubScanRepository(scans: [
            TestData.scan(title: "Tax Receipt", pages: [TestData.page(order: 0, text: "Invoice total 22")]),
            TestData.scan(title: "Groceries", notes: "Paid by card", pages: [TestData.page(order: 0, text: "Bread")])
        ])
        let viewModel = TestEnvironment(repository: repository).makeHomeViewModel()
        await viewModel.load()

        viewModel.searchText = "invoice"
        #expect(viewModel.filteredScans.map(\.title) == ["Tax Receipt"])

        viewModel.searchText = "CARD"
        #expect(viewModel.filteredScans.map(\.title) == ["Groceries"])

        viewModel.searchText = ""
        #expect(viewModel.filteredScans.count == 2)
    }

    @Test
    func importingPhotosSavesOpensAndRecognizesText() async throws {
        let repository = StubScanRepository()
        let environment = TestEnvironment(repository: repository, ocrProcessor: StubOCRProcessor(text: "Found text"))
        let viewModel = environment.makeHomeViewModel()

        await viewModel.importPhotos(from: [TestData.jpegData(), TestData.jpegData()])

        let scanID = try #require(viewModel.consumePendingNavigation())
        #expect(viewModel.scans.first?.id == scanID)
        #expect(viewModel.scans.first?.pageCount == 2)
        #expect(await waitUntil { repository.ocrApplicationCount == 1 })
        #expect(try await repository.fetchScan(id: scanID)?.pages.first?.recognizedText == "Found text")
    }

    @Test
    func deletingAScanDuringOCRDoesNotBringItBack() async throws {
        let repository = StubScanRepository()
        let environment = TestEnvironment(repository: repository)
        let viewModel = environment.makeHomeViewModel()

        await viewModel.importPhotos(from: [TestData.jpegData()])
        let summary = try #require(viewModel.scans.first)
        await viewModel.delete(summary)

        _ = await waitUntil { repository.ocrApplicationCount == 1 }
        #expect(try await repository.fetchScan(id: summary.id) == nil)
        #expect(viewModel.scans.isEmpty)
    }

    @Test
    func scanningWithoutCameraAccessExplainsHowToFixIt() {
        var environment = TestEnvironment()
        environment.deviceSupport = StubDeviceSupport(canScanDocuments: true, cameraAccess: .denied)
        let viewModel = environment.makeHomeViewModel()

        viewModel.beginScan()

        #expect(!viewModel.isShowingScanner)
        #expect(viewModel.errorOffersSettingsLink)
        #expect(viewModel.activeErrorMessage == AppError.cameraAccessDenied.localizedDescription)
    }

    @Test
    func scanningOnUnsupportedDeviceShowsMessage() {
        var environment = TestEnvironment()
        environment.deviceSupport = StubDeviceSupport(canScanDocuments: false)
        let viewModel = environment.makeHomeViewModel()

        viewModel.beginScan()

        #expect(viewModel.activeErrorMessage == "Unavailable")
        #expect(viewModel.scanSupportMessage == "Unavailable")
    }
}

@MainActor
struct ScanDetailViewModelTests {
    private func makeViewModel(pages: [ScanPage], ocr: ScanOCRProcessing = StubOCRProcessor())
        async -> (ScanDetailViewModel, StubScanRepository, ScanDocument) {
        let scan = TestData.scan(title: "Detail", pages: pages)
        let repository = StubScanRepository(scans: [scan])
        let viewModel = TestEnvironment(repository: repository, ocrProcessor: ocr).makeDetailViewModel(scanID: scan.id)
        await viewModel.load()
        return (viewModel, repository, scan)
    }

    @Test
    func editingPageTextUpdatesTheScan() async {
        let page = TestData.page(order: 0, text: "Original invoice")
        let (viewModel, _, _) = await makeViewModel(pages: [page])

        let saved = await viewModel.updateRecognizedText(for: page.id, text: "Updated invoice total")

        #expect(saved)
        #expect(viewModel.page(for: page.id)?.recognizedText == "Updated invoice total")
        #expect(viewModel.scan?.searchText.contains("updated invoice total") == true)
    }

    @Test
    func titleAndNotesDraftsAreSaved() async throws {
        let (viewModel, repository, scan) = await makeViewModel(pages: [TestData.page(order: 0, text: "")])

        viewModel.titleDraft = "  New title "
        await viewModel.saveTitle()
        viewModel.notesDraft = "Keep for taxes"
        #expect(viewModel.hasUnsavedNotes)
        #expect(await viewModel.saveNotes())

        let stored = try #require(try await repository.fetchScan(id: scan.id))
        #expect(stored.title == "New title")
        #expect(stored.notes == "Keep for taxes")
        #expect(!viewModel.hasUnsavedNotes)
    }

    @Test
    func lastPageCannotBeDeleted() async {
        let page = TestData.page(order: 0, text: "Only")
        let (viewModel, _, _) = await makeViewModel(pages: [page])

        #expect(!viewModel.canDeletePages)
        await viewModel.deletePage(page.id)

        #expect(viewModel.pages.count == 1)
        #expect(viewModel.activeErrorMessage == AppError.lastPageCannotBeDeleted.localizedDescription)
    }

    @Test
    func movingAndDeletingPages() async {
        let a = TestData.page(order: 0, text: "A")
        let b = TestData.page(order: 1, text: "B")
        let c = TestData.page(order: 2, text: "C")
        let (viewModel, _, _) = await makeViewModel(pages: [a, b, c])

        await viewModel.movePages(from: IndexSet(integer: 2), to: 0)
        #expect(viewModel.pages.map(\.recognizedText) == ["C", "A", "B"])

        await viewModel.deletePages(at: IndexSet(integer: 1))
        #expect(viewModel.pages.map(\.recognizedText) == ["C", "B"])
    }

    @Test
    func rotatingAPageResetsAndReRunsOCR() async throws {
        let page = TestData.page(order: 0, text: "Sideways", observations: [TestData.observation("Sideways")])
        let (viewModel, repository, _) = await makeViewModel(pages: [page], ocr: StubOCRProcessor(text: "Upright"))

        await viewModel.rotatePage(page.id, clockwise: true)

        let rotatedImage = try #require(viewModel.page(for: page.id)?.imageData)
        #expect(TestData.pixelSize(of: rotatedImage) == CGSize(width: 900, height: 600))
        #expect(await waitUntil { repository.ocrApplicationCount == 1 })
        await viewModel.load()
        #expect(viewModel.page(for: page.id)?.recognizedText == "Upright")
    }

    @Test
    func changingTheFilterKeepsTextAndOriginal() async throws {
        let page = TestData.page(order: 0, text: "Keep me")
        let (viewModel, repository, _) = await makeViewModel(pages: [page])

        await viewModel.setEnhancement(.blackAndWhite, for: page.id)

        let updated = try #require(viewModel.page(for: page.id))
        #expect(updated.enhancement == .blackAndWhite)
        #expect(updated.processedImageData != nil)
        #expect(updated.imageData == page.imageData)
        #expect(updated.recognizedText == "Keep me")
        #expect(repository.ocrApplicationCount == 0)
    }

    @Test
    func addingPagesAppendsThemAndRunsOCR() async {
        let (viewModel, repository, _) = await makeViewModel(pages: [TestData.page(order: 0, text: "First")], ocr: StubOCRProcessor(text: "New"))

        await viewModel.appendPages(fromImageData: [TestData.jpegData(), TestData.jpegData()])

        #expect(viewModel.pages.count == 3)
        #expect(viewModel.pages.map(\.order) == [0, 1, 2])
        #expect(await waitUntil { repository.ocrApplicationCount == 1 })
    }

    @Test
    func exportUsesCurrentSettings() async throws {
        let (viewModel, _, _) = await makeViewModel(pages: [TestData.page(order: 0, text: "")])
        await viewModel.exportPDF(mode: .imageOnly)
        let file = try #require(viewModel.exportedFile)
        #expect(file.url.pathExtension == "pdf")
        viewModel.dismissShareSheet()
        #expect(viewModel.exportedFile == nil)
    }

    @Test
    func deletedScanShowsAsMissing() async throws {
        let (viewModel, repository, scan) = await makeViewModel(pages: [TestData.page(order: 0, text: "")])
        try await repository.delete(scanID: scan.id)
        await viewModel.load()
        #expect(viewModel.scan == nil)
        #expect(viewModel.isLoaded)
    }
}

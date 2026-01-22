import Testing
import Foundation
@testable import DocboxKit

@Suite("ScannerError Tests")
struct ScannerErrorTests {

    @Test("noScannersFound has descriptive message")
    func noScannersFoundMessage() {
        let error = ScannerError.noScannersFound
        #expect(error.errorDescription?.contains("No scanners found") == true)
    }

    @Test("scannerNotFound includes scanner name in message")
    func scannerNotFoundMessage() {
        let error = ScannerError.scannerNotFound(name: "MyScanner")
        #expect(error.errorDescription?.contains("MyScanner") == true)
    }

    @Test("scannerBusy has descriptive message")
    func scannerBusyMessage() {
        let error = ScannerError.scannerBusy
        #expect(error.errorDescription?.contains("busy") == true)
    }

    @Test("sessionFailed includes underlying error")
    func sessionFailedWithUnderlyingError() {
        let underlying = NSError(domain: "Test", code: 42, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        let error = ScannerError.sessionFailed(underlying)
        #expect(error.errorDescription?.contains("Test error") == true)
    }

    @Test("sessionFailed without underlying error still has message")
    func sessionFailedWithoutUnderlyingError() {
        let error = ScannerError.sessionFailed(nil)
        #expect(error.errorDescription?.contains("session") == true)
    }

    @Test("unsupportedResolution includes requested and available values")
    func unsupportedResolutionMessage() {
        let error = ScannerError.unsupportedResolution(requested: 400, available: IndexSet([150, 300, 600]))
        let desc = error.errorDescription ?? ""
        #expect(desc.contains("400"))
    }

    @Test("unsupportedColorMode has descriptive message")
    func unsupportedColorModeMessage() {
        let error = ScannerError.unsupportedColorMode
        #expect(error.errorDescription?.contains("color mode") == true)
    }

    @Test("unsupportedPageSize has descriptive message")
    func unsupportedPageSizeMessage() {
        let error = ScannerError.unsupportedPageSize
        #expect(error.errorDescription?.contains("page size") == true)
    }

    @Test("noPagesInFeeder has descriptive message")
    func noPagesInFeederMessage() {
        let error = ScannerError.noPagesInFeeder
        #expect(error.errorDescription?.contains("feeder") == true)
    }

    @Test("scanFailed includes underlying error")
    func scanFailedWithUnderlyingError() {
        let underlying = NSError(domain: "Scan", code: 1, userInfo: [NSLocalizedDescriptionKey: "Hardware error"])
        let error = ScannerError.scanFailed(underlying)
        #expect(error.errorDescription?.contains("Hardware error") == true)
    }

    @Test("scanFailed without underlying error still has message")
    func scanFailedWithoutUnderlyingError() {
        let error = ScannerError.scanFailed(nil)
        #expect(error.errorDescription?.contains("failed") == true)
    }

    @Test("imageAssemblyFailed has descriptive message")
    func imageAssemblyFailedMessage() {
        let error = ScannerError.imageAssemblyFailed
        #expect(error.errorDescription?.contains("assemble") == true)
    }

    @Test("timeout has descriptive message")
    func timeoutMessage() {
        let error = ScannerError.timeout
        #expect(error.errorDescription?.contains("timed out") == true)
    }

    @Test("All errors conform to LocalizedError")
    func errorsConformToLocalizedError() {
        let errors: [ScannerError] = [
            .noScannersFound,
            .scannerNotFound(name: "test"),
            .scannerBusy,
            .sessionFailed(nil),
            .unsupportedResolution(requested: 100, available: IndexSet()),
            .unsupportedColorMode,
            .unsupportedPageSize,
            .noPagesInFeeder,
            .scanFailed(nil),
            .imageAssemblyFailed,
            .timeout
        ]

        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.isEmpty == false)
        }
    }
}

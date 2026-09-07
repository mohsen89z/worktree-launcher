import Testing
@testable import WorktreeLauncherCore

@Suite("URL detection")
struct UrlDetectionTests {
    @Test("detects localhost URLs from dev server output")
    func detectsLocalhostUrlsFromDevServerOutput() {
        let output = "ready - started server on 0.0.0.0:3000, url: http://localhost:3000"
        #expect(UrlDetection.detectURLs(in: output) == ["http://localhost:3000"])
    }

    @Test("detects bare localhost port")
    func detectsBareLocalhostPort() {
        let output = "Local: http://127.0.0.1:5173/"
        #expect(UrlDetection.detectURLs(in: output) == ["http://127.0.0.1:5173/"])
    }
}

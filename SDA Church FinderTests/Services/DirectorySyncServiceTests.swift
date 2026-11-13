//
//  DirectorySyncServiceTests.swift
//  AdventFindTests
//
//  Created by Kyle Slingo on 2/13/26.
//

import XCTest
@testable import AdventFind

final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

@MainActor
final class DirectorySyncServiceTests: XCTestCase {
    private var tempDir: URL!
    private var mockSession: URLSession!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        mockSession = URLSession(configuration: config)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testSeedCacheFromBundle() throws {
        let service = DirectorySyncService(cacheDirectory: tempDir, urlSession: mockSession)

        service.seedCacheFromBundleIfNeeded(bundle: .main)

        let manifest = service.localManifest()
        XCTAssertNotNil(manifest)
        XCTAssertEqual(manifest?.schemaVersion, 1)
        XCTAssertEqual(manifest?.datasets.count, 2)
        XCTAssertTrue(FileManager.default.fileExists(atPath: service.manifestFileURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: service.churchesDirectory.appendingPathComponent("connecticut-churches.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: service.churchesDirectory.appendingPathComponent("snec-churches.json").path))
    }

    func testOfflineFailsGracefullyAndPreservesLocalRecords() async {
        let service = DirectorySyncService(cacheDirectory: tempDir, urlSession: mockSession)
        service.seedCacheFromBundleIfNeeded(bundle: .main)

        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let status = await service.sync()
        XCTAssertEqual(status, .failed("Remote directory unavailable"))
        XCTAssertEqual(service.status, .failed("Remote directory unavailable"))

        // Local cache must still exist
        XCTAssertNotNil(service.localManifest())
        XCTAssertGreaterThan(ChurchDirectory.shared.records.count, 0)
    }

    func testSyncDownloadsUpdatedDatasetAndTriggersReload() async throws {
        let service = DirectorySyncService(cacheDirectory: tempDir, urlSession: mockSession)
        service.seedCacheFromBundleIfNeeded(bundle: .main)

        let remoteManifestJSON = """
        {
            "schemaVersion": 1,
            "version": 2,
            "lastUpdated": "2026-11-13T23:00:00Z",
            "datasets": [
                {
                    "id": "mock-conference",
                    "filename": "mock-conference-churches.json",
                    "name": "Mock Conference",
                    "conference": "Mock Conference",
                    "version": 1,
                    "recordCount": 1
                }
            ]
        }
        """.data(using: .utf8)!

        let remoteDatasetJSON = """
        {
            "schemaVersion": 1,
            "records": [
                {
                    "id": "mock-1",
                    "name": "Faith Hope SDA Church",
                    "street": "100 Faith Way",
                    "city": "Hartford",
                    "state": "CT",
                    "postalCode": "06120",
                    "website": "https://faithhope.org",
                    "sourceURLs": ["https://faithhope.org"],
                    "checkedOn": "2026-11-13",
                    "denomination": "Seventh-day Adventist",
                    "aliases": [],
                    "reviewNotes": "Verified mock",
                    "allowsAddressOnlyMatch": false,
                    "conference": "Mock Conference",
                    "givingURL": "https://adventistgiving.org/donate/AN4FFF",
                    "latitude": 41.77,
                    "longitude": -72.67
                }
            ]
        }
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            let urlString = request.url?.absoluteString ?? ""
            if urlString.contains("manifest.json") {
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                return (response, remoteManifestJSON)
            } else if urlString.contains("mock-conference-churches.json") {
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                return (response, remoteDatasetJSON)
            }
            let notFound = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (notFound, Data())
        }

        let status = await service.sync()
        XCTAssertEqual(status, .updated(newDatasetsCount: 1))
        XCTAssertEqual(service.localManifest()?.version, 2)

        let mockFile = service.churchesDirectory.appendingPathComponent("mock-conference-churches.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: mockFile.path))

        // Reload ChurchDirectory from this temp directory and verify the mock church is loaded!
        ChurchDirectory.reload(cacheDirectory: service.churchesDirectory)
        XCTAssertTrue(ChurchDirectory.shared.records.contains { $0.id == "mock-1" })

        // Restore ChurchDirectory to default bundled
        ChurchDirectory.reload(cacheDirectory: nil)
    }
}

//
//  DirectorySyncService.swift
//  AdventFind
//
//  Created by Kyle Slingo on 2/13/26.
//

import Foundation
import OSLog
import Combine

public struct DirectoryManifest: Codable, Equatable {
    public let schemaVersion: Int
    public let version: Int
    public let lastUpdated: String
    public let datasets: [DirectoryDataset]

    public init(schemaVersion: Int, version: Int, lastUpdated: String, datasets: [DirectoryDataset]) {
        self.schemaVersion = schemaVersion
        self.version = version
        self.lastUpdated = lastUpdated
        self.datasets = datasets
    }
}

public struct DirectoryDataset: Codable, Identifiable, Equatable {
    public let id: String
    public let filename: String
    public let name: String
    public var state: String?
    public var conference: String?
    public let version: Int
    public var recordCount: Int?

    public init(id: String, filename: String, name: String, state: String? = nil, conference: String? = nil, version: Int, recordCount: Int? = nil) {
        self.id = id
        self.filename = filename
        self.name = name
        self.state = state
        self.conference = conference
        self.version = version
        self.recordCount = recordCount
    }
}

public enum SyncStatus: Equatable {
    case idle
    case syncing
    case upToDate
    case updated(newDatasetsCount: Int)
    case failed(String)
}

@MainActor
public final class DirectorySyncService: ObservableObject {
    public static let shared = DirectorySyncService()

    @Published public private(set) var status: SyncStatus = .idle
    @Published public private(set) var lastSyncDate: Date? = nil

    public var primaryBaseURL: URL
    public var fallbackBaseURL: URL
    public let cacheDirectory: URL
    public var urlSession: URLSession
    private let logger = Logger(subsystem: "finder.AdventFind", category: "DirectorySync")

    public var churchesDirectory: URL {
        cacheDirectory.appendingPathComponent("churches", isDirectory: true)
    }

    public var manifestFileURL: URL {
        cacheDirectory.appendingPathComponent("manifest.json")
    }

    public init(
        primaryBaseURL: URL = URL(string: "https://raw.githubusercontent.com/kyleslingo-hue/AdventFind/main/directory/")!,
        fallbackBaseURL: URL = URL(string: "https://cdn.jsdelivr.net/gh/kyleslingo-hue/AdventFind@main/directory/")!,
        cacheDirectory: URL? = nil,
        urlSession: URLSession = .shared
    ) {
        self.primaryBaseURL = primaryBaseURL
        self.fallbackBaseURL = fallbackBaseURL
        if let cacheDirectory = cacheDirectory {
            self.cacheDirectory = cacheDirectory
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.cacheDirectory = appSupport.appendingPathComponent("AdventFind/DirectoryCache", isDirectory: true)
        }
        self.urlSession = urlSession
        ensureDirectoriesExist()
    }

    public func ensureDirectoriesExist() {
        try? FileManager.default.createDirectory(at: churchesDirectory, withIntermediateDirectories: true)
    }

    public func localManifest() -> DirectoryManifest? {
        guard FileManager.default.fileExists(atPath: manifestFileURL.path),
              let data = try? Data(contentsOf: manifestFileURL) else { return nil }
        return try? JSONDecoder().decode(DirectoryManifest.self, from: data)
    }

    /// Seeds local cache from the app bundle if local cache does not yet contain a manifest.
    public func seedCacheFromBundleIfNeeded(bundle: Bundle = .main) {
        ensureDirectoriesExist()
        guard !FileManager.default.fileExists(atPath: manifestFileURL.path) else { return }

        let files = ["connecticut-churches.json", "snec-churches.json"]
        let candidateBundles = [bundle, Bundle.main]

        for file in files {
            let baseName = (file as NSString).deletingPathExtension
            var foundURL: URL?
            for b in candidateBundles {
                if let url = b.url(forResource: baseName, withExtension: "json") ??
                             b.url(forResource: baseName, withExtension: "json", subdirectory: "Resources") {
                    foundURL = url
                    break
                }
            }

            if let bundleURL = foundURL {
                let destination = churchesDirectory.appendingPathComponent(file)
                try? FileManager.default.removeItem(at: destination)
                try? FileManager.default.copyItem(at: bundleURL, to: destination)
            }
        }

        let defaultManifest = DirectoryManifest(
            schemaVersion: 1,
            version: 1,
            lastUpdated: ISO8601DateFormatter().string(from: Date()),
            datasets: [
                DirectoryDataset(id: "connecticut-churches", filename: "connecticut-churches.json", name: "Connecticut Churches", state: "CT", version: 1, recordCount: 49),
                DirectoryDataset(id: "snec-churches", filename: "snec-churches.json", name: "Southern New England Conference", conference: "Southern New England Conference", version: 1, recordCount: 182)
            ]
        )

        if let encoded = try? JSONEncoder().encode(defaultManifest) {
            try? encoded.write(to: manifestFileURL, options: .atomic)
        }
    }

    @discardableResult
    public func sync(force: Bool = false) async -> SyncStatus {
        status = .syncing
        ensureDirectoriesExist()

        // 1. Fetch remote manifest
        guard let remoteManifest = await fetchRemoteManifest() else {
            status = .failed("Remote directory unavailable")
            return status
        }

        let local = localManifest()
        let localVersion = local?.version ?? 0

        // If not forced and versions match, we are up to date
        if !force && remoteManifest.version <= localVersion && local != nil {
            status = .upToDate
            lastSyncDate = Date()
            return status
        }

        // 2. Determine which datasets need download
        var updatedCount = 0
        let localDatasetVersions = Dictionary(uniqueKeysWithValues: (local?.datasets ?? []).map { ($0.id, $0.version) })

        for dataset in remoteManifest.datasets {
            let localVer = localDatasetVersions[dataset.id] ?? -1
            let destURL = churchesDirectory.appendingPathComponent(dataset.filename)
            let fileExists = FileManager.default.fileExists(atPath: destURL.path)

            if force || !fileExists || dataset.version > localVer {
                if await downloadAndValidateDataset(dataset) {
                    updatedCount += 1
                }
            }
        }

        // 3. Save remote manifest locally
        if let manifestData = try? JSONEncoder().encode(remoteManifest) {
            try? manifestData.write(to: manifestFileURL, options: .atomic)
        }

        lastSyncDate = Date()
        status = updatedCount > 0 ? .updated(newDatasetsCount: updatedCount) : .upToDate

        // 4. Reload ChurchDirectory in memory so app gets new churches immediately
        ChurchDirectory.reload(cacheDirectory: churchesDirectory)

        logger.info("Directory sync finished. Status: \(String(describing: self.status), privacy: .public)")
        return status
    }

    private func fetchRemoteManifest() async -> DirectoryManifest? {
        let candidates = [
            primaryBaseURL.appendingPathComponent("manifest.json"),
            fallbackBaseURL.appendingPathComponent("manifest.json")
        ]

        for url in candidates {
            do {
                var request = URLRequest(url: url)
                request.cachePolicy = .reloadIgnoringLocalCacheData
                request.timeoutInterval = 10
                let (data, response) = try await urlSession.data(for: request)
                if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    return try JSONDecoder().decode(DirectoryManifest.self, from: data)
                }
            } catch {
                logger.debug("Manifest fetch failed for \(url.absoluteString, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
        return nil
    }

    private func downloadAndValidateDataset(_ dataset: DirectoryDataset) async -> Bool {
        let candidates = [
            primaryBaseURL.appendingPathComponent("churches/\(dataset.filename)"),
            fallbackBaseURL.appendingPathComponent("churches/\(dataset.filename)")
        ]

        for url in candidates {
            do {
                var request = URLRequest(url: url)
                request.cachePolicy = .reloadIgnoringLocalCacheData
                request.timeoutInterval = 15
                let (data, response) = try await urlSession.data(for: request)
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                    continue
                }
                // Validate schema before saving to disk
                let doc = try JSONDecoder().decode(ChurchDirectoryDocument.self, from: data)
                guard doc.schemaVersion == 1 else { continue }

                let destination = churchesDirectory.appendingPathComponent(dataset.filename)
                try data.write(to: destination, options: .atomic)
                return true
            } catch {
                logger.debug("Failed downloading dataset \(dataset.id, privacy: .public) from \(url.absoluteString, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
        return false
    }
}

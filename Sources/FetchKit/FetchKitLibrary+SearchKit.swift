#if os(macOS)
import FetchCore
import Foundation

extension FetchKitLibrary {
    public struct PersistentConfiguration: Hashable, Sendable {
        public enum StorageLocation: Hashable, Sendable {
            case directory(URL)
            case applicationSupportDirectory(appendingPath: String)

            public static let `default` = StorageLocation.applicationSupportDirectory(
                appendingPath: "SwiftlyFetch/FetchKit"
            )
        }

        public var location: StorageLocation
        public var storeFileName: String
        public var indexFileName: String
        public var indexNamePrefix: String
        public var retryPendingSyncsOnInit: Bool

        public init(
            location: StorageLocation = .default,
            storeFileName: String = "FetchKit.sqlite",
            indexFileName: String = "FetchKit.searchindex",
            indexNamePrefix: String = "SwiftlyFetch",
            retryPendingSyncsOnInit: Bool = true
        ) {
            self.location = location
            self.storeFileName = storeFileName
            self.indexFileName = indexFileName
            self.indexNamePrefix = indexNamePrefix
            self.retryPendingSyncsOnInit = retryPendingSyncsOnInit
        }

        public static let `default` = PersistentConfiguration()
    }

    enum PersistentLibraryError: Error, LocalizedError {
        case applicationSupportDirectoryUnavailable

        var errorDescription: String? {
            switch self {
            case .applicationSupportDirectoryUnavailable:
                "FetchKit could not resolve the user Application Support directory for persistent library storage."
            }
        }
    }

    struct ResolvedPersistentPaths: Hashable, Sendable {
        let directoryURL: URL
        let storeURL: URL
        let indexURL: URL
    }

    public static func macOSPersistentLibrary(
        configuration: PersistentConfiguration = .default
    ) async throws -> FetchKitLibrary {
        let resolvedPaths = try configuration.resolvedPaths()

        try FileManager.default.createDirectory(
            at: resolvedPaths.directoryURL,
            withIntermediateDirectories: true
        )

        let store = try await CoreDataFetchDocumentStore(
            configuration: .init(store: .sqlite(resolvedPaths.storeURL))
        )
        let index = try SearchKitFetchIndex(
            configuration: .init(
                storage: .file(resolvedPaths.indexURL),
                indexNamePrefix: configuration.indexNamePrefix
            )
        )
        let library = FetchKitLibrary(documentStore: store, index: index)

        if configuration.retryPendingSyncsOnInit {
            _ = try await library.retryPendingIndexSyncs()
        }

        return library
    }

    public static func macOSPersistentLibrary(
        at directoryURL: URL,
        indexNamePrefix: String = "SwiftlyFetch",
        retryPendingSyncsOnInit: Bool = true
    ) async throws -> FetchKitLibrary {
        try await macOSPersistentLibrary(
            configuration: .init(
                location: .directory(directoryURL),
                indexNamePrefix: indexNamePrefix,
                retryPendingSyncsOnInit: retryPendingSyncsOnInit
            )
        )
    }
}

extension FetchKitLibrary.PersistentConfiguration {
    func resolvedPaths(fileManager: FileManager = .default) throws -> FetchKitLibrary.ResolvedPersistentPaths {
        let directoryURL = try resolveDirectoryURL(fileManager: fileManager)
        return .init(
            directoryURL: directoryURL,
            storeURL: directoryURL.appendingPathComponent(storeFileName),
            indexURL: directoryURL.appendingPathComponent(indexFileName)
        )
    }

    private func resolveDirectoryURL(fileManager: FileManager) throws -> URL {
        switch location {
        case let .directory(url):
            return url
        case let .applicationSupportDirectory(appendingPath):
            guard let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                throw FetchKitLibrary.PersistentLibraryError.applicationSupportDirectoryUnavailable
            }

            return baseURL.appendingPathComponent(appendingPath, isDirectory: true)
        }
    }
}
#endif

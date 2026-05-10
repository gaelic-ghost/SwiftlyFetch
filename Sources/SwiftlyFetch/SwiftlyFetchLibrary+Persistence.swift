#if os(macOS)
import FetchKit
import Foundation
import RAGKit

public struct SwiftlyFetchPersistentConfiguration: Hashable, Sendable {
    public enum StorageLocation: Hashable, Sendable {
        case directory(URL)
        case applicationSupportDirectory(appendingPath: String)

        public static let `default` = StorageLocation.applicationSupportDirectory(
            appendingPath: "SwiftlyFetch"
        )
    }

    public enum SemanticBackend: Hashable, Sendable {
        case hashing(dimension: Int)
        case naturalLanguage(languageHint: String?)

        public static let `default` = SemanticBackend.hashing(dimension: 64)
    }

    public var location: StorageLocation
    public var semanticBackend: SemanticBackend
    public var retryPendingSyncsOnInit: Bool

    public init(
        location: StorageLocation = .default,
        semanticBackend: SemanticBackend = .default,
        retryPendingSyncsOnInit: Bool = true
    ) {
        self.location = location
        self.semanticBackend = semanticBackend
        self.retryPendingSyncsOnInit = retryPendingSyncsOnInit
    }

    public static let `default` = SwiftlyFetchPersistentConfiguration()
}

public extension SwiftlyFetchLibrary {
    enum PersistentLibraryError: Error, LocalizedError {
        case applicationSupportDirectoryUnavailable

        public var errorDescription: String? {
            switch self {
                case .applicationSupportDirectoryUnavailable:
                    "SwiftlyFetch could not resolve the user Application Support directory for persistent library storage."
            }
        }
    }

    internal struct ResolvedPersistentPaths: Hashable {
        let rootURL: URL
        let fetchKitDirectoryURL: URL
        let semanticIndexURL: URL
        let semanticRetryURL: URL
    }

    static func macOSPersistentLibrary(
        configuration: SwiftlyFetchPersistentConfiguration = .default
    ) async throws -> SwiftlyFetchLibrary {
        let resolvedPaths = try configuration.resolvedPaths()

        try FileManager.default.createDirectory(
            at: resolvedPaths.rootURL,
            withIntermediateDirectories: true
        )

        let fetchLibrary = try await FetchKitLibrary.macOSPersistentLibrary(
            configuration: .init(
                location: .directory(resolvedPaths.fetchKitDirectoryURL),
                retryPendingSyncsOnInit: configuration.retryPendingSyncsOnInit
            )
        )
        let knowledgeBase = try await makePersistentKnowledgeBase(
            configuration: configuration,
            semanticIndexURL: resolvedPaths.semanticIndexURL
        )
        let retryStore = try await CoreDataSwiftlyFetchSemanticRetryStore(
            configuration: .init(store: .sqlite(resolvedPaths.semanticRetryURL))
        )

        let library = SwiftlyFetchLibrary(
            fetchLibrary: fetchLibrary,
            knowledgeBase: knowledgeBase,
            retryStore: retryStore
        )

        if configuration.retryPendingSyncsOnInit {
            _ = try await library.retrySemanticIndexing()
        }

        return library
    }

    static func macOSPersistentLibrary(
        at directoryURL: URL,
        semanticBackend: SwiftlyFetchPersistentConfiguration.SemanticBackend = .default,
        retryPendingSyncsOnInit: Bool = true
    ) async throws -> SwiftlyFetchLibrary {
        try await macOSPersistentLibrary(
            configuration: .init(
                location: .directory(directoryURL),
                semanticBackend: semanticBackend,
                retryPendingSyncsOnInit: retryPendingSyncsOnInit
            )
        )
    }

    private static func makePersistentKnowledgeBase(
        configuration: SwiftlyFetchPersistentConfiguration,
        semanticIndexURL: URL
    ) async throws -> KnowledgeBase {
        let vectorConfiguration = CoreDataVectorIndex.Configuration(store: .sqlite(semanticIndexURL))

        switch configuration.semanticBackend {
            case let .hashing(dimension):
                return try await KnowledgeBase.persistentHashingDefault(
                    configuration: vectorConfiguration,
                    dimension: dimension
                )
            case let .naturalLanguage(languageHint):
                return try await KnowledgeBase.persistentNaturalLanguageDefault(
                    configuration: vectorConfiguration,
                    languageHint: languageHint
                )
        }
    }
}

extension SwiftlyFetchPersistentConfiguration {
    func resolvedPaths(fileManager: FileManager = .default) throws -> SwiftlyFetchLibrary.ResolvedPersistentPaths {
        let rootURL = try resolveRootURL(fileManager: fileManager)
        return .init(
            rootURL: rootURL,
            fetchKitDirectoryURL: rootURL.appendingPathComponent("FetchKit", isDirectory: true),
            semanticIndexURL: rootURL.appendingPathComponent("SemanticIndex.sqlite"),
            semanticRetryURL: rootURL.appendingPathComponent("SemanticRetries.sqlite")
        )
    }

    private func resolveRootURL(fileManager: FileManager) throws -> URL {
        switch location {
            case let .directory(url):
                return url
            case let .applicationSupportDirectory(appendingPath):
                guard let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                    throw SwiftlyFetchLibrary.PersistentLibraryError.applicationSupportDirectoryUnavailable
                }

                return baseURL.appendingPathComponent(appendingPath, isDirectory: true)
        }
    }
}
#endif

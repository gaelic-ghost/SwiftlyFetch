#if os(macOS)
import FetchCore
import Foundation

extension FetchKitLibrary {
    public struct PersistentConfiguration: Hashable, Sendable {
        public var store: CoreDataFetchDocumentStore.Configuration
        public var index: SearchKitFetchIndex.Configuration
        public var retryPendingSyncsOnInit: Bool

        public init(
            store: CoreDataFetchDocumentStore.Configuration,
            index: SearchKitFetchIndex.Configuration,
            retryPendingSyncsOnInit: Bool = true
        ) {
            self.store = store
            self.index = index
            self.retryPendingSyncsOnInit = retryPendingSyncsOnInit
        }
    }

    public static func macOSPersistentLibrary(
        configuration: PersistentConfiguration
    ) async throws -> FetchKitLibrary {
        let store = try await CoreDataFetchDocumentStore(configuration: configuration.store)
        let index = try SearchKitFetchIndex(configuration: configuration.index)
        let library = FetchKitLibrary(documentStore: store, index: index)

        if configuration.retryPendingSyncsOnInit {
            _ = try await library.retryPendingIndexSyncs()
        }

        return library
    }
}
#endif

import Testing
@testable import SwiftlyFetch

@Test("The bootstrap library exposes a constructible client type")
func bootstrapSurfaceIsAvailable() {
    _ = SwiftlyFetchClient()
}

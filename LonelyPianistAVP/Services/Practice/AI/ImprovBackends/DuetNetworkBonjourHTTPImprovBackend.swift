import Foundation
import ImprovProtocol

actor DuetNetworkBonjourHTTPImprovBackend: ImprovBackendProtocol {
    nonisolated let kind: ImprovBackendKind = .networkBonjourHTTPDuet
    nonisolated let displayName: String = "网络本地连接（A.I. Duet / Magenta）"

    private let inner: NetworkBonjourHTTPImprovBackend

    init(discoveryService: any BonjourBackendDiscoveryServiceProtocol) {
        inner = NetworkBonjourHTTPImprovBackend(discoveryService: discoveryService)
    }

    func generatePlaybackPlan(
        request: ImprovGenerateRequest,
        timeout: Duration
    ) async throws -> ImprovBackendPlaybackPlan {
        try await inner.generatePlaybackPlan(request: request, timeout: timeout)
    }
}

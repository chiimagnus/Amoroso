import Foundation

enum ImprovBackendKind: String, CaseIterable, Codable, Hashable, Identifiable {
    case networkBonjourHTTP = "network_bonjour_http"
    case networkBonjourHTTPDuet = "network_bonjour_http_duet"
    case localRule = "local_rule"
    case tickRangeReplay = "tick_range_replay"

    var id: String {
        rawValue
    }
}

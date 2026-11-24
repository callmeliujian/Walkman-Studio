import Foundation

struct OnlineMetadataSelection: Identifiable {
    let id = UUID()
    let query: String
    var candidates: [OnlineTrackMetadata]
}

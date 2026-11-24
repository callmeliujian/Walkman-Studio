import SwiftUI

struct DriveLibraryCache: Sendable {
    var tracks: [Track] = []
    var cachedArtists: [ArtistItem] = []
    var cachedAlbums: [AlbumItem] = []
    var cachedRecentTracks: [Track] = []
    var cachedLanguageTracks: [Track] = []
    var libraryStats: (albums: Int, artists: Int, hiRes: Int, recentlyAdded: Int, languageStudy: Int) = (0, 0, 0, 0, 0)
    var isLoaded: Bool = false
}

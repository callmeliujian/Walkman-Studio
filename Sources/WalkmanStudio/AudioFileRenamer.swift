import Foundation

/// Renames the audio and its companion lyrics together without replacing existing files.
enum AudioFileRenamer {
    static func rename(fileURL: URL, title: String, artist: String, relativePath: String? = nil) throws -> URL {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let artist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !artist.isEmpty else { return fileURL }

        var stem = WalkmanEngine.shared.sanitizeFilename("\(title) \(artist)", maxLength: 240)
        // Leave room for the extension and collision suffix on UTF-8 filesystems.
        while stem.utf8.count > 230 { stem.removeLast() }
        stem = stem.trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        let fm = FileManager.default
        let directory = fileURL.deletingLastPathComponent()
        var companions: [URL] = []
        for ext in ["lrc", "LRC"] {
            let url = fileURL.deletingPathExtension().appendingPathExtension(ext)
            if fm.fileExists(atPath: url.path), !companions.contains(where: { sameFile($0, url) }) {
                let actualName = try url.resourceValues(forKeys: [.nameKey]).name ?? url.lastPathComponent
                companions.append(directory.appendingPathComponent(actualName))
            }
        }

        var suffix = 1
        var destination: URL
        while true {
            let name = suffix == 1 ? stem : "\(stem) (\(suffix))"
            destination = directory.appendingPathComponent(name).appendingPathExtension(fileURL.pathExtension)
            let audioOccupied = fm.fileExists(atPath: destination.path) && !sameFile(fileURL, destination)
            let lyricsOccupied = ["lrc", "LRC"].contains { ext in
                let target = destination.deletingPathExtension().appendingPathExtension(ext)
                return fm.fileExists(atPath: target.path) && !companions.contains { sameFile($0, target) }
            }
            if !audioOccupied && !lyricsOccupied { break }
            suffix += 1
        }
        guard destination.path != fileURL.path else { return fileURL }

        let playlists = try playlistEdits(fileURL: fileURL, destination: destination, relativePath: relativePath)
        var moves = [(fileURL, destination)]
        moves += companions.map { ($0, destination.deletingPathExtension().appendingPathExtension($0.pathExtension)) }
        var completed: [(URL, URL)] = []
        var writtenPlaylists: [(url: URL, original: Data, updated: Data)] = []
        do {
            for (source, target) in moves {
                // A temporary hop also supports case-only changes on APFS/FAT/exFAT.
                let temporary = directory.appendingPathComponent(".rename-\(UUID().uuidString)")
                try fm.moveItem(at: source, to: temporary)
                completed.append((source, temporary))
                try fm.moveItem(at: temporary, to: target)
                completed[completed.count - 1] = (source, target)
            }
            for edit in playlists {
                try edit.updated.write(to: edit.url, options: .atomic)
                writtenPlaylists.append(edit)
            }
        } catch {
            for edit in writtenPlaylists.reversed() {
                try edit.original.write(to: edit.url, options: .atomic)
            }
            for (source, target) in completed.reversed() {
                try fm.moveItem(at: target, to: source)
            }
            throw error
        }
        return destination
    }

    /// Preserve playlist formatting and only replace path lines resolving to this file.
    private static func playlistEdits(fileURL: URL, destination: URL, relativePath: String?) throws
        -> [(url: URL, original: Data, updated: Data)] {
        guard let relativePath, !relativePath.isEmpty,
              fileURL.path.hasSuffix("/" + relativePath) else { return [] }
        let root = URL(fileURLWithPath: String(fileURL.path.dropLast(relativePath.count)))
        var roots = [root]
        if ["music", "learning"].contains(root.lastPathComponent.lowercased()) {
            let mount = root.deletingLastPathComponent()
            roots += ["MUSIC", "LEARNING", "PLAYLISTS", "Playlists", "playlists"].map { mount.appendingPathComponent($0) }
        }
        var visited = Set<String>()
        var edits: [(url: URL, original: Data, updated: Data)] = []
        for searchRoot in roots {
            guard let files = FileManager.default.enumerator(at: searchRoot, includingPropertiesForKeys: nil,
                                                            options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { continue }
            for case let playlist as URL in files where ["m3u", "m3u8"].contains(playlist.pathExtension.lowercased()) {
                guard visited.insert(playlist.path).inserted else { continue }
                let original = try Data(contentsOf: playlist)
                guard let encoding = [String.Encoding.utf8, .utf16, .isoLatin1, .windowsCP1252].first(where: {
                    String(data: original, encoding: $0) != nil
                }), let content = String(data: original, encoding: encoding) else { continue }
                let updated = content.components(separatedBy: "\n").map { line -> String in
                    let path = line.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\u{FEFF}")))
                    guard !path.isEmpty, !path.hasPrefix("#") else { return line }
                    let posix = path.replacingOccurrences(of: "\\", with: "/")
                    let candidates = [URL(fileURLWithPath: posix, relativeTo: playlist.deletingLastPathComponent()),
                                      root.appendingPathComponent(posix),
                                      root.deletingLastPathComponent().appendingPathComponent(posix)]
                    guard candidates.contains(where: { $0.standardizedFileURL.path == fileURL.standardizedFileURL.path }) else { return line }
                    let prefix = path.lastIndex(where: { $0 == "/" || $0 == "\\" }).map { String(path[...$0]) } ?? ""
                    return line.replacingOccurrences(of: path, with: prefix + destination.lastPathComponent)
                }.joined(separator: "\n")
                if updated != content {
                    guard let data = updated.data(using: encoding) else {
                        throw CocoaError(.fileWriteInapplicableStringEncoding)
                    }
                    edits.append((playlist, original, data))
                }
            }
        }
        return edits
    }

    private static func sameFile(_ first: URL, _ second: URL) -> Bool {
        guard let a = try? first.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier,
              let b = try? second.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier else {
            return false
        }
        return (a as? NSObject)?.isEqual(b) == true
    }
}

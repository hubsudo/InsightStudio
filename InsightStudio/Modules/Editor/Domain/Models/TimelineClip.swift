import Foundation

struct TimelineClip: Hashable, Identifiable, Sendable {
    let id: UUID
    var title: String
    
    var localFileURL: URL?
    var remoteStreamURL: String
    
    var duration: Double

    init(id: UUID = UUID(),
         title: String,
         localFileURL: URL?,
         remoteStreamURL: String,
         duration: Double
    ) {
        self.id = id
        self.title = title
        self.localFileURL = localFileURL
        self.remoteStreamURL = remoteStreamURL
        self.duration = duration
    }
}

extension TimelineClip {
    init(importedClip: ImportedClip) {
        let selectedDuration = max(
            importedClip.selectedEndSeconds - importedClip.selectedStartSeconds,
            0.1
        )
        
        self.init(
            id: importedClip.id,
            title: importedClip.title,
            localFileURL: importedClip.localFileURL,
            remoteStreamURL: importedClip.remoteStreamURL,
            duration: selectedDuration
        )
    }
    var playbackURL: URL? {
        if let localFileURL,
           FileManager.default.fileExists(atPath: localFileURL.path) {
            return localFileURL
        }
        
        return URL(string: remoteStreamURL)
    }

    var sourceURLString: String {
        playbackURL?.absoluteString ?? remoteStreamURL
    }

    var prefersLocalPlayback: Bool {
        guard let localFileURL else { return false }
        return FileManager.default.fileExists(atPath: localFileURL.path)
    }
}

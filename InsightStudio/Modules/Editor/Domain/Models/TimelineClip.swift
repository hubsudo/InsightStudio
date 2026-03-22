import Foundation

struct TimelineClip: Hashable, Identifiable, Sendable {
    let id: UUID
    var title: String
    var sourceURLString: String
    var duration: Double

    init(id: UUID = UUID(), title: String, sourceURLString: String, duration: Double) {
        self.id = id
        self.title = title
        self.sourceURLString = sourceURLString
        self.duration = duration
    }
}

extension TimelineClip {
    init(importedClip: ImportedClip) {
        let selectedDuration = max(importedClip.selectedEndSeconds - importedClip.selectedStartSeconds, 0.1)
        self.init(
            id: importedClip.id,
            title: importedClip.title,
            sourceURLString: importedClip.localFileURL.absoluteString,
            duration: selectedDuration
        )
    }
}

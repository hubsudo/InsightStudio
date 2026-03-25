import Combine
import Foundation

enum ImportedClipEvent {
    case inserted(ImportedClip)
    case progress(id: UUID, progress: Double)
    case updated(ImportedClip)
    case failed(id: UUID, message: String)
}

final class ImportSignalCenter {
    let importedClip = PassthroughSubject<ImportedClipEvent, Never>()
}

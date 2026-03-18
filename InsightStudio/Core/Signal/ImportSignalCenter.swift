import Combine
import Foundation

final class ImportSignalCenter {
    let importedClip = PassthroughSubject<ImportedClip, Never>()
}

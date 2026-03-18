import Foundation

protocol ClipLibraryRepository {
    func fetchRecentImports() -> [ImportedClip]
    func save(_ clip: ImportedClip)
    func update(_ clip: ImportedClip)
}

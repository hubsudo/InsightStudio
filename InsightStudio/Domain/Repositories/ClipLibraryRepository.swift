import Foundation

protocol ClipLibraryRepository {
    func fetchRecentImports() -> [ImportedClip]
    func save(_ clip: ImportedClip)
    func update(_ clip: ImportedClip)
    func updateProgress(for id: UUID, progress: Double)
    func markReady(for id: UUID, localFileURL: URL, durationSeconds: Double)
    func markFailed(for id: UUID, message: String)
    func findClip(by id: UUID) -> ImportedClip?
    
    // 删除
    func deleteClip(by id: UUID)
    func deleteAllClips()
    
    // 恢复
    func reconcileLocalFiles() async -> [ImportedClip]
}

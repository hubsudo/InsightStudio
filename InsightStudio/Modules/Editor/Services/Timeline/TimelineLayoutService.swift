import Foundation

final class TimelineLayoutService: @unchecked Sendable {
    private let cacheActor = TimelineLayoutCacheActor()

    init() {}

    func makeSnapshot(
        clips: [TimelineClipLayoutInput],
        key: TimelineLayoutKey
    ) async -> TimelineLayoutSnapshot {
        if let cached = await cacheActor.cachedSnapshot(for: key) {
            return cached
        }
        let generation = await cacheActor.nextGeneration()
        let previous = await cacheActor.latestSnapshot()
        let snapshot = await Task.detached(priority: .userInitiated) {
            TimelineLayoutEngine.buildSnapshot(clips: clips, key: key, previous: previous, generation: generation)
        }.value
        await cacheActor.store(snapshot)
        return snapshot
    }

    func invalidateAll() async {
        await cacheActor.invalidateAll()
    }
}

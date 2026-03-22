import Foundation

actor TimelineLayoutCacheActor {
    private var latest: TimelineLayoutSnapshot?
    private var generation: Int = 0

    init() {}

    func nextGeneration() -> Int {
        generation += 1
        return generation
    }

    func cachedSnapshot(for key: TimelineLayoutKey) -> TimelineLayoutSnapshot? {
        guard let latest, latest.key == key else { return nil }
        return latest
    }

    func latestSnapshot() -> TimelineLayoutSnapshot? {
        latest
    }

    func store(_ snapshot: TimelineLayoutSnapshot) {
        if snapshot.generation >= (latest?.generation ?? -1) {
            latest = snapshot
        }
    }

    func invalidateAll() {
        latest = nil
    }
}

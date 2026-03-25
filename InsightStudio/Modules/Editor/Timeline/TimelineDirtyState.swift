import Foundation

enum TimelineInvalidationReason: Sendable {
    case clipsChanged
    case durationsChanged(startingAtClipID: UUID?)
    case zoomChanged
    case rulerChanged
    case fullReload
}

struct TimelineDirtyState: Sendable {
    var needsFullRelayout: Bool = true
    var dirtyClipIDs: Set<UUID> = []

    mutating func markAllDirty() {
        needsFullRelayout = true
        dirtyClipIDs.removeAll()
    }

    mutating func markDirty(ids: [UUID]) {
        guard !needsFullRelayout else { return }
        dirtyClipIDs.formUnion(ids)
    }

    mutating func consume() -> TimelineDirtyState {
        let copy = self
        needsFullRelayout = false
        dirtyClipIDs.removeAll()
        return copy
    }
}

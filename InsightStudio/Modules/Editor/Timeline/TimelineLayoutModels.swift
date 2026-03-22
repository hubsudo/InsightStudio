import Foundation

struct TimelineInsets: Equatable, Sendable {
    let top: Double
    let left: Double
    let bottom: Double
    let right: Double

    init(top: Double, left: Double, bottom: Double, right: Double) {
        self.top = top
        self.left = left
        self.bottom = bottom
        self.right = right
    }
}

struct TimelineRect: Equatable, Sendable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

struct TimelineLayoutItemModel: Equatable, Sendable, Identifiable {
    let clipID: UUID
    let rect: TimelineRect
    let startTime: Double
    let endTime: Double
    let title: String

    var id: UUID { clipID }

    init(clipID: UUID, rect: TimelineRect, startTime: Double, endTime: Double, title: String) {
        self.clipID = clipID
        self.rect = rect
        self.startTime = startTime
        self.endTime = endTime
        self.title = title
    }
}

struct TimelineLayoutKey: Equatable, Sendable {
    let clipIDs: [UUID]
    let renderedDurations: [Double]
    let pixelsPerSecond: Double
    let trackHeight: Double
    let contentInset: TimelineInsets

    init(
        clipIDs: [UUID],
        renderedDurations: [Double],
        pixelsPerSecond: Double,
        trackHeight: Double,
        contentInset: TimelineInsets
    ) {
        self.clipIDs = clipIDs
        self.renderedDurations = renderedDurations
        self.pixelsPerSecond = pixelsPerSecond
        self.trackHeight = trackHeight
        self.contentInset = contentInset
    }
}

struct TimelineLayoutSnapshot: Equatable, Sendable {
    let key: TimelineLayoutKey
    let items: [TimelineLayoutItemModel]
    let contentWidth: Double
    let generation: Int
    let changedClipIDs: Set<UUID>

    init(
        key: TimelineLayoutKey,
        items: [TimelineLayoutItemModel],
        contentWidth: Double,
        generation: Int,
        changedClipIDs: Set<UUID>
    ) {
        self.key = key
        self.items = items
        self.contentWidth = contentWidth
        self.generation = generation
        self.changedClipIDs = changedClipIDs
    }
}

struct TimelineClipLayoutInput: Equatable, Sendable {
    let id: UUID
    let title: String
    let duration: Double

    init(id: UUID, title: String, duration: Double) {
        self.id = id
        self.title = title
        self.duration = duration
    }
}

import Foundation
import CoreGraphics

public struct TimelineLayoutItem: Equatable {
    public let clipID: UUID
    public let frame: CGRect
    public let startTime: Double
    public let endTime: Double
    public let title: String

    public init(clipID: UUID, frame: CGRect, startTime: Double, endTime: Double, title: String) {
        self.clipID = clipID
        self.frame = frame
        self.startTime = startTime
        self.endTime = endTime
        self.title = title
    }
}

public protocol TimelineLayoutService {
    func makeLayout(
        for draft: TimelineDraft,
        pixelsPerSecond: CGFloat,
        trackHeight: CGFloat,
        contentInset: UIEdgeInsets
    ) -> [TimelineLayoutItem]
}

public final class DefaultTimelineLayoutService: TimelineLayoutService {
    public init() {}

    public func makeLayout(
        for draft: TimelineDraft,
        pixelsPerSecond: CGFloat,
        trackHeight: CGFloat,
        contentInset: UIEdgeInsets
    ) -> [TimelineLayoutItem] {
        var result: [TimelineLayoutItem] = []
        var cursor: Double = 0

        for clip in draft.clips {
            let width = max(CGFloat(clip.renderedDuration) * pixelsPerSecond, 44)
            let x = contentInset.left + CGFloat(cursor) * pixelsPerSecond

            let item = TimelineLayoutItem(
                clipID: clip.id,
                frame: CGRect(x: x, y: contentInset.top, width: width, height: trackHeight),
                startTime: cursor,
                endTime: cursor + clip.renderedDuration,
                title: clip.displayName
            )
            result.append(item)
            cursor += clip.renderedDuration
        }

        return result
    }
}

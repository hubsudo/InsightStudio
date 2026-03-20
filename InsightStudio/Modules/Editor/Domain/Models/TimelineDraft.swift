//
//  TimelineDraft.swift
//  InsightStudio
//
//  Created by chenrunhuan on 2026/3/19.
//

import Foundation
import CoreGraphics

public struct TimeRange: Equatable {
    public var start: Double
    public var duration: Double

    public init(start: Double, duration: Double) {
        self.start = start
        self.duration = duration
    }

    public var end: Double { start + duration }
}

public enum ClipAsset: Equatable {
    case localFile(url: URL)
    case remoteVideo(videoID: String, title: String?, thumbnailURL: URL?)
}

public struct VideoTransform: Equatable {
    public var rotation: CGFloat = 0
    public var isMirrored: Bool = false
    public var scale: CGFloat = 1.0
    public var translation: CGPoint = .zero
    public var cropRect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)

    public init() {}
    public static let identity = VideoTransform()
}

public struct ClipAnimation: Equatable {
    public var intro: AnimationSpec?
    public var outro: AnimationSpec?

    public init(intro: AnimationSpec? = nil, outro: AnimationSpec? = nil) {
        self.intro = intro
        self.outro = outro
    }

    public static let none = ClipAnimation()
}

public struct AnimationSpec: Equatable {
    public var type: AnimationType
    public var duration: Double

    public init(type: AnimationType, duration: Double) {
        self.type = type
        self.duration = duration
    }
}

public enum AnimationType: Equatable {
    case fadeIn
    case fadeOut
    case slideLeft
    case slideRight
    case zoomIn
    case zoomOut
}

public struct Clip: Identifiable, Equatable {
    public let id: UUID
    public let asset: ClipAsset
    public var displayName: String
    public var sourceRange: TimeRange
    public var playbackRate: Double
    public var transform: VideoTransform
    public var animation: ClipAnimation

    public init(
        id: UUID = UUID(),
        asset: ClipAsset,
        displayName: String,
        sourceRange: TimeRange,
        playbackRate: Double = 1.0,
        transform: VideoTransform = .identity,
        animation: ClipAnimation = .none
    ) {
        self.id = id
        self.asset = asset
        self.displayName = displayName
        self.sourceRange = sourceRange
        self.playbackRate = playbackRate
        self.transform = transform
        self.animation = animation
    }

    public var renderedDuration: Double {
        guard playbackRate > 0 else { return sourceRange.duration }
        return sourceRange.duration / playbackRate
    }
}

public struct TimelineDraft: Equatable {
    public var clips: [Clip] = []
    public var selectedClipID: UUID?
    public var playheadSeconds: Double = 0
    public var zoomScale: Double = 1.0

    public init(
        clips: [Clip] = [],
        selectedClipID: UUID? = nil,
        playheadSeconds: Double = 0,
        zoomScale: Double = 1.0
    ) {
        self.clips = clips
        self.selectedClipID = selectedClipID
        self.playheadSeconds = playheadSeconds
        self.zoomScale = zoomScale
    }

    public var totalDuration: Double {
        clips.reduce(0) { $0 + $1.renderedDuration }
    }

    public func indexOfSelectedClip() -> Int? {
        guard let selectedClipID else { return nil }
        return clips.firstIndex(where: { $0.id == selectedClipID })
    }

    public func selectedClip() -> Clip? {
        guard let index = indexOfSelectedClip() else { return nil }
        return clips[index]
    }
}

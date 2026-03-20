import Foundation
import Combine
import UIKit
import AVFoundation

public struct PreviewSnapshot: Equatable {
    public let clipID: UUID?
    public let clipName: String
    public let timelineTime: Double
    public let localClipTime: Double

    public init(clipID: UUID?, clipName: String, timelineTime: Double, localClipTime: Double) {
        self.clipID = clipID
        self.clipName = clipName
        self.timelineTime = timelineTime
        self.localClipTime = localClipTime
    }
}

public struct EditorViewState: Equatable {
    public var draft: TimelineDraft
    public var canUndo: Bool
    public var canRedo: Bool
    public var errorMessage: String?
    public var timelineItems: [TimelineLayoutItem]
    public var isPlaying: Bool

    public static let empty = EditorViewState(
        draft: TimelineDraft(),
        canUndo: false,
        canRedo: false,
        errorMessage: nil,
        timelineItems: [],
        isPlaying: false
    )
}

@MainActor
public final class EditorViewModel: ObservableObject {
    @Published public private(set) var state: EditorViewState

    private let historyManager: HistoryManager
    private let timelineLayoutService: TimelineLayoutService
    private let previewService: EditorPreviewService

    private let pixelsPerSecond: CGFloat = 60
    private let trackHeight: CGFloat = 64

    private var mockAssetCounter = 1
    private var previewTask: Task<Void, Never>?

    public init(
        initialDraft: TimelineDraft = TimelineDraft(),
        timelineLayoutService: TimelineLayoutService,
        previewService: EditorPreviewService
    ) {
        self.historyManager = HistoryManager(initialDraft: initialDraft)
        self.timelineLayoutService = timelineLayoutService
        self.previewService = previewService
        self.state = .empty
        syncState()
    }

    public func appendLocalClip(url: URL) {
        let clip = Clip(
            asset: .localFile(url: url),
            displayName: url.deletingPathExtension().lastPathComponent,
            sourceRange: TimeRange(start: 0, duration: 4)
        )
        historyManager.perform(InsertClipCommand(clip: clip, index: state.draft.clips.count))
        syncStateAndPreview()
    }

    public func appendMockRemoteClip() {
        let index = mockAssetCounter
        mockAssetCounter += 1

        let clip = Clip(
            asset: .remoteVideo(videoID: "mock-\(index)", title: "素材\(index)", thumbnailURL: nil),
            displayName: "素材\(index)",
            sourceRange: TimeRange(start: 0, duration: 4)
        )
        historyManager.perform(InsertClipCommand(clip: clip, index: state.draft.clips.count))
        syncStateAndPreview()
    }

    public func selectClip(id: UUID) {
        historyManager.updateSelection(id)
        syncState()
    }

    public func movePlayhead(to seconds: Double) {
        historyManager.updatePlayhead(seconds)
        syncStateAndPreview(rebuildComposition: false)
    }

    public func splitSelectedClipAtPlayhead() {
        guard let clip = historyManager.draft.selectedClip() else {
            syncError("请先选中一个片段")
            return
        }

        let clipStart = timelineStartSeconds(of: clip.id, in: historyManager.draft)
        let clipEnd = clipStart + clip.renderedDuration
        let playhead = historyManager.draft.playheadSeconds
        guard playhead > clipStart, playhead < clipEnd else {
            syncError("播放头需要落在选中片段内部")
            return
        }

        historyManager.perform(SplitClipCommand(clipID: clip.id, timelineSplitSeconds: playhead))
        syncStateAndPreview()
    }

    public func deleteSelectedClip() {
        guard let selectedID = historyManager.draft.selectedClipID else {
            syncError("请先选中一个片段")
            return
        }
        historyManager.perform(DeleteClipCommand(clipID: selectedID))
        syncStateAndPreview()
    }

    public func undo() {
        historyManager.undo()
        syncStateAndPreview()
    }

    public func redo() {
        historyManager.redo()
        syncStateAndPreview()
    }

    public func togglePlay() {
        if state.isPlaying {
            previewService.pause()
            state.isPlaying = false
        } else {
            previewService.play()
            state.isPlaying = true
        }
    }

    public var playerLayer: AVPlayerLayer {
        previewService.playerLayer
    }

    public func makePreviewSnapshot() -> PreviewSnapshot {
        let time = state.draft.playheadSeconds
        var cursor = 0.0

        for clip in state.draft.clips {
            let rendered = clip.renderedDuration
            let end = cursor + rendered

            if time >= cursor && time <= end {
                let localRenderedOffset = time - cursor
                let localSourceOffset = localRenderedOffset * clip.playbackRate
                return PreviewSnapshot(
                    clipID: clip.id,
                    clipName: clip.displayName,
                    timelineTime: time,
                    localClipTime: clip.sourceRange.start + localSourceOffset
                )
            }
            cursor = end
        }

        return PreviewSnapshot(clipID: nil, clipName: "无预览", timelineTime: time, localClipTime: 0)
    }

    private func syncState() {
        let draft = historyManager.draft
        let items = timelineLayoutService.makeLayout(
            for: draft,
            pixelsPerSecond: pixelsPerSecond,
            trackHeight: trackHeight,
            contentInset: UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        )
        state = EditorViewState(
            draft: draft,
            canUndo: historyManager.canUndo,
            canRedo: historyManager.canRedo,
            errorMessage: nil,
            timelineItems: items,
            isPlaying: state.isPlaying
        )
    }

    private func syncError(_ message: String) {
        syncState()
        state.errorMessage = message
    }

    private func syncStateAndPreview(rebuildComposition: Bool = true) {
        syncState()
        previewTask?.cancel()
        let draft = state.draft
        let playhead = state.draft.playheadSeconds
        previewTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.previewService.updatePreview(draft: draft, at: playhead)
            } catch {
                await MainActor.run {
                    self.state.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func timelineStartSeconds(of clipID: UUID, in draft: TimelineDraft) -> Double {
        var cursor = 0.0
        for clip in draft.clips {
            if clip.id == clipID { return cursor }
            cursor += clip.renderedDuration
        }
        return 0
    }
}

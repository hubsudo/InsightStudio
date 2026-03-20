import Foundation
import Combine
import CoreGraphics
import UIKit

struct PreviewSnapshot: Equatable {
    let clipID: UUID?
    let clipName: String
    let timelineTime: Double
    let localClipTime: Double
}

struct EditorViewState: Equatable {
    var draft: TimelineDraft
    var canUndo: Bool
    var canRedo: Bool
    var errorMessage: String?
    var timelineItems: [TimelineLayoutItem]

    static let empty = EditorViewState(draft: TimelineDraft(), canUndo: false, canRedo: false, errorMessage: nil, timelineItems: [])
}

@MainActor
final class EditorViewModel: ObservableObject {
    @Published private(set) var state: EditorViewState = .empty

    let previewService: EditorPreviewService

    private let historyManager: HistoryManager
    private let timelineLayoutService: TimelineLayoutService
    private let demoLocalAssetProvider: DemoLocalAssetProvider?
    private let pixelsPerSecond: CGFloat = 60
    private let trackHeight: CGFloat = 64
    private var mockAssetCounter = 1
    private var previewTask: Task<Void, Never>?

    init(
        initialDraft: TimelineDraft = TimelineDraft(),
        timelineLayoutService: TimelineLayoutService,
        previewService: EditorPreviewService,
        demoLocalAssetProvider: DemoLocalAssetProvider? = nil
    ) {
        self.historyManager = HistoryManager(initialDraft: initialDraft)
        self.timelineLayoutService = timelineLayoutService
        self.previewService = previewService
        self.demoLocalAssetProvider = demoLocalAssetProvider
        Task { [weak self] in
            guard let self else { return }
            await self.syncState()
            self.refreshPreview()
        }
    }

    func appendDemoClip() {
        appendMockClip(localURL: demoLocalAssetProvider?.nextLocalAssetURL())
    }

    func appendMockClip(localURL: URL? = nil) {
        let clip = makeMockClip(localURL: localURL)
        historyManager.perform(InsertClipCommand(clip: clip, index: state.draft.clips.count))
        triggerSyncAndPreview()
    }

    func insertMockClipAfterSelection(localURL: URL? = nil) {
        let insertIndex = (state.draft.indexOfSelectedClip() ?? (state.draft.clips.count - 1)) + 1
        let clip = makeMockClip(localURL: localURL ?? demoLocalAssetProvider?.nextLocalAssetURL())
        historyManager.perform(InsertClipCommand(clip: clip, index: max(insertIndex, 0)))
        triggerSyncAndPreview()
    }

    func selectClip(id: UUID) {
        historyManager.updateDraft { $0.selectedClipID = id }
        triggerSyncAndPreview(updateLayout: false)
    }

    func movePlayhead(to seconds: Double) {
        historyManager.updateDraft { $0.playheadSeconds = max(0, min(seconds, $0.totalDuration)) }
        triggerSyncAndPreview(updateLayout: false)
    }

    func splitSelectedClipAtPlayhead() {
        guard let clip = state.draft.selectedClip(), let clipStart = state.draft.timelineStartTime(of: clip.id) else {
            state.errorMessage = "请先选中一个片段"
            return
        }
        let playhead = state.draft.playheadSeconds
        guard playhead > clipStart, playhead < clipStart + clip.renderedDuration else {
            state.errorMessage = "播放头需要落在选中片段内部"
            return
        }
        historyManager.perform(SplitClipCommand(clipID: clip.id, timelineSplitSeconds: playhead))
        triggerSyncAndPreview()
    }

    func deleteSelectedClip() {
        guard let selectedID = state.draft.selectedClipID else {
            state.errorMessage = "请先选中一个片段"
            return
        }
        historyManager.perform(DeleteClipCommand(clipID: selectedID))
        triggerSyncAndPreview()
    }

    func moveClip(from sourceIndex: Int, to destinationIndex: Int) {
        historyManager.perform(MoveClipCommand(fromIndex: sourceIndex, toIndex: destinationIndex))
        triggerSyncAndPreview()
    }

    func moveSelectedClipLeft() {
        guard let idx = state.draft.indexOfSelectedClip(), idx > 0 else { return }
        moveClip(from: idx, to: idx - 1)
    }

    func moveSelectedClipRight() {
        guard let idx = state.draft.indexOfSelectedClip(), idx < state.draft.clips.count - 1 else { return }
        moveClip(from: idx, to: idx + 1)
    }

    func updatePlaybackRateForSelection(_ rate: Double) {
        guard let clipID = state.draft.selectedClipID else { return }
        historyManager.perform(UpdatePlaybackRateCommand(clipID: clipID, newRate: rate))
        triggerSyncAndPreview()
    }

    func rotateSelection() {
        guard let clip = state.draft.selectedClip() else { return }
        var transform = clip.transform
        transform.rotationDegrees += 90
        historyManager.perform(UpdateTransformCommand(clipID: clip.id, newTransform: transform))
        triggerSyncAndPreview()
    }

    func mirrorSelection() {
        guard let clip = state.draft.selectedClip() else { return }
        var transform = clip.transform
        transform.isMirrored.toggle()
        historyManager.perform(UpdateTransformCommand(clipID: clip.id, newTransform: transform))
        triggerSyncAndPreview()
    }

    func scaleSelection(_ scale: CGFloat) {
        guard let clip = state.draft.selectedClip() else { return }
        var transform = clip.transform
        transform.scale = max(0.2, min(scale, 3.0))
        historyManager.perform(UpdateTransformCommand(clipID: clip.id, newTransform: transform))
        triggerSyncAndPreview()
    }

    func undo() {
        historyManager.undo()
        triggerSyncAndPreview()
    }

    func redo() {
        historyManager.redo()
        triggerSyncAndPreview()
    }

    func makePreviewSnapshot() -> PreviewSnapshot {
        let time = state.draft.playheadSeconds
        var cursor = 0.0
        for clip in state.draft.clips {
            let end = cursor + clip.renderedDuration
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

    private func triggerSyncAndPreview(updateLayout: Bool = true) {
        Task { [weak self] in
            guard let self else { return }
            if updateLayout { await self.timelineLayoutService.invalidateCache() }
            await self.syncState()
            self.refreshPreview()
        }
    }

    private func syncState() async {
        let draft = historyManager.draft
        let items = await timelineLayoutService.makeLayout(
            for: draft,
            pixelsPerSecond: pixelsPerSecond * draft.zoomScale,
            trackHeight: trackHeight,
            contentInset: UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        )
        state = EditorViewState(
            draft: draft,
            canUndo: historyManager.canUndo,
            canRedo: historyManager.canRedo,
            errorMessage: nil,
            timelineItems: items
        )
    }

    private func refreshPreview() {
        previewTask?.cancel()
        let draft = state.draft
        let t = draft.playheadSeconds
        previewTask = Task { [weak self] in
            guard let self else { return }
            try? await self.previewService.updatePreview(draft: draft, at: t)
        }
    }

    private func makeMockClip(localURL: URL?) -> Clip {
        let index = mockAssetCounter
        mockAssetCounter += 1
        let duration = Double([3,4,5,6].randomElement() ?? 4)
        return Clip(
            asset: localURL.map { .localFile(url: $0) } ?? .remoteVideo(videoID: "mock-\(index)", title: "素材\(index)", thumbnailURL: nil),
            displayName: localURL == nil ? "素材\(index)" : "本地素材\(index)",
            sourceRange: TimeRange(start: 0, duration: duration),
            playbackRate: 1.0,
            transform: .identity
        )
    }
}

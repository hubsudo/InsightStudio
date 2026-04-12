import Foundation
import Combine
import CoreGraphics

@MainActor
final class EditorViewModel: ObservableObject {
    let previewService: EditorPreviewService
    @Published private(set) var currentState: EditorState
    @Published private(set) var timelineSnapshot: TimelineLayoutSnapshot?
    @Published private(set) var snapCandidates: [TimelineSnapCandidate] = []

    private let store: EditorStore
    private let layoutService: TimelineLayoutService
    private var cancellables: Set<AnyCancellable> = []
    private var layoutTask: Task<Void, Never>?
    private var previewTask: Task<Void, Never>?
    private var dirtyState = TimelineDirtyState()

    init(
        initialDraft: EditorDraft,
        store: EditorStore? = nil,
        layoutService: TimelineLayoutService,
        previewService: EditorPreviewService
    ) {
        let store = store ?? EditorStore(initialDraft: initialDraft)
        self.store = store
        self.currentState = store.state
        self.layoutService = layoutService
        self.previewService = previewService
        self.previewService.onPlaybackTimeChange = { [weak self] seconds in
            Task { @MainActor [weak self] in
                self?.syncPlaybackTime(seconds)
            }
        }
        self.previewService.onPlaybackStateChange = { [weak self] isPlaying in
            Task { @MainActor [weak self] in
                self?.syncPlaybackState(isPlaying)
            }
        }

        store.$state
            .sink { [weak self] state in
                guard let self else { return }
                self.currentState = state
                self.snapCandidates = TimelineSnapService.buildCandidates(in: state.draft)
                self.scheduleRelayout(reason: .fullReload)
                self.refreshPreview(shouldPlay: state.playbackUIState == .playing)
            }
            .store(in: &cancellables)

        snapCandidates = TimelineSnapService.buildCandidates(in: currentState.draft)
        scheduleRelayout(reason: .fullReload)
        refreshPreview(shouldPlay: false)
    }

    private func syncPlaybackTime(_ seconds: Double) {
        let clamped = max(0, min(seconds, currentState.draft.totalDuration))
        var nextState = currentState
        nextState.draft.playheadSeconds = clamped
        currentState = nextState
        if clamped >= currentState.draft.totalDuration {
            syncPlaybackState(false)
        }
    }

    private func syncPlaybackState(_ isPlaying: Bool) {
        let nextState: PlaybackUIState = isPlaying ? .playing : .paused
        var updatedState = currentState
        updatedState.playbackUIState = nextState
        updatedState.draft.isPlaying = isPlaying
        currentState = updatedState
    }

    private func refreshPreview(shouldPlay: Bool? = nil) {
        let draft = currentState.draft
        let seconds = currentState.draft.playheadSeconds
        let wantsPlay = shouldPlay ?? (currentState.playbackUIState == .playing)

        previewTask?.cancel()
        previewTask = Task {
            try? await previewService.updatePreview(
                draft: draft,
                at: seconds,
                shouldPlay: wantsPlay
            )
        }
    }

    func appendImportedClip(_ importedClip: ImportedClip) {
        store.perform(
            AppendClipCommand(clip: TimelineClip(importedClip: importedClip)),
            baseDraft: currentState.draft
        )
    }

    func undo() {
        store.setPlaybackUIState(.paused, baseDraft: currentState.draft)
        store.undo(baseDraft: currentState.draft)
    }

    func redo() {
        store.redo(baseDraft: currentState.draft)
    }

    func movePlayhead(
        to seconds: Double,
        recordHistory: Bool = false,
        snapsToCandidates: Bool = true
    ) {
        let snapped = snapsToCandidates
            ? TimelineSnapService.nearestTime(to: seconds, in: currentState.draft)
            : seconds
        if recordHistory {
            store.perform(SetPlayheadCommand(seconds: snapped), baseDraft: currentState.draft)
        } else {
            var draft = currentState.draft
            draft.playheadSeconds = max(0, min(snapped, draft.totalDuration))
            currentState = EditorState(
                draft: draft,
                playbackUIState: currentState.playbackUIState,
                canUndo: currentState.canUndo,
                canRedo: currentState.canRedo
            )
        }
        refreshPreview(shouldPlay: false)
    }

    func setTrimRange(start: Double, end: Double, recordHistory: Bool) {
        if recordHistory {
            store.perform(
                SetTrimRangeCommand(startSeconds: start, endSeconds: end),
                baseDraft: currentState.draft
            )
            return
        }

        var draft = currentState.draft
        draft.setTrimRange(start: start, end: end)
        currentState = EditorState(
            draft: draft,
            playbackUIState: currentState.playbackUIState,
            canUndo: currentState.canUndo,
            canRedo: currentState.canRedo
        )
        refreshPreview(shouldPlay: currentState.playbackUIState == .playing)
    }

    func togglePlayback() {
        switch currentState.playbackUIState {
        case .playing:
            store.setPlaybackUIState(.paused, baseDraft: currentState.draft)
        case .idle, .paused:
            store.setPlaybackUIState(.playing, baseDraft: currentState.draft)
        }
    }

    func anchoredZoom(scaleDelta: CGFloat, anchorX: CGFloat, visibleWidth: CGFloat, currentContentOffsetX: CGFloat) -> CGFloat {
        let oldPPS = currentState.draft.zoomPixelsPerSecond
        let newPPS = min(max(oldPPS * Double(scaleDelta), 24), 240)
        guard abs(newPPS - oldPPS) > 0.25 else { return currentContentOffsetX }

        let currentContentStartX = contentStartX(visibleWidth: visibleWidth, pixelsPerSecond: oldPPS)
        let timeAtAnchor = max(0, (Double(currentContentOffsetX + anchorX) - Double(currentContentStartX)) / oldPPS)

        var draft = currentState.draft
        draft.zoomPixelsPerSecond = newPPS
        currentState = EditorState(
            draft: draft,
            playbackUIState: currentState.playbackUIState,
            canUndo: currentState.canUndo,
            canRedo: currentState.canRedo
        )
        dirtyState.markAllDirty()
        scheduleRelayout(reason: .zoomChanged)

        let newContentStartX = contentStartX(visibleWidth: visibleWidth, pixelsPerSecond: newPPS)
        let newOffset = CGFloat(timeAtAnchor * newPPS) + newContentStartX - anchorX
        return clampedContentOffsetX(newOffset, visibleWidth: visibleWidth, pixelsPerSecond: newPPS)
    }

    func leadingViewportPadding(visibleWidth: CGFloat) -> CGFloat {
        max((visibleWidth / 2) - CGFloat(timelineInsets.left), 0)
    }

    func trailingViewportPadding(visibleWidth: CGFloat) -> CGFloat {
        max((visibleWidth / 2) - CGFloat(timelineInsets.right), 0)
    }

    func contentStartX(visibleWidth: CGFloat, pixelsPerSecond: Double? = nil) -> CGFloat {
        leadingViewportPadding(visibleWidth: visibleWidth) + CGFloat(timelineInsets.left)
    }

    func timelineContentWidth(visibleWidth: CGFloat, pixelsPerSecond: Double? = nil) -> CGFloat {
        let pps = pixelsPerSecond ?? currentState.draft.zoomPixelsPerSecond
        return CGFloat(
            leadingViewportPadding(visibleWidth: visibleWidth)
            + timelineInsets.left
            + currentState.draft.totalDuration * pps
            + timelineInsets.right
            + trailingViewportPadding(visibleWidth: visibleWidth)
        )
    }

    func playheadContentX(visibleWidth: CGFloat, pixelsPerSecond: Double? = nil) -> CGFloat {
        let pps = pixelsPerSecond ?? currentState.draft.zoomPixelsPerSecond
        return contentStartX(visibleWidth: visibleWidth, pixelsPerSecond: pps)
            + CGFloat(currentState.draft.playheadSeconds * pps)
    }

    func clampedContentOffsetX(_ proposed: CGFloat, visibleWidth: CGFloat, pixelsPerSecond: Double? = nil) -> CGFloat {
        let maxOffset = max(0, timelineContentWidth(visibleWidth: visibleWidth, pixelsPerSecond: pixelsPerSecond) - visibleWidth)
        return min(max(proposed, 0), maxOffset)
    }

    func centeredContentOffsetX(visibleWidth: CGFloat) -> CGFloat {
        clampedContentOffsetX(playheadContentX(visibleWidth: visibleWidth) - (visibleWidth / 2), visibleWidth: visibleWidth)
    }

    func playheadSeconds(forCenteredContentOffset contentOffsetX: CGFloat, visibleWidth: CGFloat) -> Double {
        let clampedOffset = clampedContentOffsetX(contentOffsetX, visibleWidth: visibleWidth)
        let centerTimelineX = Double(clampedOffset + (visibleWidth / 2))
        let seconds = (centerTimelineX - Double(contentStartX(visibleWidth: visibleWidth))) / max(currentState.draft.zoomPixelsPerSecond, 1)
        return min(max(seconds, 0), currentState.draft.totalDuration)
    }

    var timelineInsets: TimelineInsets {
        .init(top: 12, left: 16, bottom: 12, right: 16)
    }

    private func scheduleRelayout(reason: TimelineInvalidationReason) {
        switch reason {
        case .zoomChanged, .clipsChanged, .fullReload, .rulerChanged:
            dirtyState.markAllDirty()
        case .durationsChanged:
            dirtyState.markAllDirty()
        }

        let clips = currentState.draft.clips.map {
            TimelineClipLayoutInput(id: $0.id, title: $0.title, duration: $0.duration)
        }

        let key = TimelineLayoutKey(
            clipIDs: clips.map(\.id),
            renderedDurations: clips.map(\.duration),
            pixelsPerSecond: currentState.draft.zoomPixelsPerSecond,
            trackHeight: 72,
            contentInset: timelineInsets
        )

        layoutTask?.cancel()
        layoutTask = Task { [weak self] in
            guard let self else { return }
            let snapshot = await self.layoutService.makeSnapshot(clips: clips, key: key)
            guard !Task.isCancelled else { return }
            if (self.timelineSnapshot?.generation ?? -1) <= snapshot.generation {
                self.timelineSnapshot = snapshot
            }
        }
    }
}

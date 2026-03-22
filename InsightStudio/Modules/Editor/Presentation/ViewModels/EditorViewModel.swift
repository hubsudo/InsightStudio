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

        Task {
            try? await previewService.updatePreview(
                draft: draft,
                at: seconds,
                shouldPlay: wantsPlay
            )
        }
    }

    func appendImportedClip(_ importedClip: ImportedClip) {
        store.perform(AppendClipCommand(clip: TimelineClip(importedClip: importedClip)))
    }

    func undo() {
        store.setPlaybackUIState(.paused)
        store.undo()
    }

    func redo() {
        store.redo()
    }

    func movePlayhead(to seconds: Double, recordHistory: Bool = false) {
        let snapped = TimelineSnapService.nearestTime(to: seconds, in: currentState.draft)
        if recordHistory {
            store.perform(SetPlayheadCommand(seconds: snapped))
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

    func togglePlayback() {
        switch currentState.playbackUIState {
        case .playing:
            store.setPlaybackUIState(.paused)
            refreshPreview(shouldPlay: false)
        case .idle, .paused:
            store.setPlaybackUIState(.playing)
            refreshPreview(shouldPlay: true)
        }
    }

    func anchoredZoom(scaleDelta: CGFloat, anchorX: CGFloat, visibleWidth: CGFloat, currentContentOffsetX: CGFloat) -> CGFloat {
        let oldPPS = currentState.draft.zoomPixelsPerSecond
        let newPPS = min(max(oldPPS * Double(scaleDelta), 24), 240)
        guard abs(newPPS - oldPPS) > 0.25 else { return currentContentOffsetX }

        let insetLeft = timelineInsets.left
        let timeAtAnchor = max(0, (Double(currentContentOffsetX + anchorX) - insetLeft) / oldPPS)

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

        let newOffset = CGFloat(timeAtAnchor * newPPS + insetLeft) - anchorX
        let maxOffset = max(0, CGFloat(draft.totalDuration * newPPS + insetLeft + timelineInsets.right) - visibleWidth)
        return min(max(newOffset, 0), maxOffset)
    }

    var playheadX: CGFloat {
        CGFloat(currentState.draft.playheadSeconds * currentState.draft.zoomPixelsPerSecond + timelineInsets.left)
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

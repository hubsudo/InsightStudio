import Foundation

enum PlaybackUIState: Equatable, Sendable {
    case idle
    case playing
    case paused
}

struct EditorState: Equatable, Sendable {
    var draft: EditorDraft
    var playbackUIState: PlaybackUIState
    var canUndo: Bool
    var canRedo: Bool

    init(
        draft: EditorDraft = .init(),
        playbackUIState: PlaybackUIState = .idle,
        canUndo: Bool = false,
        canRedo: Bool = false
    ) {
        self.draft = draft
        self.playbackUIState = playbackUIState
        self.canUndo = canUndo
        self.canRedo = canRedo
    }
}

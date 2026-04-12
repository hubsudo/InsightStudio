import Foundation
import Combine

@MainActor
final class EditorStore {
    @Published private(set) var state: EditorState
    private let historyManager: HistoryManager

    init(initialDraft: EditorDraft = .init(), historyManager: HistoryManager = .init()) {
        self.state = .init(draft: initialDraft, playbackUIState: .idle, canUndo: false, canRedo: false)
        self.historyManager = historyManager
        syncHistoryFlags()
    }

    func perform(_ command: any EditorCommand, baseDraft: EditorDraft? = nil) {
        if let baseDraft {
            state.draft = baseDraft
        }
        historyManager.perform(command, on: &state.draft)
        syncHistoryFlags()
    }

    func undo(baseDraft: EditorDraft? = nil) {
        if let baseDraft {
            state.draft = baseDraft
        }
        historyManager.undo(on: &state.draft)
        syncHistoryFlags()
    }

    func redo(baseDraft: EditorDraft? = nil) {
        if let baseDraft {
            state.draft = baseDraft
        }
        historyManager.redo(on: &state.draft)
        syncHistoryFlags()
    }

    func setPlaybackUIState(_ newValue: PlaybackUIState, baseDraft: EditorDraft? = nil) {
        if let baseDraft {
            state.draft = baseDraft
        }
        state.playbackUIState = newValue
        state.draft.isPlaying = (newValue == .playing)
    }

    private func syncHistoryFlags() {
        state.canUndo = historyManager.canUndo
        state.canRedo = historyManager.canRedo
    }
}

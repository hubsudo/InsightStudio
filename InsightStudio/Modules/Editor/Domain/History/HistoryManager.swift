import Foundation

final class HistoryManager {
    private(set) var draft: TimelineDraft
    private var undoStack: [any TimelineCommand] = []
    private var redoStack: [any TimelineCommand] = []

    init(initialDraft: TimelineDraft = TimelineDraft()) {
        self.draft = initialDraft
    }

    func perform<C: TimelineCommand>(_ command: C) {
        var cmd = command
        cmd.apply(to: &draft)
        undoStack.append(cmd)
        redoStack.removeAll()
    }

    func updateDraft(_ update: (inout TimelineDraft) -> Void) {
        update(&draft)
    }

    func undo() {
        guard var cmd = undoStack.popLast() else { return }
        cmd.undo(on: &draft)
        redoStack.append(cmd)
    }

    func redo() {
        guard var cmd = redoStack.popLast() else { return }
        cmd.apply(to: &draft)
        undoStack.append(cmd)
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
}

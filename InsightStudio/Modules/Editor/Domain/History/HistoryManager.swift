import Foundation

struct CommandPair: Sendable {
    let forward: any EditorCommand
    let backward: any EditorCommand

    init(forward: any EditorCommand, backward: any EditorCommand) {
        self.forward = forward
        self.backward = backward
    }
}

final class HistoryManager: @unchecked Sendable {
    private var undoStack: [CommandPair] = []
    private var redoStack: [CommandPair] = []

    init() {}

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    func perform(_ command: any EditorCommand, on draft: inout EditorDraft) {
        let old = draft
        command.apply(to: &draft)
        let inverse = command.makeInverse(from: old)
        undoStack.append(.init(forward: command, backward: inverse))
        redoStack.removeAll()
    }

    func undo(on draft: inout EditorDraft) {
        guard let pair = undoStack.popLast() else { return }
        pair.backward.apply(to: &draft)
        redoStack.append(pair)
    }

    func redo(on draft: inout EditorDraft) {
        guard let pair = redoStack.popLast() else { return }
        pair.forward.apply(to: &draft)
        undoStack.append(pair)
    }
}

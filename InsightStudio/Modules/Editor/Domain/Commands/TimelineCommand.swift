import Foundation

protocol TimelineCommand {
    mutating func apply(to draft: inout TimelineDraft)
    mutating func undo(on draft: inout TimelineDraft)
    var description: String { get }
}

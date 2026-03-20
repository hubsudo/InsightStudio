import Foundation

public enum EditorModuleAssembler {
    @MainActor
    public static func build(initialDraft: TimelineDraft = TimelineDraft()) -> EditorViewController {
        let resolver = DefaultClipAssetResolver()
        let compositionBuilder = CompositionBuilder(resolver: resolver)
        let previewService = DefaultEditorPreviewService(compositionBuilder: compositionBuilder)
        let timelineLayoutService = DefaultTimelineLayoutService()
        let viewModel = EditorViewModel(
            initialDraft: initialDraft,
            timelineLayoutService: timelineLayoutService,
            previewService: previewService
        )
        return EditorViewController(viewModel: viewModel)
    }
}

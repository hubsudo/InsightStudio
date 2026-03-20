import Foundation

struct EditorModuleAssembler {
    static func makeEditorViewController(initialDraft: TimelineDraft = TimelineDraft()) -> EditorViewController {
        let demoLocalAssetProvider = BundleDemoLocalAssetProvider()
        let resolver = DefaultClipAssetResolver(fallbackProvider: demoLocalAssetProvider)
        let previewService = DefaultEditorPreviewService(resolver: resolver)
        let timelineLayoutService = DefaultTimelineLayoutService()
        let viewModel = EditorViewModel(
            initialDraft: initialDraft,
            timelineLayoutService: timelineLayoutService,
            previewService: previewService,
            demoLocalAssetProvider: demoLocalAssetProvider
        )
        return EditorViewController(viewModel: viewModel)
    }
}

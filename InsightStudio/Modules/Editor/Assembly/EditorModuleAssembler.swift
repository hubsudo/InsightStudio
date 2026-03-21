import Foundation

struct EditorModuleAssembler {
    static func makeEditorViewController(
        initialDraft: TimelineDraft = TimelineDraft(),
        context: AppContext
    ) -> EditorViewController {
        let demoLocalAssetProvider = BundleDemoLocalAssetProvider()
        let resolver = DefaultClipAssetResolver(fallbackProvider: demoLocalAssetProvider)
        let previewService = DefaultEditorPreviewService(resolver: resolver)
        let timelineLayoutService = DefaultTimelineLayoutService()
        let workspaceViewModel = EditorWorkspaceViewModel(
            repository: context.clipLibraryRepository,
            importSignalCenter: context.importSignalCenter
        )
        let viewModel = EditorViewModel(
            initialDraft: initialDraft,
            timelineLayoutService: timelineLayoutService,
            previewService: previewService,
            demoLocalAssetProvider: demoLocalAssetProvider
        )
        return EditorViewController(
            viewModel: viewModel,
            workspaceViewModel: workspaceViewModel,
            imagePipeline: context.imagePipeline
        )
    }
}

import Foundation

struct EditorModuleBuilder {
    static func makeEditorViewController(
        initialDraft: EditorDraft = EditorDraft(),
        context: AppContext
    ) -> EditorViewController {
        let clipPlayerViewModel = ClipPlayerViewModel()
        let previewService = DefaultEditorPreviewService(
            viewModel: clipPlayerViewModel,
            clipRepository: context.clipLibraryRepository,
        )
        
        let viewModel = EditorViewModel(
            initialDraft: initialDraft,
            layoutService: TimelineLayoutService(),
            previewService: previewService
        )
        let workspaceViewModel = EditorWorkspaceViewModel(
            pipeline: context.clipPipeline,
        )
        return EditorViewController(
            viewModel: viewModel,
            workspaceViewModel: workspaceViewModel,
            context: context,
        )
    }
}

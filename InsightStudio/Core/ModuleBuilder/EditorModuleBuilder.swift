import Foundation

struct EditorModuleBuilder {
    static func makeEditorViewController(
        initialDraft: EditorDraft = EditorDraft(),
        context: AppContext
    ) -> EditorViewController {
        let clipPlayerViewModel = ClipPlayerViewModel()
        let compositionBuilder = TimelineCompositionBuilder(
            clipRepository: context.clipLibraryRepository
        )
        let previewService = DefaultEditorPreviewService(
            viewModel: clipPlayerViewModel,
            compositionBuilder: compositionBuilder
        )
        let exportService = DefaultEditorExportService(
            compositionBuilder: compositionBuilder
        )
        
        let viewModel = EditorViewModel(
            initialDraft: initialDraft,
            layoutService: TimelineLayoutService(),
            previewService: previewService,
            clipRepository: context.clipLibraryRepository
        )
        let workspaceViewModel = EditorWorkspaceViewModel(
            pipeline: context.clipPipeline,
        )
        return EditorViewController(
            viewModel: viewModel,
            workspaceViewModel: workspaceViewModel,
            exportService: exportService,
            context: context,
        )
    }
}

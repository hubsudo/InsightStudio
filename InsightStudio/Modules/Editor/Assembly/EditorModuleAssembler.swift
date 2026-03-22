import Foundation

struct EditorModuleAssembler {
    static func makeEditorViewController(
        initialDraft: EditorDraft = EditorDraft(),
        context: AppContext
    ) -> EditorViewController {
        let workspaceViewModel = EditorWorkspaceViewModel(
            repository: context.clipLibraryRepository,
            importSignalCenter: context.importSignalCenter
        )
        let viewModel = EditorViewModel(
            initialDraft: initialDraft,
            layoutService: TimelineLayoutService(),
            previewService: DefaultEditorPreviewService()
        )
        return EditorViewController(
            viewModel: viewModel,
            workspaceViewModel: workspaceViewModel,
            imagePipeline: context.imagePipeline
        )
    }
}

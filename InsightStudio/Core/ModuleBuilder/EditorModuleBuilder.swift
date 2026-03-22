import UIKit

@MainActor
enum EditorModuleBuilder {
    static func build(context: AppContext, coordinator: EditorCoordinator) -> UIViewController {
        let viewModel = EditorWorkspaceViewModel(
            repository: context.clipLibraryRepository,
            importSignalCenter: context.importSignalCenter
        )
        let vc = EditorWorkspaceViewController(viewModel: viewModel, imagePipeline: context.imagePipeline)
        vc.onSelectClip = { clip in
            coordinator.showClipEditor(clip: clip)
        }
        return vc
    }
}

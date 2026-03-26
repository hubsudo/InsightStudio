import UIKit

@MainActor
enum EditorWorkspaceModuleBuilder {
    static func build(context: AppContext, coordinator: EditorCoordinator) -> UIViewController {
        let viewModel = EditorWorkspaceViewModel(
            pipeline: context.clipPipeline,
        )
        let vc = EditorWorkspaceViewController(
            viewModel: viewModel,
            context: context,
        )
        vc.onSelectClip = { clip in
            coordinator.showClipEditor(clip: clip)
        }
        return vc
    }
}

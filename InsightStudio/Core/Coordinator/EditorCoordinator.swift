import UIKit

final class EditorCoordinator {
    private let navigationController: UINavigationController
    private let context: AppContext

    init(navigationController: UINavigationController, context: AppContext) {
        self.navigationController = navigationController
        self.context = context
    }

    func start() {
        let vc = EditorWorkspaceModuleBuilder.build(context: context, coordinator: self)
        vc.tabBarItem = UITabBarItem(title: "Editor", image: UIImage(systemName: "scissors"), selectedImage: UIImage(systemName: "scissors.circle.fill"))
        navigationController.setViewControllers([vc], animated: false)
    }

    func showClipEditor(clip: ImportedClip) {
        let initialDraft = EditorDraft(importedClip: clip)
        let vc = EditorModuleBuilder.makeEditorViewController(initialDraft: initialDraft, context: context)
        navigationController.pushViewController(vc, animated: true)
    }
}

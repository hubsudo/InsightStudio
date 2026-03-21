import UIKit

final class EditorCoordinator {
    private let navigationController: UINavigationController
    private let context: AppContext

    init(navigationController: UINavigationController, context: AppContext) {
        self.navigationController = navigationController
        self.context = context
    }

    func start() {
        let vc = EditorModuleBuilder.build(context: context, coordinator: self)
        vc.tabBarItem = UITabBarItem(title: "Editor", image: UIImage(systemName: "scissors"), selectedImage: UIImage(systemName: "scissors.circle.fill"))
        navigationController.setViewControllers([vc], animated: false)
    }

    func showClipEditor(clip: ImportedClip) {
//        let vc = ClipEditorViewController(clip: clip, context: context)
        let start = max(0, clip.selectedStartSeconds)
        let end = max(start, clip.selectedEndSeconds)
        guard let url = URL(string: clip.remoteStreamURL) else {
            // 处理错误：URL 不合法
            return
        }
        let asset: ClipAsset = .localFile(url: url)
        let rawClip = Clip(
            id: clip.id,
            asset: asset,
            displayName: clip.title,
            sourceRange: TimeRange(start: start, duration: max(end - start, 0.1))
        )
        let initialDraft = TimelineDraft(clips: [rawClip], selectedClipID: rawClip.id)
        let vc = EditorModuleAssembler.makeEditorViewController(initialDraft: initialDraft, context: context)
        navigationController.pushViewController(vc, animated: true)
    }
}

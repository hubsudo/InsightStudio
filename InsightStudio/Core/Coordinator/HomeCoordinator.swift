import UIKit

final class HomeCoordinator {
    private let navigationController: UINavigationController
    private let context: AppContext

    init(navigationController: UINavigationController, context: AppContext) {
        self.navigationController = navigationController
        self.context = context
    }

    func start() {
        let vc = HomeModuleBuilder.build(context: context, coordinator: self)
        vc.tabBarItem = UITabBarItem(title: "Home", image: UIImage(systemName: "house"), selectedImage: UIImage(systemName: "house.fill"))
        navigationController.setViewControllers([vc], animated: false)
    }

    func showDetail(video: VideoSummary) {
        let vc = VideoDetailViewController(
            video: video,
            context: context,
        )
        navigationController.pushViewController(vc, animated: true)
    }
}

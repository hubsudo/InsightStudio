import UIKit

final class AppCoordinator {
    private let window: UIWindow
    private let context: AppContext

    init(window: UIWindow, context: AppContext) {
        self.window = window
        self.context = context
    }

    func start() {
        let tabBarController = UITabBarController()

        let homeNavigationController = UINavigationController()
        let editorNavigationController = UINavigationController()

        let homeCoordinator = HomeCoordinator(
            navigationController: homeNavigationController,
            context: context
        )
        let editorCoordinator = EditorCoordinator(
            navigationController: editorNavigationController,
            context: context
        )

        homeCoordinator.start()
        editorCoordinator.start()

        tabBarController.viewControllers = [homeNavigationController, editorNavigationController]
        window.rootViewController = tabBarController
        window.makeKeyAndVisible()
    }
}

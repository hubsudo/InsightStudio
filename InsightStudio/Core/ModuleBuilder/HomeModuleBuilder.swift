import UIKit

enum HomeModuleBuilder {
    static func build(context: AppContext, coordinator: HomeCoordinator) -> UIViewController {
        let viewModel = HomeViewModel(repository: context.youtubeRepository)
        let vc = HomeViewController(viewModel: viewModel, imagePipeline: context.imagePipeline)
        vc.onSelectVideo = { video in
            coordinator.showDetail(video: video)
        }
        return vc
    }
}

import UIKit

final class AsyncImageView: UIImageView {
    private var currentURL: String?

    func setImage(urlString: String, pipeline: ImagePipeline) {
        currentURL = urlString
        image = nil

        Task { [weak self] in
            guard let self else { return }
            let image = await pipeline.loadImage(from: urlString)
            guard self.currentURL == urlString else { return }
            self.image = image
        }
    }
}

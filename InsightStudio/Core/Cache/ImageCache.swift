import UIKit

protocol ImageCache {
    func image(for key: NSString) -> UIImage?
    func store(_ image: UIImage, for key: NSString)
}

final class MemoryImageCache: ImageCache {
    private let cache = NSCache<NSString, UIImage>()

    func image(for key: NSString) -> UIImage? {
        cache.object(forKey: key)
    }

    func store(_ image: UIImage, for key: NSString) {
        cache.setObject(image, forKey: key)
    }
}

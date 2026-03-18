import UIKit

protocol ImagePipeline {
    func loadImage(from urlString: String) async -> UIImage?
}

actor ImageTaskStore {
    private var tasks: [String: Task<UIImage?, Never>] = [:]

    func task(for key: String) -> Task<UIImage?, Never>? {
        tasks[key]
    }

    func setTask(_ task: Task<UIImage?, Never>, for key: String) {
        tasks[key] = task
    }

    func removeTask(for key: String) {
        tasks[key] = nil
    }
}

final class DefaultImagePipeline: ImagePipeline {
    private let cache: ImageCache
    private let session: URLSession
    private let taskStore = ImageTaskStore()

    init(cache: ImageCache, session: URLSession = .shared) {
        self.cache = cache
        self.session = session
    }

    func loadImage(from urlString: String) async -> UIImage? {
        let key = urlString as NSString
        if let cached = cache.image(for: key) { return cached }

        if let existingTask = await taskStore.task(for: urlString) {
            return await existingTask.value
        }

        let task = Task<UIImage?, Never> { [session, cache] in
            defer {
                Task { await self.taskStore.removeTask(for: urlString) }
            }

            guard let url = URL(string: urlString) else { return nil }
            do {
                let (data, _) = try await session.data(from: url)
                guard let image = UIImage(data: data) else { return nil }
                cache.store(image, for: key)
                return image
            } catch {
                return nil
            }
        }

        await taskStore.setTask(task, for: urlString)
        return await task.value
    }
}

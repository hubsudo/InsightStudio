import Foundation

struct AppContext {
    let youtubeRepository: VideoSourceRepository
    let clipLibraryRepository: ClipLibraryRepository
    let streamPlaybackService: StreamPlaybackService
    let imagePipeline: ImagePipeline
    let importSignalCenter: ImportSignalCenter
    let clipDownloadService: ClipDownloadService

    static func make() -> AppContext {
        let imageCache = MemoryImageCache()
        let imagePipeline = DefaultImagePipeline(cache: imageCache)
        let importSignalCenter = ImportSignalCenter()

        let youtubeAPIService = YouTubeAPIService()
        let youtubeRepository = DefaultVideoSourceRepository(apiService: youtubeAPIService)

        let clipLibraryRepository = UserDefaultsClipLibraryRepository(
            storageKey: AppEnvironment.recentImportsStorageKey
        )

        let streamPlaybackService = DefaultStreamPlaybackService()

        return AppContext(
            youtubeRepository: youtubeRepository,
            clipLibraryRepository: clipLibraryRepository,
            streamPlaybackService: streamPlaybackService,
            imagePipeline: imagePipeline,
            importSignalCenter: importSignalCenter,
            clipDownloadService: ClipDownloadService(),
        )
    }
}

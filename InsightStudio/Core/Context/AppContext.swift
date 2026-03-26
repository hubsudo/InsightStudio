import Foundation

final class AppContext {
    let youtubeRepository: VideoSourceRepository
    let clipLibraryRepository: any ClipLibraryRepository
    let streamPlaybackService: StreamPlaybackService
    let imagePipeline: ImagePipeline
    let clipDownloadService: ClipDownloadService
    
    lazy var clipPipeline: ClipLibraryPipeline = {
        ClipLibraryPipeline(
            repository: clipLibraryRepository,
            downloadService: clipDownloadService
        )
    }()
    
    init(youtubeRepository: VideoSourceRepository,
         clipLibraryRepository: any ClipLibraryRepository,
         streamPlaybackService: StreamPlaybackService,
         imagePipeline: ImagePipeline,
         clipDownloadService: ClipDownloadService
    ) {
        self.youtubeRepository = youtubeRepository
        self.clipLibraryRepository = clipLibraryRepository
        self.streamPlaybackService = streamPlaybackService
        self.imagePipeline = imagePipeline
        self.clipDownloadService = clipDownloadService
    }

    static func make() -> AppContext {
        let imageCache = MemoryImageCache()
        let imagePipeline = DefaultImagePipeline(cache: imageCache)

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
            clipDownloadService: ClipDownloadService(),
        )
    }
}

import Combine
import Foundation

@MainActor
final class EditorWorkspaceViewModel: ObservableObject {
    @Published private(set) var clips: [ImportedClip] = []
    @Published private(set) var isRestoring: Bool = false
    @Published private(set) var isDeletingAll: Bool = false
    @Published private(set) var errorMessage: String?

    private let pipeline: ClipLibraryPipeline
    private var cancellables: Set<AnyCancellable> = []

    /// ViewModel → Pipeline → Repository
    init(pipeline: ClipLibraryPipeline) {
        self.pipeline = pipeline
        
        /// 不能调换顺序
        /// .restoreFromStorage 发出的 .restored() 有可能在订阅建立前就已经发出去了，导致首屏拿不到数据
        bindState()
        reload()
    }

    func reload() {
        pipeline.send(.restoreFromStorage)
    }
    
    func deleteClip(_ clip: ImportedClip) {
        pipeline.send(.deleteRequested(clip))
    }

    func deleteAll() {
        pipeline.send(.deleteAllRequested)
    }

    private func bindState() {
        pipeline.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.clips = state.clips
                self?.isRestoring = state.isRestoring
                self?.isDeletingAll = state.isDeletingAll
                self?.errorMessage = state.lastErrorMessage
            }
            .store(in: &cancellables)
    }
}

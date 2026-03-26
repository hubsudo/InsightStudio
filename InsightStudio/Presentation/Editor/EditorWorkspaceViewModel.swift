import Combine
import Foundation

@MainActor
final class EditorWorkspaceViewModel: ObservableObject {
    @Published private(set) var clips: [ImportedClip] = []

    private let pipeline: ClipLibraryPipeline
    private var cancellables: Set<AnyCancellable> = []

    /// ViewModel → Pipeline → Repository
    init(pipeline: ClipLibraryPipeline) {
        self.pipeline = pipeline
        
        /// 不能调换顺序
        /// .restoreFromStorage 发出的 .restored() 有可能在订阅建立前就已经发出去了，导致首屏拿不到数据
        bindSignals()
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

    private func bindSignals() {
        pipeline.importedClip
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self else { return }
                self.handle(event)
            }
            .store(in: &cancellables)
    }
    
    private func handle(_ event: ImportedClipEvent) {
        switch event {
        case .inserted(let clip):
            clips.insert(clip, at: 0)

        case .updated(let clip):
            replaceClip(clip)
            
        case .deleted(let id):
            clips.removeAll(where: {$0.id == id})
            
        case .deletedAll:
            clips.removeAll()
            
        case .restored(let restoredClips):
            clips = restoredClips
        }
    }
    
    private func replaceClip(_ clip: ImportedClip) {
        if let index = clips.firstIndex(where: { $0.id == clip.id }) {
            clips[index] = clip
        } else {
            clips.insert(clip, at: 0)
        }
    }
}

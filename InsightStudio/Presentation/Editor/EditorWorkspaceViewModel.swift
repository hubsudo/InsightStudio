import Combine
import Foundation

@MainActor
final class EditorWorkspaceViewModel: ObservableObject {
    @Published private(set) var clips: [ImportedClip] = []

    private let repository: ClipLibraryRepository
    private let importSignalCenter: ImportSignalCenter
    private var cancellables: Set<AnyCancellable> = []

    init(repository: ClipLibraryRepository, importSignalCenter: ImportSignalCenter) {
        self.repository = repository
        self.importSignalCenter = importSignalCenter
        bindSignals()
        reload()
    }

    func reload() {
        clips = repository.fetchRecentImports()
    }

    private func bindSignals() {
        importSignalCenter.importedClip
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

        case .progress(let id, let progress):
            guard let index = clips.firstIndex(where: { $0.id == id }) else { return }
            clips[index].downloadProgress = progress
            clips[index].downloadState = .downloading

        case .updated(let clip):
            guard let index = clips.firstIndex(where: { $0.id == clip.id }) else { return }
            clips[index] = clip

        case .failed(let id, let message):
            guard let index = clips.firstIndex(where: { $0.id == id }) else { return }
            clips[index].downloadState = .failed
            clips[index].lastErrorMessage = message
        }
    }
}

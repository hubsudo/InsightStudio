import Combine
import Foundation

@MainActor
final class EditorWorkspaceViewModel {
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

    func updateClip(_ clip: ImportedClip) {
        repository.update(clip)
        reload()
    }

    private func bindSignals() {
        importSignalCenter.importedClip
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reload()
            }
            .store(in: &cancellables)
    }
}

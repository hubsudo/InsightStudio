import Foundation

protocol DemoLocalAssetProvider {
    func nextLocalAssetURL() -> URL?
}

/// Demo-only helper.
/// It tries to find one of the known sample video names inside the app bundle.
/// You can drop a small mp4/mov into the host app target and reuse this provider
/// without changing the Editor module architecture.
final class BundleDemoLocalAssetProvider: DemoLocalAssetProvider {
    private let candidateNames: [String]
    private var cursor: Int = 0

    init(candidateNames: [String] = ["sample1", "sample2", "sample3", "demo1", "demo2"]) {
        self.candidateNames = candidateNames
    }

    func nextLocalAssetURL() -> URL? {
        guard !candidateNames.isEmpty else { return nil }

        for offset in 0..<candidateNames.count {
            let index = (cursor + offset) % candidateNames.count
            let name = candidateNames[index]
            if let url = Bundle.main.url(forResource: name, withExtension: "mp4") ??
                Bundle.main.url(forResource: name, withExtension: "mov") {
                cursor = (index + 1) % candidateNames.count
                return url
            }
        }
        return nil
    }
}

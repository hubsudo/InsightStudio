import AVKit
import UIKit

final class ClipEditorViewController: UIViewController {
    private var clip: ImportedClip
    private let context: AppContext
    private var playerViewController: AVPlayerViewController?

    private let playerContainer = UIView()
    private let timelineView = EditorTimelineView()
    private let infoLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 14)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    init(clip: ImportedClip, context: AppContext) {
        self.clip = clip
        self.context = context
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "剪辑工作台"
        view.backgroundColor = .systemBackground
        setupUI()
        attachPlayer()
        refreshInfo()
    }

    private func setupUI() {
        playerContainer.translatesAutoresizingMaskIntoConstraints = false
        timelineView.translatesAutoresizingMaskIntoConstraints = false
        timelineView.delegate = self

        view.addSubview(playerContainer)
        view.addSubview(timelineView)
        view.addSubview(infoLabel)

        NSLayoutConstraint.activate([
            playerContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playerContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            playerContainer.heightAnchor.constraint(equalTo: playerContainer.widthAnchor, multiplier: 9.0/16.0),

            timelineView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            timelineView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            timelineView.topAnchor.constraint(equalTo: playerContainer.bottomAnchor, constant: 20),
            timelineView.heightAnchor.constraint(equalToConstant: 88),

            infoLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            infoLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            infoLabel.topAnchor.constraint(equalTo: timelineView.bottomAnchor, constant: 16)
        ])
    }

    private func attachPlayer() {
        guard let player = PlayerFactory.makePlayer(urlString: clip.remoteStreamURL) else { return }
        let pvc = AVPlayerViewController()
        pvc.player = player
        addChild(pvc)
        pvc.view.translatesAutoresizingMaskIntoConstraints = false
        playerContainer.addSubview(pvc.view)
        NSLayoutConstraint.activate([
            pvc.view.leadingAnchor.constraint(equalTo: playerContainer.leadingAnchor),
            pvc.view.trailingAnchor.constraint(equalTo: playerContainer.trailingAnchor),
            pvc.view.topAnchor.constraint(equalTo: playerContainer.topAnchor),
            pvc.view.bottomAnchor.constraint(equalTo: playerContainer.bottomAnchor)
        ])
        pvc.didMove(toParent: self)
        playerViewController = pvc

        let endRatio = CGFloat(min(max(clip.selectedEndSeconds / 60.0, 0.2), 1.0))
        timelineView.setSelection(startRatio: 0, endRatio: endRatio)
    }

    private func refreshInfo() {
        infoLabel.text = "当前片段：\nstart = \(String(format: "%.2f", clip.selectedStartSeconds))s\nend = \(String(format: "%.2f", clip.selectedEndSeconds))s"
    }
}

extension ClipEditorViewController: EditorTimelineViewDelegate {
    func timelineView(_ view: EditorTimelineView, didChange startRatio: CGFloat, endRatio: CGFloat) {
        let fakeTotalDuration: Double = 60
        clip.selectedStartSeconds = Double(startRatio) * fakeTotalDuration
        clip.selectedEndSeconds = Double(endRatio) * fakeTotalDuration
        context.clipLibraryRepository.update(clip)
        refreshInfo()
    }
}

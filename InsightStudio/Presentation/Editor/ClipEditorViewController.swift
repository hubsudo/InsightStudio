import AVKit
import UIKit

final class ClipEditorViewController: UIViewController {
    private var clip: ImportedClip
    private let context: AppContext
    private var playerViewController: AVPlayerViewController?
    private var itemStatusObservation: NSKeyValueObservation?

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

    deinit {
        itemStatusObservation?.invalidate()
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
        player.pause()
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
        observePlayerItem(player.currentItem)
        syncTimelineSelection()
        seekPreview(to: clip.selectedStartSeconds)
    }

    private func observePlayerItem(_ item: AVPlayerItem?) {
        itemStatusObservation?.invalidate()
        itemStatusObservation = item?.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            guard item.status == .readyToPlay else { return }
            DispatchQueue.main.async {
                self?.syncTimelineSelection()
            }
        }
    }

    private func syncTimelineSelection() {
        let duration = resolvedDurationSeconds()
        let startRatio = CGFloat(min(max(clip.selectedStartSeconds / duration, 0), 1))
        let endRatio = CGFloat(min(max(clip.selectedEndSeconds / duration, startRatio + 0.05), 1))
        timelineView.setSelection(startRatio: startRatio, endRatio: endRatio)
    }

    private func resolvedDurationSeconds() -> Double {
        if let duration = playerViewController?.player?.currentItem?.duration.seconds, duration.isFinite, duration > 0 {
            return duration
        }
        if let duration = playerViewController?.player?.currentItem?.asset.duration.seconds, duration.isFinite, duration > 0 {
            return duration
        }
        return max(clip.selectedEndSeconds, clip.selectedStartSeconds + 1, 1)
    }

    private func seekPreview(to seconds: Double) {
        guard let player = playerViewController?.player else { return }
        let clampedSeconds = min(max(seconds, 0), resolvedDurationSeconds())
        let time = CMTime(seconds: clampedSeconds, preferredTimescale: 600)
        player.pause()
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func refreshInfo() {
        infoLabel.text = "当前片段：\nstart = \(String(format: "%.2f", clip.selectedStartSeconds))s\nend = \(String(format: "%.2f", clip.selectedEndSeconds))s"
    }
}

extension ClipEditorViewController: EditorTimelineViewDelegate {
    func timelineView(_ view: EditorTimelineView, didChange startRatio: CGFloat, endRatio: CGFloat, activeHandle: EditorTimelineHandle) {
        let duration = resolvedDurationSeconds()
        clip.selectedStartSeconds = Double(startRatio) * duration
        clip.selectedEndSeconds = Double(endRatio) * duration
        context.clipLibraryRepository.update(clip)
        refreshInfo()
        let previewSeconds = activeHandle == .left ? clip.selectedStartSeconds : clip.selectedEndSeconds
        seekPreview(to: previewSeconds)
    }
}

import UIKit
import Combine

final class EditorViewController: UIViewController {
    private let viewModel: EditorViewModel
    private let workspaceViewModel: EditorWorkspaceViewModel
    private let imagePipeline: ImagePipeline
    private var cancellables = Set<AnyCancellable>()

    private let previewContainer = PreviewContainerView()
    private let previewTitleLabel = UILabel()
    private let previewSubtitleLabel = UILabel()
    private let summaryLabel = UILabel()
    private let playPauseButton = UIButton(type: .system)
    private let timelineView = TimelineView()
    private let playheadSlider = UISlider()

    private let addButton = UIButton(type: .system)
    private let undoButton = UIButton(type: .system)
    private let redoButton = UIButton(type: .system)

    private var currentState: EditorViewState = .empty

    init(
        viewModel: EditorViewModel,
        workspaceViewModel: EditorWorkspaceViewModel,
        imagePipeline: ImagePipeline
    ) {
        self.viewModel = viewModel
        self.workspaceViewModel = workspaceViewModel
        self.imagePipeline = imagePipeline
        super.init(nibName: nil, bundle: nil)
        self.title = "Editor Demo"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bind()
        previewContainer.attach(playerLayer: viewModel.previewService.playerLayer)
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground

        previewContainer.backgroundColor = .black
        previewContainer.layer.cornerRadius = 12
        previewContainer.clipsToBounds = true
        previewContainer.translatesAutoresizingMaskIntoConstraints = false

        previewTitleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        previewTitleLabel.textColor = .label
        previewSubtitleLabel.font = .systemFont(ofSize: 13)
        previewSubtitleLabel.textColor = .secondaryLabel
        previewSubtitleLabel.numberOfLines = 0
        summaryLabel.font = .systemFont(ofSize: 13)
        summaryLabel.numberOfLines = 0

        playPauseButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        playPauseButton.addTarget(self, action: #selector(playPauseTapped), for: .touchUpInside)

        timelineView.translatesAutoresizingMaskIntoConstraints = false
        timelineView.delegate = self

        playheadSlider.minimumValue = 0
        playheadSlider.addTarget(self, action: #selector(playheadChanged(_:)), for: .valueChanged)

        [addButton, undoButton, redoButton].forEach {
            $0.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        }
        addButton.setTitle("追加远程", for: .normal)
        undoButton.setTitle("Undo", for: .normal)
        redoButton.setTitle("Redo", for: .normal)

        addButton.addTarget(self, action: #selector(addTapped), for: .touchUpInside)
        undoButton.addTarget(self, action: #selector(undoTapped), for: .touchUpInside)
        redoButton.addTarget(self, action: #selector(redoTapped), for: .touchUpInside)

        let previewInfo = UIStackView(arrangedSubviews: [previewTitleLabel, previewSubtitleLabel])
        previewInfo.axis = .vertical
        previewInfo.spacing = 6

        let row1 = UIStackView(arrangedSubviews: [addButton])
        row1.axis = .horizontal; row1.spacing = 8; row1.distribution = .fillEqually
        let row2 = UIStackView(arrangedSubviews: [undoButton, redoButton])
        row2.axis = .horizontal; row2.spacing = 8; row2.distribution = .fillEqually

        let root = UIStackView(arrangedSubviews: [previewContainer, previewInfo, summaryLabel, playPauseButton, timelineView, playheadSlider, row1, row2])
        root.axis = .vertical
        root.spacing = 12
        root.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(root)

        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            root.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            root.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            root.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            previewContainer.heightAnchor.constraint(equalToConstant: 220),
            timelineView.heightAnchor.constraint(equalToConstant: 120),
        ])
    }

    private func bind() {
        viewModel.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.render($0) }
            .store(in: &cancellables)
    }

    private func render(_ state: EditorViewState) {
        currentState = state
        let snapshot = viewModel.makePreviewSnapshot()
        previewTitleLabel.text = snapshot.clipName
        previewSubtitleLabel.text = "timeline: \(String(format: "%.2f", snapshot.timelineTime))s | clip local: \(String(format: "%.2f", snapshot.localClipTime))s"
        summaryLabel.text = "clips: \(state.draft.clips.count) | total: \(String(format: "%.2f", state.draft.totalDuration))s | playhead: \(String(format: "%.2f", state.draft.playheadSeconds))s"
        playPauseButton.setTitle(state.isPlaying ? "暂停" : "播放", for: .normal)

        playheadSlider.maximumValue = Float(max(state.draft.totalDuration, 0.1))
        playheadSlider.value = Float(state.draft.playheadSeconds)
        timelineView.render(
            items: state.timelineItems,
            selectedClipID: state.draft.selectedClipID,
            playheadSeconds: state.draft.playheadSeconds,
            totalDuration: state.draft.totalDuration
        )

        undoButton.isEnabled = state.canUndo
        redoButton.isEnabled = state.canRedo

        if let message = state.errorMessage, presentedViewController == nil {
            let alert = UIAlertController(title: "提示", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "知道了", style: .default))
            present(alert, animated: true)
        }
    }

    @objc private func addTapped() { presentRemoteClipPicker() }
    @objc private func undoTapped() { viewModel.undo() }
    @objc private func redoTapped() { viewModel.redo() }
    @objc private func playheadChanged(_ sender: UISlider) { viewModel.movePlayhead(to: Double(sender.value)) }
    @objc private func playPauseTapped() { viewModel.togglePlayback() }

    private func presentRemoteClipPicker() {
        workspaceViewModel.reload()
        let excludedIDs = Set(currentState.draft.clips.map(\.id))
        let availableClips = workspaceViewModel.clips.filter { !excludedIDs.contains($0.id) }
        guard !availableClips.isEmpty else {
            let alert = UIAlertController(title: "提示", message: "素材库里没有可追加的其他视频", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "知道了", style: .default))
            present(alert, animated: true)
            return
        }

        let picker = EditorWorkspaceViewController(viewModel: workspaceViewModel, imagePipeline: imagePipeline)
        picker.screenTitle = "追加远程素材"
        picker.clipFilter = { clip in
            !excludedIDs.contains(clip.id)
        }
        picker.onSelectClip = { [weak self] clip in
            self?.viewModel.appendImportedClip(clip)
            self?.dismiss(animated: true)
        }

        let nav = UINavigationController(rootViewController: picker)
        picker.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(dismissPresentedPicker)
        )
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(nav, animated: true)
    }

    @objc private func dismissPresentedPicker() {
        presentedViewController?.dismiss(animated: true)
    }
}

extension EditorViewController: TimelineViewDelegate {
    func timelineView(_ timelineView: TimelineView, didSelectClip id: UUID) {
        viewModel.selectClip(id: id)
    }

    func timelineView(_ timelineView: TimelineView, didRequestTrimSelectedClipUsing handle: TimelineTrimHandle) {
        viewModel.trimSelectedClip(using: handle)
    }
}

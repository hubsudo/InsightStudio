import UIKit
import Combine

@MainActor
final class EditorViewController: UIViewController {
    private let viewModel: EditorViewModel
    private let workspaceViewModel: EditorWorkspaceViewModel
    private let context: AppContext

    private let previewContainer = PreviewContainerView()
    private let timelineView = TimelineView()
    private let addButton = UIButton(type: .system)
    private let undoButton = UIButton(type: .system)
    private let redoButton = UIButton(type: .system)
    private let playPauseButton = UIButton(type: .system)
    private let playheadSlider = UISlider()
    private let summaryLabel = UILabel()
    private let previewSubtitleLabel = UILabel()

    private var cancellables: Set<AnyCancellable> = []

    init(
        viewModel: EditorViewModel,
        workspaceViewModel: EditorWorkspaceViewModel,
        context: AppContext,
    ) {
        self.viewModel = viewModel
        self.workspaceViewModel = workspaceViewModel
        self.context = context
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Editor"
        view.backgroundColor = .systemBackground
        setupUI()
        bind()
        previewContainer.attach(playerLayer: viewModel.previewService.playerLayer)
    }

    private func setupUI() {
        addButton.setTitle("追加远程", for: .normal)
        undoButton.setTitle("Undo", for: .normal)
        redoButton.setTitle("Redo", for: .normal)
        playPauseButton.setTitle("Play/Pause", for: .normal)

        addButton.addTarget(self, action: #selector(addTapped), for: .touchUpInside)
        undoButton.addTarget(self, action: #selector(undoTapped), for: .touchUpInside)
        redoButton.addTarget(self, action: #selector(redoTapped), for: .touchUpInside)
        playheadSlider.addTarget(self, action: #selector(playheadChanged(_:)), for: .valueChanged)
        playPauseButton.addTarget(self, action: #selector(playPauseTapped), for: .touchUpInside)

        let buttonStack = UIStackView(arrangedSubviews: [addButton, undoButton, redoButton, playPauseButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 12
        buttonStack.distribution = .fillEqually

        summaryLabel.font = .systemFont(ofSize: 13, weight: .medium)
        previewSubtitleLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        previewSubtitleLabel.textColor = .secondaryLabel
        previewContainer.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.backgroundColor = .black
        previewContainer.layer.cornerRadius = 12
        previewContainer.clipsToBounds = true

        let stack = UIStackView(arrangedSubviews: [buttonStack, previewContainer, timelineView, playheadSlider, summaryLabel, previewSubtitleLabel])
        stack.axis = .vertical
        stack.spacing = 12
        view.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        timelineView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            previewContainer.heightAnchor.constraint(equalTo: previewContainer.widthAnchor, multiplier: 9.0 / 16.0),
            timelineView.heightAnchor.constraint(equalToConstant: 120),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])

        timelineView.collectionView.dataSource = self
        timelineView.collectionView.delegate = self
        timelineView.onPinchScaleChanged = { [weak self] scale, location, _ in
            guard let self else { return }
            let newOffset = self.viewModel.anchoredZoom(
                scaleDelta: scale,
                anchorX: location.x,
                visibleWidth: self.timelineView.scrollView.bounds.width,
                currentContentOffsetX: self.timelineView.scrollView.contentOffset.x
            )
            self.timelineView.scrollView.setContentOffset(CGPoint(x: newOffset, y: 0), animated: false)
        }
        timelineView.onScrolled = { [weak self] _ in
            guard let self else { return }
            self.timelineView.updatePlayheadX(self.viewModel.playheadX)
        }
    }

    private func bind() {
        viewModel.$currentState
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self else { return }
                self.undoButton.isEnabled = state.canUndo
                self.redoButton.isEnabled = state.canRedo
                self.playheadSlider.minimumValue = 0
                self.playheadSlider.maximumValue = Float(max(state.draft.totalDuration, 0.1))
                self.playheadSlider.value = Float(state.draft.playheadSeconds)
                self.playPauseButton.setTitle(state.playbackUIState == .playing ? "Pause" : "Play", for: .normal)
                self.summaryLabel.text = "clips: \(state.draft.clips.count) | total: \(String(format: "%.2f", state.draft.totalDuration))s | playhead: \(String(format: "%.2f", state.draft.playheadSeconds))s"
                self.previewSubtitleLabel.text = "zoom: \(Int(state.draft.zoomPixelsPerSecond)) px/s | playback: \(state.playbackUIState)"
                self.timelineView.rulerView.pixelsPerSecond = state.draft.zoomPixelsPerSecond
                self.timelineView.rulerView.totalDuration = state.draft.totalDuration
                self.timelineView.rulerView.leftInset = CGFloat(self.viewModel.timelineInsets.left)
                self.timelineView.updatePlayheadX(self.viewModel.playheadX)
            }
            .store(in: &cancellables)

        viewModel.$timelineSnapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] snapshot in
                guard let self, let snapshot else { return }
                self.timelineView.scrollView.contentSize = CGSize(width: CGFloat(snapshot.contentWidth), height: self.timelineView.scrollView.bounds.height)
                self.timelineView.collectionView.frame = CGRect(x: 0, y: 0, width: CGFloat(snapshot.contentWidth), height: self.timelineView.scrollView.bounds.height)
                self.timelineView.collectionView.reloadData()
                self.timelineView.updatePlayheadX(self.viewModel.playheadX)
            }
            .store(in: &cancellables)
    }

    @objc private func addTapped() { presentRemoteClipPicker() }
    @objc private func undoTapped() { viewModel.undo() }
    @objc private func redoTapped() { viewModel.redo() }
    @objc private func playheadChanged(_ sender: UISlider) { viewModel.movePlayhead(to: Double(sender.value)) }
    @objc private func playPauseTapped() { viewModel.togglePlayback() }

    private func presentRemoteClipPicker() {
        workspaceViewModel.reload()
        let excludedIDs = Set(viewModel.currentState.draft.clips.map(\.id))
        let availableClips = workspaceViewModel.clips.filter { !excludedIDs.contains($0.id) }
        guard !availableClips.isEmpty else {
            let alert = UIAlertController(title: "提示", message: "素材库里没有可追加的其他视频", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "知道了", style: .default))
            present(alert, animated: true)
            return
        }

        let picker = EditorWorkspaceViewController(
            viewModel: workspaceViewModel,
            context: context,
        )
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
        dismiss(animated: true)
    }
}

extension EditorViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        viewModel.timelineSnapshot?.items.count ?? 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TimelineClipCell.reuseIdentifier, for: indexPath) as? TimelineClipCell,
            let item = viewModel.timelineSnapshot?.items[indexPath.item]
        else {
            return UICollectionViewCell()
        }
        cell.configure(title: item.title)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        guard let item = viewModel.timelineSnapshot?.items[indexPath.item] else { return .zero }
        return CGSize(width: CGFloat(item.rect.width), height: CGFloat(item.rect.height))
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        let inset = viewModel.timelineInsets
        return UIEdgeInsets(top: CGFloat(inset.top), left: CGFloat(inset.left), bottom: CGFloat(inset.bottom), right: CGFloat(inset.right))
    }
}

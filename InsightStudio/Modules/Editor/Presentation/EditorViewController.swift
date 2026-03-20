import UIKit
import Combine

final class EditorViewController: UIViewController {
    private let viewModel: EditorViewModel
    private var cancellables = Set<AnyCancellable>()

    private let previewContainer = PreviewContainerView()
    private let previewTitleLabel = UILabel()
    private let previewSubtitleLabel = UILabel()
    private let summaryLabel = UILabel()
    private let playheadSlider = UISlider()
    private let timelineView = TimelineView()

    private let addButton = UIButton(type: .system)
    private let addLocalButton = UIButton(type: .system)
    private let insertAfterButton = UIButton(type: .system)
    private let splitButton = UIButton(type: .system)
    private let deleteButton = UIButton(type: .system)
    private let undoButton = UIButton(type: .system)
    private let redoButton = UIButton(type: .system)
    private let moveLeftButton = UIButton(type: .system)
    private let moveRightButton = UIButton(type: .system)
    private let rateButton = UIButton(type: .system)
    private let rotateButton = UIButton(type: .system)
    private let mirrorButton = UIButton(type: .system)

    private var currentState: EditorViewState = .empty

    init(viewModel: EditorViewModel) {
        self.viewModel = viewModel
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

        timelineView.delegate = self
        timelineView.translatesAutoresizingMaskIntoConstraints = false

        playheadSlider.minimumValue = 0
        playheadSlider.addTarget(self, action: #selector(playheadChanged(_:)), for: .valueChanged)

        [addButton, addLocalButton, insertAfterButton, splitButton, deleteButton, undoButton, redoButton, moveLeftButton, moveRightButton, rateButton, rotateButton, mirrorButton].forEach {
            $0.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        }
        addButton.setTitle("追加远端Mock", for: .normal)
        addLocalButton.setTitle("追加本地Mock", for: .normal)
        insertAfterButton.setTitle("选中后插入", for: .normal)
        splitButton.setTitle("分割", for: .normal)
        deleteButton.setTitle("删除", for: .normal)
        undoButton.setTitle("Undo", for: .normal)
        redoButton.setTitle("Redo", for: .normal)
        moveLeftButton.setTitle("左移", for: .normal)
        moveRightButton.setTitle("右移", for: .normal)
        rateButton.setTitle("变速1.5x", for: .normal)
        rotateButton.setTitle("旋转", for: .normal)
        mirrorButton.setTitle("镜像", for: .normal)

        addButton.addTarget(self, action: #selector(addTapped), for: .touchUpInside)
        addLocalButton.addTarget(self, action: #selector(addLocalTapped), for: .touchUpInside)
        insertAfterButton.addTarget(self, action: #selector(insertAfterTapped), for: .touchUpInside)
        splitButton.addTarget(self, action: #selector(splitTapped), for: .touchUpInside)
        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
        undoButton.addTarget(self, action: #selector(undoTapped), for: .touchUpInside)
        redoButton.addTarget(self, action: #selector(redoTapped), for: .touchUpInside)
        moveLeftButton.addTarget(self, action: #selector(moveLeftTapped), for: .touchUpInside)
        moveRightButton.addTarget(self, action: #selector(moveRightTapped), for: .touchUpInside)
        rateButton.addTarget(self, action: #selector(rateTapped), for: .touchUpInside)
        rotateButton.addTarget(self, action: #selector(rotateTapped), for: .touchUpInside)
        mirrorButton.addTarget(self, action: #selector(mirrorTapped), for: .touchUpInside)

        let previewInfo = UIStackView(arrangedSubviews: [previewTitleLabel, previewSubtitleLabel])
        previewInfo.axis = .vertical
        previewInfo.spacing = 6

        let row1 = UIStackView(arrangedSubviews: [addButton, addLocalButton, insertAfterButton, splitButton])
        row1.axis = .horizontal; row1.spacing = 8; row1.distribution = .fillEqually
        let row2 = UIStackView(arrangedSubviews: [deleteButton, undoButton, redoButton, moveLeftButton])
        row2.axis = .horizontal; row2.spacing = 8; row2.distribution = .fillEqually
        let row3 = UIStackView(arrangedSubviews: [moveRightButton, rateButton, rotateButton, mirrorButton])
        row3.axis = .horizontal; row3.spacing = 8; row3.distribution = .fillEqually

        let root = UIStackView(arrangedSubviews: [previewContainer, previewInfo, summaryLabel, playheadSlider, timelineView, row1, row2, row3])
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
            timelineView.heightAnchor.constraint(equalToConstant: 84)
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
        
        playheadSlider.maximumValue = Float(max(state.draft.totalDuration, 0.1))
        playheadSlider.value = Float(state.draft.playheadSeconds)
        timelineView.render(items: state.timelineItems, selectedClipID: state.draft.selectedClipID)

        undoButton.isEnabled = state.canUndo
        redoButton.isEnabled = state.canRedo
        let hasSelection = state.draft.selectedClipID != nil
        [splitButton, deleteButton, moveLeftButton, moveRightButton, rateButton, rotateButton, mirrorButton].forEach { $0.isEnabled = hasSelection }

        if let message = state.errorMessage, presentedViewController == nil {
            let alert = UIAlertController(title: "提示", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "知道了", style: .default))
            present(alert, animated: true)
        }
    }

    @objc private func addTapped() { viewModel.appendMockClip() }
    @objc private func addLocalTapped() { viewModel.appendDemoClip() }
    @objc private func insertAfterTapped() { viewModel.insertMockClipAfterSelection() }
    @objc private func splitTapped() { viewModel.splitSelectedClipAtPlayhead() }
    @objc private func deleteTapped() { viewModel.deleteSelectedClip() }
    @objc private func undoTapped() { viewModel.undo() }
    @objc private func redoTapped() { viewModel.redo() }
    @objc private func moveLeftTapped() { viewModel.moveSelectedClipLeft() }
    @objc private func moveRightTapped() { viewModel.moveSelectedClipRight() }
    @objc private func rateTapped() { viewModel.updatePlaybackRateForSelection(1.5) }
    @objc private func rotateTapped() { viewModel.rotateSelection() }
    @objc private func mirrorTapped() { viewModel.mirrorSelection() }
    @objc private func playheadChanged(_ sender: UISlider) { viewModel.movePlayhead(to: Double(sender.value)) }
}

extension EditorViewController: TimelineViewDelegate {
    func timelineView(_ timelineView: TimelineView, didSelectClip id: UUID) {
        viewModel.selectClip(id: id)
    }

    func timelineView(_ timelineView: TimelineView, didMoveClipFrom sourceIndex: Int, to destinationIndex: Int) {
        viewModel.moveClip(from: sourceIndex, to: destinationIndex)
    }
}

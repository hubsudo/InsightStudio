import UIKit
import Combine
import UniformTypeIdentifiers

public final class EditorViewController: UIViewController {
    private let viewModel: EditorViewModel
    private var cancellables = Set<AnyCancellable>()

    private let previewView = PreviewContainerView()
    private let summaryLabel = UILabel()
    private let playheadSlider = UISlider()
    private let timelineView = TimelineView()

    private let addLocalButton = UIButton(type: .system)
    private let splitButton = UIButton(type: .system)
    private let deleteButton = UIButton(type: .system)
    private let undoButton = UIButton(type: .system)
    private let redoButton = UIButton(type: .system)
    private let playPauseButton = UIButton(type: .system)

    private var currentState: EditorViewState = .empty

    public init(viewModel: EditorViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        self.title = "Editor Composition Preview"
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bind()
        previewView.attach(playerLayer: viewModel.playerLayer)
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground
        timelineView.delegate = self

        summaryLabel.numberOfLines = 0
        summaryLabel.font = .systemFont(ofSize: 13)
        summaryLabel.textColor = .secondaryLabel

        playheadSlider.minimumValue = 0
        playheadSlider.addTarget(self, action: #selector(playheadChanged(_:)), for: .valueChanged)

        addLocalButton.setTitle("添加本地素材", for: .normal)
        splitButton.setTitle("分割", for: .normal)
        deleteButton.setTitle("删除", for: .normal)
        undoButton.setTitle("Undo", for: .normal)
        redoButton.setTitle("Redo", for: .normal)
        playPauseButton.setTitle("播放", for: .normal)

        addLocalButton.addTarget(self, action: #selector(addLocalTapped), for: .touchUpInside)
        splitButton.addTarget(self, action: #selector(splitTapped), for: .touchUpInside)
        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
        undoButton.addTarget(self, action: #selector(undoTapped), for: .touchUpInside)
        redoButton.addTarget(self, action: #selector(redoTapped), for: .touchUpInside)
        playPauseButton.addTarget(self, action: #selector(playPauseTapped), for: .touchUpInside)

        let row1 = UIStackView(arrangedSubviews: [addLocalButton, playPauseButton])
        row1.axis = .horizontal
        row1.spacing = 8
        row1.distribution = .fillEqually

        let row2 = UIStackView(arrangedSubviews: [splitButton, deleteButton, undoButton, redoButton])
        row2.axis = .horizontal
        row2.spacing = 8
        row2.distribution = .fillEqually

        let root = UIStackView(arrangedSubviews: [previewView, summaryLabel, playheadSlider, timelineView, row1, row2])
        root.axis = .vertical
        root.spacing = 12
        root.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(root)

        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            root.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            root.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            root.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -12),
            previewView.heightAnchor.constraint(equalToConstant: 280),
            timelineView.heightAnchor.constraint(equalToConstant: 84)
        ])
    }

    private func bind() {
        viewModel.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.render(state)
            }
            .store(in: &cancellables)
    }

    private func render(_ state: EditorViewState) {
        currentState = state

        summaryLabel.text = "clips: \(state.draft.clips.count)\n" +
            "total: \(String(format: "%.2f", state.draft.totalDuration))s\n" +
            "playhead: \(String(format: "%.2f", state.draft.playheadSeconds))s\n" +
            "selected: \(state.draft.selectedClipID?.uuidString.prefix(6) ?? "nil")"

        playheadSlider.maximumValue = Float(max(state.draft.totalDuration, 0.1))
        playheadSlider.value = Float(state.draft.playheadSeconds)

        timelineView.render(items: state.timelineItems, selectedClipID: state.draft.selectedClipID)
        previewView.render(snapshot: viewModel.makePreviewSnapshot())

        undoButton.isEnabled = state.canUndo
        redoButton.isEnabled = state.canRedo
        splitButton.isEnabled = state.draft.selectedClipID != nil
        deleteButton.isEnabled = state.draft.selectedClipID != nil
        playPauseButton.setTitle(state.isPlaying ? "暂停" : "播放", for: .normal)

        if let message = state.errorMessage {
            let alert = UIAlertController(title: "提示", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "知道了", style: .default))
            present(alert, animated: true)
        }
    }

    @objc private func addLocalTapped() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.movie, UTType.video])
        picker.delegate = self
        present(picker, animated: true)
    }


    @objc private func splitTapped() {
        viewModel.splitSelectedClipAtPlayhead()
    }

    @objc private func deleteTapped() {
        viewModel.deleteSelectedClip()
    }

    @objc private func undoTapped() {
        viewModel.undo()
    }

    @objc private func redoTapped() {
        viewModel.redo()
    }

    @objc private func playPauseTapped() {
        viewModel.togglePlay()
    }

    @objc private func playheadChanged(_ sender: UISlider) {
        viewModel.movePlayhead(to: Double(sender.value))
    }
}

extension EditorViewController: TimelineViewDelegate {
    public func timelineView(_ timelineView: TimelineView, didSelectClip id: UUID) {
        viewModel.selectClip(id: id)
    }
}

extension EditorViewController: UIDocumentPickerDelegate {
    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        viewModel.appendLocalClip(url: url)
    }
}

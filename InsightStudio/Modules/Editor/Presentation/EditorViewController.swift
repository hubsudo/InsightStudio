import UIKit
import Combine

@MainActor
final class EditorViewController: UIViewController {
    private let viewModel: EditorViewModel
    private let workspaceViewModel: EditorWorkspaceViewModel
    private let exportService: any EditorExportService
    private let context: AppContext

    private let previewContainer = PreviewContainerView()
    private let timelineView = TimelineView()
    private let addButton = UIButton(type: .system)
    private let undoButton = UIButton(type: .system)
    private let redoButton = UIButton(type: .system)
    private let playPauseButton = UIButton(type: .system)
    private let summaryLabel = UILabel()
    private let previewSubtitleLabel = UILabel()
    private lazy var exportBarButtonItem = UIBarButtonItem(
        title: "导出",
        style: .prominent,
        target: self,
        action: #selector(exportTapped)
    )

    private var cancellables: Set<AnyCancellable> = []
    private var trimInteractionInitialRange: ClosedRange<Double>?
    private var isExporting = false {
        didSet {
            updateExportButtonState()
        }
    }

    init(
        viewModel: EditorViewModel,
        workspaceViewModel: EditorWorkspaceViewModel,
        exportService: any EditorExportService,
        context: AppContext,
    ) {
        self.viewModel = viewModel
        self.workspaceViewModel = workspaceViewModel
        self.exportService = exportService
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
        navigationItem.rightBarButtonItem = exportBarButtonItem
        addButton.setTitle("追加远程", for: .normal)
        undoButton.setTitle("Undo", for: .normal)
        redoButton.setTitle("Redo", for: .normal)
        playPauseButton.setTitle("Play/Pause", for: .normal)

        addButton.addTarget(self, action: #selector(addTapped), for: .touchUpInside)
        undoButton.addTarget(self, action: #selector(undoTapped), for: .touchUpInside)
        redoButton.addTarget(self, action: #selector(redoTapped), for: .touchUpInside)
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

        let stack = UIStackView(arrangedSubviews: [buttonStack, previewContainer, timelineView, summaryLabel, previewSubtitleLabel])
        stack.axis = .vertical
        stack.spacing = 12
        view.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        timelineView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            previewContainer.heightAnchor.constraint(equalTo: previewContainer.widthAnchor, multiplier: 9.0 / 16.0),
            timelineView.heightAnchor.constraint(equalToConstant: 128),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])

        timelineView.onPinchScaleChanged = { [weak self] scale, _, _ in
            guard let self else { return }
            let visibleWidth = self.timelineView.bounds.width
            guard visibleWidth > 0 else { return }
            let newOffset = self.viewModel.anchoredZoom(
                scaleDelta: scale,
                anchorX: visibleWidth / 2,
                visibleWidth: visibleWidth,
                currentContentOffsetX: self.timelineView.contentOffsetX
            )
            self.timelineView.setContentOffsetX(newOffset)
            self.viewModel.updateTimelineViewport(
                visibleWidth: visibleWidth,
                contentOffsetX: self.timelineView.contentOffsetX
            )
        }
        timelineView.onScrubOffsetChanged = { [weak self] contentOffsetX, state in
            guard let self else { return }
            let visibleWidth = self.timelineView.bounds.width
            guard visibleWidth > 0 else { return }
            self.viewModel.updateTimelineViewport(
                visibleWidth: visibleWidth,
                contentOffsetX: contentOffsetX
            )
            let playhead = self.viewModel.playheadSeconds(
                forCenteredContentOffset: contentOffsetX,
                visibleWidth: visibleWidth
            )
            let shouldSnap = state == .ended
            self.viewModel.movePlayhead(to: playhead, snapsToCandidates: shouldSnap)
        }
        timelineView.onTrimRangeChanged = { [weak self] range, handle, state in
            guard let self else { return }
            switch state {
            case .began:
                self.trimInteractionInitialRange = self.viewModel.currentState.draft.trimRange
                self.viewModel.setTrimRange(start: range.lowerBound, end: range.upperBound, recordHistory: false)
            case .changed:
                self.viewModel.setTrimRange(start: range.lowerBound, end: range.upperBound, recordHistory: false)
            case .ended:
                let snapped = self.snapTrimRangeToPlayhead(range: range, handle: handle)
                let originalRange = self.trimInteractionInitialRange ?? self.viewModel.currentState.draft.trimRange
                self.viewModel.commitTrimRange(
                    start: snapped.lowerBound,
                    end: snapped.upperBound,
                    originalRange: originalRange
                )
                self.trimInteractionInitialRange = nil
            case .cancelled, .failed:
                let originalRange = self.trimInteractionInitialRange ?? self.viewModel.currentState.draft.trimRange
                self.viewModel.setTrimRange(
                    start: originalRange.lowerBound,
                    end: originalRange.upperBound,
                    recordHistory: false
                )
                self.trimInteractionInitialRange = nil
            default:
                break
            }
        }
    }

    private func bind() {
        viewModel.$currentState
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self else { return }
                self.undoButton.isEnabled = state.canUndo
                self.redoButton.isEnabled = state.canRedo
                self.playPauseButton.setTitle(state.playbackUIState == .playing ? "Pause" : "Play", for: .normal)
                self.summaryLabel.text = "clips: \(state.draft.videoClipsCount) | total: \(String(format: "%.2f", state.draft.totalDuration))s | playhead: \(String(format: "%.2f", state.draft.playheadSeconds))s | trim: \(String(format: "%.2f", state.draft.trimStartSeconds))-\(String(format: "%.2f", state.draft.trimEndSeconds))s"
                self.previewSubtitleLabel.text = "zoom: \(Int(state.draft.zoomPixelsPerSecond)) px/s | playback: \(state.playbackUIState)"
                self.timelineView.pixelsPerSecond = state.draft.zoomPixelsPerSecond
                self.timelineView.totalDuration = state.draft.totalDuration
                self.timelineView.leftInset = CGFloat(self.viewModel.timelineInsets.left)
                self.timelineView.trimRange = state.draft.trimRange
                self.updateExportButtonState()
                self.syncTimelineToPlayheadIfPossible()
            }
            .store(in: &cancellables)

        viewModel.$timelineSnapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] snapshot in
                self?.timelineView.apply(snapshot: snapshot)
            }
            .store(in: &cancellables)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        syncTimelineToPlayheadIfPossible()
    }

    private func syncTimelineToPlayheadIfPossible() {
        let visibleWidth = timelineView.bounds.width
        guard visibleWidth > 0 else { return }
        timelineView.leadingPadding = viewModel.leadingViewportPadding(visibleWidth: visibleWidth)
        timelineView.contentWidth = viewModel.timelineContentWidth(visibleWidth: visibleWidth)
        let offset = viewModel.centeredContentOffsetX(visibleWidth: visibleWidth)
        timelineView.setContentOffsetX(offset)
        viewModel.updateTimelineViewport(
            visibleWidth: visibleWidth,
            contentOffsetX: offset
        )
    }

    private func snapTrimRangeToPlayhead(
        range: ClosedRange<Double>,
        handle: TimelineTrimHandle
    ) -> ClosedRange<Double> {
        let total = viewModel.currentState.draft.totalDuration
        guard total > 0 else { return 0...0 }

        let playhead = viewModel.currentState.draft.playheadSeconds
        let minimumDuration = min(0.1, total)
        var start = range.lowerBound
        var end = range.upperBound

        switch handle {
        case .left:
            start = playhead
            if end - start < minimumDuration {
                end = min(total, start + minimumDuration)
                start = max(0, end - minimumDuration)
            }
        case .right:
            end = playhead
            if end - start < minimumDuration {
                start = max(0, end - minimumDuration)
                end = min(total, start + minimumDuration)
            }
        }

        start = min(max(start, 0), max(0, total - minimumDuration))
        end = min(max(end, start + minimumDuration), total)
        return start...end
    }

    @objc private func addTapped() { presentRemoteClipPicker() }
    @objc private func undoTapped() { viewModel.undo() }
    @objc private func redoTapped() { viewModel.redo() }
    @objc private func playPauseTapped() { viewModel.togglePlayback() }
    @objc private func exportTapped() {
        guard isExporting == false else { return }
        guard viewModel.currentState.draft.hasVideoClips else {
            presentInfoAlert(title: "无法导出", message: "请先向时间轴追加至少一段视频素材")
            return
        }

        isExporting = true
        let draft = viewModel.currentState.draft

        Task { [weak self] in
            guard let self else { return }

            do {
                let clip = try await self.exportService.export(
                    draft: draft,
                    template: .libraryDefault
                )
                self.context.clipPipeline.send(.localClipCreated(clip))
                self.presentInfoAlert(
                    title: "导出完成",
                    message: "已导出到素材库，并标记为编辑结果，可继续复用"
                )
            } catch {
                self.presentInfoAlert(
                    title: "导出失败",
                    message: error.localizedDescription
                )
            }

            self.isExporting = false
        }
    }

    private func presentRemoteClipPicker() {
        workspaceViewModel.reload()
        let availableClips = workspaceViewModel.clips
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

    private func updateExportButtonState() {
        exportBarButtonItem.isEnabled = viewModel.currentState.draft.hasVideoClips && !isExporting
        exportBarButtonItem.title = isExporting ? "导出中..." : "导出"
    }

    private func presentInfoAlert(title: String, message: String) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        present(alert, animated: true)
    }
}

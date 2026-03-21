import UIKit

protocol TimelineViewDelegate: AnyObject {
    func timelineView(_ timelineView: TimelineView, didSelectClip id: UUID)
    func timelineView(_ timelineView: TimelineView, didRequestTrimSelectedClipUsing handle: TimelineTrimHandle)
}

final class TimelineView: UIView {
    weak var delegate: TimelineViewDelegate?

    var viewportScale: CGFloat = 1.0 {
        didSet { setNeedsLayout() }
    }

    private let timeMarkerStack = UIStackView()
    private let trackBackgroundView = UIView()
    private let clipsContainerView = UIView()
    private let playheadView = UIView()
    private let leftHandle = UIView()
    private let rightHandle = UIView()

    private var markerLabels: [UILabel] = []
    private var clipButtons: [UIButton] = []
    private var items: [TimelineLayoutItem] = []
    private var selectedClipID: UUID?
    private var playheadSeconds: Double = 0
    private var totalDuration: Double = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        attachGestures()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutTimeline()
    }

    func render(
        items: [TimelineLayoutItem],
        selectedClipID: UUID?,
        playheadSeconds: Double,
        totalDuration: Double
    ) {
        self.items = items
        self.selectedClipID = selectedClipID
        self.playheadSeconds = playheadSeconds
        self.totalDuration = totalDuration
        reloadClipViews()
        updateTimeMarkers()
        setNeedsLayout()
    }

    private func setupUI() {
        backgroundColor = .clear

        timeMarkerStack.axis = .horizontal
        timeMarkerStack.alignment = .fill
        timeMarkerStack.distribution = .fillEqually
        timeMarkerStack.spacing = 8
        timeMarkerStack.translatesAutoresizingMaskIntoConstraints = false

        markerLabels = (0..<5).map { _ in
            let label = UILabel()
            label.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
            label.textColor = .secondaryLabel
            label.textAlignment = .center
            timeMarkerStack.addArrangedSubview(label)
            return label
        }

        trackBackgroundView.backgroundColor = UIColor.secondarySystemFill
        trackBackgroundView.layer.cornerRadius = 14
        trackBackgroundView.translatesAutoresizingMaskIntoConstraints = false

        clipsContainerView.translatesAutoresizingMaskIntoConstraints = false

        playheadView.backgroundColor = .systemRed
        playheadView.layer.cornerRadius = 1
        playheadView.translatesAutoresizingMaskIntoConstraints = false

        [leftHandle, rightHandle].forEach {
            $0.backgroundColor = .systemBlue
            $0.layer.cornerRadius = 10
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        addSubview(timeMarkerStack)
        addSubview(trackBackgroundView)
        trackBackgroundView.addSubview(clipsContainerView)
        trackBackgroundView.addSubview(playheadView)
        trackBackgroundView.addSubview(leftHandle)
        trackBackgroundView.addSubview(rightHandle)

        NSLayoutConstraint.activate([
            timeMarkerStack.topAnchor.constraint(equalTo: topAnchor),
            timeMarkerStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            timeMarkerStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),

            trackBackgroundView.topAnchor.constraint(equalTo: timeMarkerStack.bottomAnchor, constant: 12),
            trackBackgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            trackBackgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            trackBackgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
            trackBackgroundView.heightAnchor.constraint(equalToConstant: 84),

            clipsContainerView.leadingAnchor.constraint(equalTo: trackBackgroundView.leadingAnchor, constant: 12),
            clipsContainerView.trailingAnchor.constraint(equalTo: trackBackgroundView.trailingAnchor, constant: -12),
            clipsContainerView.topAnchor.constraint(equalTo: trackBackgroundView.topAnchor, constant: 14),
            clipsContainerView.bottomAnchor.constraint(equalTo: trackBackgroundView.bottomAnchor, constant: -14),
        ])
    }

    private func attachGestures() {
        let leftPan = UIPanGestureRecognizer(target: self, action: #selector(handleLeftPan(_:)))
        let rightPan = UIPanGestureRecognizer(target: self, action: #selector(handleRightPan(_:)))
        leftHandle.addGestureRecognizer(leftPan)
        rightHandle.addGestureRecognizer(rightPan)
        leftHandle.isUserInteractionEnabled = true
        rightHandle.isUserInteractionEnabled = true
    }

    private func reloadClipViews() {
        clipButtons.forEach { $0.removeFromSuperview() }
        clipButtons = items.enumerated().map { index, item in
            let button = UIButton(type: .system)
            button.tag = index
            button.setTitle(item.title, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 12, weight: .semibold)
            button.setTitleColor(item.clipID == selectedClipID ? .white : .label, for: .normal)
            button.backgroundColor = item.clipID == selectedClipID ? .systemBlue : UIColor.systemGray5
            button.layer.cornerRadius = 10
            button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
            button.addTarget(self, action: #selector(clipTapped(_:)), for: .touchUpInside)
            clipsContainerView.addSubview(button)
            return button
        }
    }

    private func updateTimeMarkers() {
        let safeDuration = max(totalDuration, 0)
        for (index, label) in markerLabels.enumerated() {
            let ratio = CGFloat(index) / CGFloat(max(markerLabels.count - 1, 1))
            label.text = Self.formatTime(safeDuration * Double(ratio))
        }
    }

    private func layoutTimeline() {
        let trackBounds = clipsContainerView.bounds
        guard trackBounds.width > 0 else { return }

        let effectiveDuration = max(totalDuration / Double(max(viewportScale, 1)), 0.1)

        for (index, item) in items.enumerated() {
            let startRatio = CGFloat(item.startTime / effectiveDuration)
            let endRatio = CGFloat(item.endTime / effectiveDuration)
            let minX = trackBounds.width * max(0, min(startRatio, 1))
            let maxX = trackBounds.width * max(0, min(endRatio, 1))
            let width = max(maxX - minX, 44)
            clipButtons[index].frame = CGRect(x: minX, y: 0, width: min(width, trackBounds.width - minX), height: trackBounds.height)
        }

        let playheadRatio = CGFloat(min(max(playheadSeconds / effectiveDuration, 0), 1))
        let playheadX = clipsContainerView.frame.minX + clipsContainerView.bounds.width * playheadRatio
        playheadView.frame = CGRect(x: playheadX - 1, y: 8, width: 2, height: trackBackgroundView.bounds.height - 16)

        guard let selectedClipID,
              let selectedItem = items.first(where: { $0.clipID == selectedClipID }) else {
            leftHandle.isHidden = true
            rightHandle.isHidden = true
            return
        }

        leftHandle.isHidden = false
        rightHandle.isHidden = false

        let selectedStartRatio = CGFloat(selectedItem.startTime / effectiveDuration)
        let selectedEndRatio = CGFloat(selectedItem.endTime / effectiveDuration)
        let handleY = (trackBackgroundView.bounds.height - 44) / 2
        let handleSize = CGSize(width: 20, height: 44)

        leftHandle.frame = CGRect(
            origin: CGPoint(
                x: clipsContainerView.frame.minX + clipsContainerView.bounds.width * selectedStartRatio - handleSize.width / 2,
                y: handleY
            ),
            size: handleSize
        )
        rightHandle.frame = CGRect(
            origin: CGPoint(
                x: clipsContainerView.frame.minX + clipsContainerView.bounds.width * selectedEndRatio - handleSize.width / 2,
                y: handleY
            ),
            size: handleSize
        )
    }

    @objc private func clipTapped(_ sender: UIButton) {
        guard items.indices.contains(sender.tag) else { return }
        delegate?.timelineView(self, didSelectClip: items[sender.tag].clipID)
    }

    @objc private func handleLeftPan(_ gesture: UIPanGestureRecognizer) {
        gesture.setTranslation(.zero, in: self)
        if gesture.state == .began {
            delegate?.timelineView(self, didRequestTrimSelectedClipUsing: .left)
        }
    }

    @objc private func handleRightPan(_ gesture: UIPanGestureRecognizer) {
        gesture.setTranslation(.zero, in: self)
        if gesture.state == .began {
            delegate?.timelineView(self, didRequestTrimSelectedClipUsing: .right)
        }
    }

    private static func formatTime(_ seconds: Double) -> String {
        let total = Int(seconds.rounded(.down))
        let minutes = total / 60
        let remainder = total % 60
        return String(format: "%02d:%02d", minutes, remainder)
    }
}

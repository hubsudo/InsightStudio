import UIKit

enum TimelineTrimHandle {
    case left
    case right
}

final class TimelineView: UIView {
    var onPinchScaleChanged: ((CGFloat, CGPoint, UIGestureRecognizer.State) -> Void)?
    var onScrubOffsetChanged: ((CGFloat, UIGestureRecognizer.State) -> Void)?
    var onTrimRangeChanged: ((ClosedRange<Double>, TimelineTrimHandle, UIGestureRecognizer.State) -> Void)?

    let rulerView = TimelineRulerView()
    private let trackBackgroundView = UIView()
    let playheadView = UIView()
    private let trimSelectionView = UIView()
    private let leftTrimHandle = UIView()
    private let rightTrimHandle = UIView()

    var pixelsPerSecond: Double = 56 {
        didSet {
            rulerView.pixelsPerSecond = pixelsPerSecond
            setNeedsLayout()
        }
    }
    var totalDuration: Double = 0 {
        didSet {
            rulerView.totalDuration = totalDuration
            setNeedsLayout()
        }
    }
    var leftInset: CGFloat = 16 {
        didSet {
            rulerView.leftInset = leftInset
            setNeedsLayout()
        }
    }
    var leadingPadding: CGFloat = 0 {
        didSet {
            rulerView.leadingPadding = leadingPadding
            setNeedsLayout()
        }
    }
    var trimRange: ClosedRange<Double>? {
        didSet { setNeedsLayout() }
    }
    var contentWidth: CGFloat = 0 {
        didSet { setContentOffsetX(contentOffsetX, notify: false) }
    }
    private(set) var contentOffsetX: CGFloat = 0

    private var scrubStartOffsetX: CGFloat = 0
    private var trimEditStartRange: ClosedRange<Double>?
    private var trimEditHandle: TimelineTrimHandle?

    private lazy var pinchGesture: UIPinchGestureRecognizer = {
        let gesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        gesture.delegate = self
        return gesture
    }()

    private lazy var scrubGesture: UIPanGestureRecognizer = {
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(handleScrub(_:)))
        gesture.maximumNumberOfTouches = 1
        gesture.delegate = self
        return gesture
    }()

    private lazy var leftTrimHandlePan: UIPanGestureRecognizer = {
        UIPanGestureRecognizer(target: self, action: #selector(handleLeftTrimPan(_:)))
    }()

    private lazy var rightTrimHandlePan: UIPanGestureRecognizer = {
        UIPanGestureRecognizer(target: self, action: #selector(handleRightTrimPan(_:)))
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .systemBackground
        rulerView.backgroundColor = .secondarySystemBackground
        trackBackgroundView.backgroundColor = .quaternarySystemFill

        addGestureRecognizer(scrubGesture)
        addGestureRecognizer(pinchGesture)

        addSubview(rulerView)
        addSubview(trackBackgroundView)
        addSubview(trimSelectionView)
        addSubview(playheadView)

        rulerView.translatesAutoresizingMaskIntoConstraints = false
        trackBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        playheadView.translatesAutoresizingMaskIntoConstraints = false
        playheadView.backgroundColor = .systemRed
        playheadView.layer.cornerRadius = 1

        trimSelectionView.layer.borderWidth = 2
        trimSelectionView.layer.borderColor = UIColor.systemBlue.cgColor
        trimSelectionView.layer.cornerRadius = 8
        trimSelectionView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.08)

        leftTrimHandle.backgroundColor = .systemBlue
        rightTrimHandle.backgroundColor = .systemBlue
        leftTrimHandle.layer.cornerRadius = 2
        rightTrimHandle.layer.cornerRadius = 2
        leftTrimHandle.addGestureRecognizer(leftTrimHandlePan)
        rightTrimHandle.addGestureRecognizer(rightTrimHandlePan)
        trimSelectionView.addSubview(leftTrimHandle)
        trimSelectionView.addSubview(rightTrimHandle)

        NSLayoutConstraint.activate([
            rulerView.topAnchor.constraint(equalTo: topAnchor),
            rulerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            rulerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            rulerView.heightAnchor.constraint(equalToConstant: 24),

            trackBackgroundView.topAnchor.constraint(equalTo: rulerView.bottomAnchor),
            trackBackgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            trackBackgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            trackBackgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),

            playheadView.widthAnchor.constraint(equalToConstant: 2),
            playheadView.topAnchor.constraint(equalTo: rulerView.bottomAnchor),
            playheadView.bottomAnchor.constraint(equalTo: bottomAnchor),
            playheadView.centerXAnchor.constraint(equalTo: centerXAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let clamped = clampedContentOffset(contentOffsetX)
        if abs(clamped - contentOffsetX) > 0.001 {
            contentOffsetX = clamped
            rulerView.contentOffsetX = clamped
        }
        layoutTrimSelection()
    }

    func setContentOffsetX(_ proposed: CGFloat, notify: Bool = false, state: UIGestureRecognizer.State = .changed) {
        let clamped = clampedContentOffset(proposed)
        if abs(clamped - contentOffsetX) <= 0.001 {
            if notify {
                onScrubOffsetChanged?(clamped, state)
            }
            return
        }
        contentOffsetX = clamped
        rulerView.contentOffsetX = clamped
        setNeedsLayout()
        if notify {
            onScrubOffsetChanged?(clamped, state)
        }
    }

    @objc
    private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        let location = gesture.location(in: self)
        onPinchScaleChanged?(gesture.scale, location, gesture.state)
        gesture.scale = 1
    }

    @objc
    private func handleScrub(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            scrubStartOffsetX = contentOffsetX
            onScrubOffsetChanged?(contentOffsetX, .began)
        case .changed:
            let translationX = gesture.translation(in: self).x
            let proposedOffset = scrubStartOffsetX - translationX
            setContentOffsetX(proposedOffset, notify: true, state: .changed)
        case .ended:
            let translationX = gesture.translation(in: self).x
            let proposedOffset = scrubStartOffsetX - translationX
            setContentOffsetX(proposedOffset, notify: true, state: .ended)
        case .cancelled, .failed:
            onScrubOffsetChanged?(contentOffsetX, .cancelled)
        default:
            break
        }
    }

    @objc
    private func handleLeftTrimPan(_ gesture: UIPanGestureRecognizer) {
        handleTrimPan(gesture, handle: .left)
    }

    @objc
    private func handleRightTrimPan(_ gesture: UIPanGestureRecognizer) {
        handleTrimPan(gesture, handle: .right)
    }

    private func handleTrimPan(_ gesture: UIPanGestureRecognizer, handle: TimelineTrimHandle) {
        guard totalDuration > 0 else { return }
        let minimumDuration = min(0.1, totalDuration)
        switch gesture.state {
        case .began:
            trimEditHandle = handle
            let initialRange = trimRange ?? (0...minimumDuration)
            trimEditStartRange = initialRange
            onTrimRangeChanged?(initialRange, handle, .began)
        case .changed, .ended, .cancelled, .failed:
            guard trimEditHandle == handle, let startRange = trimEditStartRange else { return }
            let deltaSeconds = Double(gesture.translation(in: self).x) / max(pixelsPerSecond, 1)
            var start = startRange.lowerBound
            var end = startRange.upperBound
            switch handle {
            case .left:
                start = min(max(startRange.lowerBound + deltaSeconds, 0), end - minimumDuration)
            case .right:
                end = max(min(startRange.upperBound + deltaSeconds, totalDuration), start + minimumDuration)
            }
            let updatedRange = start...end
            trimRange = updatedRange
            onTrimRangeChanged?(updatedRange, handle, gesture.state)

            if gesture.state == .ended || gesture.state == .cancelled || gesture.state == .failed {
                trimEditHandle = nil
                trimEditStartRange = nil
            }
        default:
            break
        }
    }

    private func clampedContentOffset(_ proposed: CGFloat) -> CGFloat {
        let maxOffset = max(0, contentWidth - bounds.width)
        return min(max(proposed, 0), maxOffset)
    }

    private func layoutTrimSelection() {
        guard
            totalDuration > 0,
            let trimRange
        else {
            trimSelectionView.isHidden = true
            return
        }

        let startX = x(for: trimRange.lowerBound)
        let endX = x(for: trimRange.upperBound)
        let minimumVisualWidth: CGFloat = 36
        var width = max(endX - startX, minimumVisualWidth)
        var originX = startX
        if endX - startX < minimumVisualWidth {
            let center = (startX + endX) / 2
            originX = center - (minimumVisualWidth / 2)
            width = minimumVisualWidth
        }

        let top = rulerView.frame.maxY + 8
        let height = max(30, bounds.height - top - 8)
        trimSelectionView.frame = CGRect(x: originX, y: top, width: width, height: height)
        trimSelectionView.isHidden = false

        let handleWidth: CGFloat = min(20, width / 2)
        leftTrimHandle.frame = CGRect(x: 0, y: 0, width: handleWidth, height: height)
        rightTrimHandle.frame = CGRect(x: width - handleWidth, y: 0, width: handleWidth, height: height)
    }

    private func x(for timelineSeconds: Double) -> CGFloat {
        leadingPadding + leftInset + CGFloat(timelineSeconds * pixelsPerSecond) - contentOffsetX
    }
}

extension TimelineView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard gestureRecognizer === scrubGesture else { return true }
        if touch.view?.isDescendant(of: leftTrimHandle) == true { return false }
        if touch.view?.isDescendant(of: rightTrimHandle) == true { return false }
        return true
    }
}

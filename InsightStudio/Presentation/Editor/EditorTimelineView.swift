import UIKit

protocol EditorTimelineViewDelegate: AnyObject {
    func timelineView(_ view: EditorTimelineView, didChange startRatio: CGFloat, endRatio: CGFloat)
}

final class EditorTimelineView: UIView {
    weak var delegate: EditorTimelineViewDelegate?

    private let trackView = UIView()
    private let selectionView = UIView()
    private let leftHandle = UIView()
    private let rightHandle = UIView()

    private var startRatio: CGFloat = 0.0
    private var endRatio: CGFloat = 0.35

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        attachGestures()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutTimeline()
    }

    private func setupUI() {
        trackView.backgroundColor = .systemGray5
        trackView.layer.cornerRadius = 8
        selectionView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.25)
        selectionView.layer.borderColor = UIColor.systemBlue.cgColor
        selectionView.layer.borderWidth = 2
        selectionView.layer.cornerRadius = 8

        [trackView, selectionView, leftHandle, rightHandle].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = true
            addSubview($0)
        }

        leftHandle.backgroundColor = .systemBlue
        rightHandle.backgroundColor = .systemBlue
        leftHandle.layer.cornerRadius = 3
        rightHandle.layer.cornerRadius = 3
    }

    private func attachGestures() {
        leftHandle.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handleLeftPan(_:))))
        rightHandle.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handleRightPan(_:))))
        leftHandle.isUserInteractionEnabled = true
        rightHandle.isUserInteractionEnabled = true
    }

    private func layoutTimeline() {
        let inset: CGFloat = 16
        let height: CGFloat = 56
        trackView.frame = CGRect(x: inset, y: 16, width: bounds.width - inset * 2, height: height)

        let x1 = trackView.frame.minX + trackView.bounds.width * startRatio
        let x2 = trackView.frame.minX + trackView.bounds.width * endRatio
        selectionView.frame = CGRect(x: x1, y: trackView.frame.minY, width: max(24, x2 - x1), height: height)
        leftHandle.frame = CGRect(x: selectionView.frame.minX - 6, y: trackView.frame.minY - 4, width: 12, height: height + 8)
        rightHandle.frame = CGRect(x: selectionView.frame.maxX - 6, y: trackView.frame.minY - 4, width: 12, height: height + 8)
    }

    @objc private func handleLeftPan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self)
        gesture.setTranslation(.zero, in: self)
        let delta = translation.x / max(trackView.bounds.width, 1)
        startRatio = max(0, min(startRatio + delta, endRatio - 0.05))
        layoutTimeline()
        delegate?.timelineView(self, didChange: startRatio, endRatio: endRatio)
    }

    @objc private func handleRightPan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self)
        gesture.setTranslation(.zero, in: self)
        let delta = translation.x / max(trackView.bounds.width, 1)
        endRatio = min(1, max(endRatio + delta, startRatio + 0.05))
        layoutTimeline()
        delegate?.timelineView(self, didChange: startRatio, endRatio: endRatio)
    }

    func setSelection(startRatio: CGFloat, endRatio: CGFloat) {
        self.startRatio = max(0, min(startRatio, 1))
        self.endRatio = max(self.startRatio + 0.05, min(endRatio, 1))
        setNeedsLayout()
    }
}

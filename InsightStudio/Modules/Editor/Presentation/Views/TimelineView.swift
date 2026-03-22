import UIKit

final class TimelineView: UIView {
    var onPinchScaleChanged: ((CGFloat, CGPoint, UIGestureRecognizer.State) -> Void)?
    var onScrolled: ((CGFloat) -> Void)?

    let rulerView = TimelineRulerView()
    let scrollView = UIScrollView()
    let collectionView: UICollectionView
    let playheadView = UIView()

    private var playheadLeadingConstraint: NSLayoutConstraint!

    private lazy var pinchGesture: UIPinchGestureRecognizer = {
        UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
    }()

    override init(frame: CGRect) {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 8
        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: frame)

        backgroundColor = .systemBackground
        rulerView.backgroundColor = .secondarySystemBackground
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.alwaysBounceHorizontal = true
        scrollView.delegate = self
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.isScrollEnabled = false
        collectionView.register(TimelineClipCell.self, forCellWithReuseIdentifier: TimelineClipCell.reuseIdentifier)

        addGestureRecognizer(pinchGesture)

        addSubview(rulerView)
        addSubview(scrollView)
        scrollView.addSubview(collectionView)
        addSubview(playheadView)

        rulerView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        playheadView.translatesAutoresizingMaskIntoConstraints = false
        playheadView.backgroundColor = .systemRed

        playheadLeadingConstraint = playheadView.leadingAnchor.constraint(equalTo: leadingAnchor)

        NSLayoutConstraint.activate([
            rulerView.topAnchor.constraint(equalTo: topAnchor),
            rulerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            rulerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            rulerView.heightAnchor.constraint(equalToConstant: 24),

            scrollView.topAnchor.constraint(equalTo: rulerView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            collectionView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            collectionView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),

            playheadView.widthAnchor.constraint(equalToConstant: 2),
            playheadView.topAnchor.constraint(equalTo: rulerView.bottomAnchor),
            playheadView.bottomAnchor.constraint(equalTo: bottomAnchor),
            playheadLeadingConstraint
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updatePlayheadX(_ x: CGFloat) {
        playheadLeadingConstraint.constant = x - scrollView.contentOffset.x
        layoutIfNeeded()
    }

    @objc
    private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        let location = gesture.location(in: scrollView)
        onPinchScaleChanged?(gesture.scale, location, gesture.state)
        gesture.scale = 1
    }
}

extension TimelineView: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        onScrolled?(scrollView.contentOffset.x)
    }
}

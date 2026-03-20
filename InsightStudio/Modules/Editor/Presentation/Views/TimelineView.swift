import UIKit

public protocol TimelineViewDelegate: AnyObject {
    func timelineView(_ timelineView: TimelineView, didSelectClip id: UUID)
}

final class TimelineClipCell: UICollectionViewCell {
    static let reuseID = "TimelineClipCell"

    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.layer.cornerRadius = 10
        contentView.layer.borderWidth = 1
        contentView.layer.borderColor = UIColor.separator.cgColor
        contentView.backgroundColor = .secondarySystemBackground

        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String, isSelected: Bool) {
        titleLabel.text = title
        contentView.backgroundColor = isSelected ? UIColor.systemBlue.withAlphaComponent(0.2) : .secondarySystemBackground
        contentView.layer.borderColor = isSelected ? UIColor.systemBlue.cgColor : UIColor.separator.cgColor
        contentView.layer.borderWidth = isSelected ? 2 : 1
    }
}

public final class TimelineView: UIView {
    public weak var delegate: TimelineViewDelegate?

    private var items: [TimelineLayoutItem] = []
    private var selectedClipID: UUID?

    private let collectionView: UICollectionView
    private let playheadView = UIView()

    public override init(frame: CGRect) {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 8
        layout.minimumInteritemSpacing = 0
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: frame)

        backgroundColor = .systemBackground

        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = true
        collectionView.register(TimelineClipCell.self, forCellWithReuseIdentifier: TimelineClipCell.reuseID)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false

        playheadView.backgroundColor = .systemRed
        playheadView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(collectionView)
        addSubview(playheadView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),

            playheadView.centerXAnchor.constraint(equalTo: centerXAnchor),
            playheadView.topAnchor.constraint(equalTo: topAnchor),
            playheadView.bottomAnchor.constraint(equalTo: bottomAnchor),
            playheadView.widthAnchor.constraint(equalToConstant: 2)
        ])
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func render(items: [TimelineLayoutItem], selectedClipID: UUID?) {
        self.items = items
        self.selectedClipID = selectedClipID
        collectionView.reloadData()
    }
}

extension TimelineView: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let item = items[indexPath.item]
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TimelineClipCell.reuseID, for: indexPath) as! TimelineClipCell
        cell.configure(title: item.title, isSelected: item.clipID == selectedClipID)
        return cell
    }

    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate?.timelineView(self, didSelectClip: items[indexPath.item].clipID)
    }

    public func collectionView(_ collectionView: UICollectionView,
                               layout collectionViewLayout: UICollectionViewLayout,
                               sizeForItemAt indexPath: IndexPath) -> CGSize {
        let frame = items[indexPath.item].frame
        return CGSize(width: frame.width, height: frame.height)
    }
}

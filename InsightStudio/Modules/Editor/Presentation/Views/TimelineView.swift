import UIKit

protocol TimelineViewDelegate: AnyObject {
    func timelineView(_ timelineView: TimelineView, didSelectClip id: UUID)
    func timelineView(_ timelineView: TimelineView, didMoveClipFrom sourceIndex: Int, to destinationIndex: Int)
}

final class TimelineView: UIView {
    weak var delegate: TimelineViewDelegate?

    private var items: [TimelineLayoutItem] = []
    private var selectedClipID: UUID?

    private let collectionView: UICollectionView
    private let playheadView = UIView()

    override init(frame: CGRect) {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 8
        layout.minimumInteritemSpacing = 0
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: frame)

        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = true
        collectionView.dragInteractionEnabled = true
        collectionView.register(TimelineClipCell.self, forCellWithReuseIdentifier: TimelineClipCell.reuseID)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.dragDelegate = self
        collectionView.dropDelegate = self
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

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func render(items: [TimelineLayoutItem], selectedClipID: UUID?) {
        self.items = items
        self.selectedClipID = selectedClipID
        collectionView.reloadData()
    }
}

extension TimelineView: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { items.count }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let item = items[indexPath.item]
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TimelineClipCell.reuseID, for: indexPath) as! TimelineClipCell
        cell.configure(title: item.title, isSelected: item.clipID == selectedClipID)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate?.timelineView(self, didSelectClip: items[indexPath.item].clipID)
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let frame = items[indexPath.item].frame
        return CGSize(width: frame.width, height: frame.height)
    }
}

extension TimelineView: UICollectionViewDragDelegate, UICollectionViewDropDelegate {
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        let provider = NSItemProvider(object: NSString(string: items[indexPath.item].clipID.uuidString))
        let item = UIDragItem(itemProvider: provider)
        item.localObject = indexPath
        return [item]
    }

    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        guard let destinationIndexPath = coordinator.destinationIndexPath,
              let item = coordinator.items.first,
              let sourceIndexPath = item.sourceIndexPath else { return }

        coordinator.drop(item.dragItem, toItemAt: destinationIndexPath)
        delegate?.timelineView(self, didMoveClipFrom: sourceIndexPath.item, to: destinationIndexPath.item)
    }

    func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool {
        session.localDragSession != nil
    }

    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
    }
}

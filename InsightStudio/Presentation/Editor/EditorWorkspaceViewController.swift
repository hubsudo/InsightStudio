import Combine
import UIKit

final class EditorWorkspaceViewController: UIViewController {
    var onSelectClip: ((ImportedClip) -> Void)?
    var clipFilter: ((ImportedClip) -> Bool)?
    var screenTitle: String?

    private let viewModel: EditorWorkspaceViewModel
    private let imagePipeline: ImagePipeline
    private var cancellables: Set<AnyCancellable> = []

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 150, height: 140)
        layout.minimumLineSpacing = 12
        layout.minimumInteritemSpacing = 12
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemBackground
        view.register(ImportedClipCell.self, forCellWithReuseIdentifier: ImportedClipCell.reuseID)
        view.dataSource = self
        view.delegate = self
        return view
    }()

    init(viewModel: EditorWorkspaceViewModel, imagePipeline: ImagePipeline) {
        self.viewModel = viewModel
        self.imagePipeline = imagePipeline
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = screenTitle ?? "Editor"
        view.backgroundColor = .systemBackground
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            collectionView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        viewModel.$clips
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.collectionView.reloadData()
            }
            .store(in: &cancellables)
    }

    private var displayedClips: [ImportedClip] {
        viewModel.clips.filter { clip in
            clipFilter?(clip) ?? true
        }
    }
}

extension EditorWorkspaceViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        displayedClips.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ImportedClipCell.reuseID, for: indexPath) as? ImportedClipCell else {
            return UICollectionViewCell()
        }
        cell.configure(with: displayedClips[indexPath.item], pipeline: imagePipeline)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        onSelectClip?(displayedClips[indexPath.item])
    }
}

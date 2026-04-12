import Combine
import UIKit

final class EditorWorkspaceViewController: UIViewController {
    var onSelectClip: ((ImportedClip) -> Void)?
    var clipFilter: ((ImportedClip) -> Bool)?
    var screenTitle: String?

    private let viewModel: EditorWorkspaceViewModel
    private let context: AppContext
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

    init(
        viewModel: EditorWorkspaceViewModel,
        context: AppContext,
    ) {
        self.viewModel = viewModel
        self.context = context
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = screenTitle ?? "Editor"
        view.backgroundColor = .systemBackground
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "trash"),
            style: .plain,
            target: self,
            action: #selector(didTapDeleteAll)
        )
        
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
    
    @objc
    private func didTapDeleteAll() {
        guard viewModel.clips.isEmpty == false else { return }
        let alert = UIAlertController(
            title: "删除全部素材",
            message: "此操作会清空素材库记录，是否继续？",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "删除", style: .destructive, handler: { [weak self] _ in
            guard let self else { return }
            self.context.clipPipeline.send(.deleteAllRequested)
        }))
        
        present(alert, animated: true)
    }
}

extension EditorWorkspaceViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        displayedClips.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ImportedClipCell.reuseID, for: indexPath) as? ImportedClipCell else {
            return UICollectionViewCell()
        }
        cell.configure(with: displayedClips[indexPath.item], pipeline: context.imagePipeline)
        cell.onTapDelete = { [weak self] clip in
            guard let self else { return }
            
            let alert = UIAlertController(
                title: "删除素材",
                message: "确认删除这条素材吗？",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "取消", style: .cancel))
            alert.addAction(UIAlertAction(title: "删除", style: .destructive) { _ in
                self.context.clipPipeline.send(.deleteRequested(clip))
            })
            self.present(alert, animated: true)
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        onSelectClip?(displayedClips[indexPath.item])
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = collectionView.bounds.width - 24
        return CGSize(width: width, height: 96)
    }
}

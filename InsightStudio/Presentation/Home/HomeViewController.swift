import UIKit

final class HomeViewController: UIViewController {
    var onSelectVideo: ((VideoSummary) -> Void)?

    private let viewModel: HomeViewModel
    private let imagePipeline: ImagePipeline

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let searchField: UITextField = {
        let field = UITextField()
        field.placeholder = "输入搜索关键词"
        field.borderStyle = .roundedRect
        field.text = AppEnvironment.defaultSearchKeyword
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()

    private let searchButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("搜索", for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    init(viewModel: HomeViewModel, imagePipeline: ImagePipeline) {
        self.viewModel = viewModel
        self.imagePipeline = imagePipeline
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "InsightStudio"
        view.backgroundColor = .systemBackground
        setupUI()
        loadVideos()
    }

    private func setupUI() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(HomeVideoCell.self, forCellReuseIdentifier: HomeVideoCell.reuseID)

        searchButton.addTarget(self, action: #selector(onTapSearch), for: .touchUpInside)

        view.addSubview(searchField)
        view.addSubview(searchButton)
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            searchField.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            searchField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: searchButton.leadingAnchor, constant: -8),

            searchButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            searchButton.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),
            searchButton.widthAnchor.constraint(equalToConstant: 60),

            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 12),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    @objc private func onTapSearch() {
        loadVideos()
    }

    private func loadVideos() {
        let keyword = searchField.text?.isEmpty == false ? searchField.text! : AppEnvironment.defaultSearchKeyword
        Task { [weak self] in
            guard let self else { return }
            do {
                try await viewModel.loadVideos(keyword: keyword)
                tableView.reloadData()
            } catch {
                let alert = UIAlertController(title: "加载失败", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
            }
        }
    }
}

extension HomeViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.videos.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: HomeVideoCell.reuseID, for: indexPath) as? HomeVideoCell else {
            return UITableViewCell()
        }
        cell.configure(with: viewModel.videos[indexPath.row], pipeline: imagePipeline)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        onSelectVideo?(viewModel.videos[indexPath.row])
    }
}

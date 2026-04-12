import UIKit

final class ImportedClipCell: UICollectionViewCell {
    static let reuseID = "ImportedClipCell"
    
    var onTapDelete: ((ImportedClip) -> Void)?
    private var currentClip: ImportedClip?
    private var currentThumbnailURL: String?

    private let thumbnailView: AsyncImageView = {
        let view = AsyncImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.layer.cornerRadius = 10
        view.backgroundColor = .tertiarySystemFill
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .label
        label.numberOfLines = 2
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }()

    private let stateLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.numberOfLines = 1
        return label
    }()

    private let progressView: UIProgressView = {
        let view = UIProgressView(progressViewStyle: .default)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let deleteButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "trash"), for: .normal)
        button.tintColor = .secondaryLabel
        return button
    }()

    private lazy var textStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [titleLabel, stateLabel, progressView])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 8
        return stack
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.backgroundColor = .secondarySystemBackground
        contentView.layer.cornerRadius = 14
        contentView.layer.borderWidth = 1
        contentView.layer.borderColor = UIColor.separator.cgColor
        contentView.clipsToBounds = true

        deleteButton.addTarget(self, action: #selector(didTapDelete), for: .touchUpInside)

        [thumbnailView,
         textStack,
         deleteButton
        ].forEach {
            contentView.addSubview($0)
        }

        NSLayoutConstraint.activate([
            thumbnailView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            thumbnailView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            thumbnailView.widthAnchor.constraint(equalToConstant: 120),
            thumbnailView.heightAnchor.constraint(equalToConstant: 68),

            deleteButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            deleteButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            deleteButton.widthAnchor.constraint(equalToConstant: 28),
            deleteButton.heightAnchor.constraint(equalToConstant: 28),

            textStack.leadingAnchor.constraint(equalTo: thumbnailView.trailingAnchor, constant: 12),
            textStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            textStack.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -8),
            textStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -12),

            progressView.heightAnchor.constraint(equalToConstant: 3)
        ])

        titleLabel.setContentHuggingPriority(.defaultHigh, for: .vertical)
        stateLabel.setContentHuggingPriority(.required, for: .vertical)
        progressView.setContentHuggingPriority(.required, for: .vertical)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with clip: ImportedClip, pipeline: ImagePipeline) {
        currentClip = clip

        titleLabel.text = clip.title
        updateDownloadUI(with: clip)

        if currentThumbnailURL != clip.thumbnailURL {
            currentThumbnailURL = clip.thumbnailURL
            thumbnailView.setImage(urlString: clip.thumbnailURL, pipeline: pipeline)
        }
    }

    func updateDownloadUI(with clip: ImportedClip) {
        progressView.progress = Float(clip.downloadProgress)
        
        switch clip.resolvedDownloadState {
        case .idle:
            stateLabel.text = "等待下载"
            progressView.isHidden = false
        case .downloading:
            stateLabel.text = "下载中 \(Int(clip.downloadProgress * 100))%"
            progressView.isHidden = false
        case .ready:
            stateLabel.text = "已下载，可本地播放"
            progressView.isHidden = true
        case .failed:
            stateLabel.text = clip.lastErrorMessage ?? "下载失败"
            progressView.isHidden = true
        case .deleted:
            stateLabel.text = "已删除"
            progressView.isHidden = true
        }
    }
    
    @objc
    private func didTapDelete() {
        guard let currentClip else { return }
        onTapDelete?(currentClip)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        currentClip = nil
        onTapDelete = nil
        currentThumbnailURL = nil
        
        titleLabel.text = nil
        stateLabel.text = nil
        progressView.progress = 0
        progressView.isHidden = false
    }
}

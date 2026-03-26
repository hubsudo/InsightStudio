import UIKit

final class ImportedClipCell: UICollectionViewCell {
    static let reuseID = "ImportedClipCell"
    
    var onTapDelete: ((ImportedClip) -> Void)?
    private var currentClip: ImportedClip?

    private let imageView: AsyncImageView = {
        let view = AsyncImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.layer.cornerRadius = 12
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.numberOfLines = 2
        return label
    }()
    
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let stateLabel = UILabel()
    private let deleteButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.layer.cornerRadius = 12
        contentView.layer.borderWidth = 1
        contentView.layer.borderColor = UIColor.separator.cgColor
        contentView.backgroundColor = .secondarySystemBackground

        deleteButton.setImage(UIImage(systemName: "trash"), for: .normal)
        deleteButton.addTarget(self, action: #selector(didTapDelete), for: .touchUpInside)

        [imageView,
         titleLabel,
         progressView,
         stateLabel,
         deleteButton
        ].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.heightAnchor.constraint(equalToConstant: 100),
            
            deleteButton.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 8),
            deleteButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            deleteButton.widthAnchor.constraint(equalToConstant: 28),
            deleteButton.heightAnchor.constraint(equalToConstant: 28),

            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -8),
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 6),
            
            progressView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            progressView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            progressView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            
            stateLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 8),
            stateLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            stateLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            stateLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -8),
        ])
        
        stateLabel.font = .systemFont(ofSize: 13)
        stateLabel.textColor = .secondaryLabel
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with clip: ImportedClip, pipeline: ImagePipeline) {
        titleLabel.text = clip.title
        imageView.setImage(urlString: clip.thumbnailURL, pipeline: pipeline)
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
    }
}

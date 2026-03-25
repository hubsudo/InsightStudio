import UIKit

final class ImportedClipCell: UICollectionViewCell {
    static let reuseID = "ImportedClipCell"

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

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(imageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(progressView)
        contentView.addSubview(stateLabel)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.heightAnchor.constraint(equalToConstant: 100),

            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 6),
            
            progressView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            progressView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            progressView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            
            stateLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 8),
            stateLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            stateLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            stateLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -8)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with clip: ImportedClip, pipeline: ImagePipeline) {
        titleLabel.text = clip.title
        imageView.setImage(urlString: clip.thumbnailURL, pipeline: pipeline)
        progressView.progress = Float(clip.downloadProgress)
        
        switch clip.downloadState {
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
        }
    }
}

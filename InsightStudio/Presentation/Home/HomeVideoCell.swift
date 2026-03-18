import UIKit

final class HomeVideoCell: UITableViewCell {
    static let reuseID = "HomeVideoCell"

    private let thumbImageView: AsyncImageView = {
        let view = AsyncImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.layer.cornerRadius = 8
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with video: VideoSummary, pipeline: ImagePipeline) {
        titleLabel.text = video.title
        subtitleLabel.text = video.channelTitle
        thumbImageView.setImage(urlString: video.thumbnailURL, pipeline: pipeline)
    }

    private func setupUI() {
        contentView.addSubview(thumbImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            thumbImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            thumbImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            thumbImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            thumbImageView.widthAnchor.constraint(equalToConstant: 120),
            thumbImageView.heightAnchor.constraint(equalToConstant: 72),

            titleLabel.leadingAnchor.constraint(equalTo: thumbImageView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            titleLabel.topAnchor.constraint(equalTo: thumbImageView.topAnchor),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8)
        ])
    }
}

import UIKit

final class TimelineClipCell: UIView {
    static let reuseIdentifier = "TimelineClipCell"

    private let titleLabel = UILabel()
    private let backgroundView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false

        backgroundView.backgroundColor = .systemBlue.withAlphaComponent(0.15)
        backgroundView.layer.cornerRadius = 10
        backgroundView.layer.borderWidth = 1
        backgroundView.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.3).cgColor

        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 2
        addSubview(backgroundView)
        backgroundView.addSubview(titleLabel)
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor, constant: -10),
            titleLabel.centerYAnchor.constraint(equalTo: backgroundView.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with item: TimelineLayoutItemModel) {
        titleLabel.text = item.title
    }
}

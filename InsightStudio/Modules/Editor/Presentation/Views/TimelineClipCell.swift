import UIKit

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

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(title: String, isSelected: Bool) {
        titleLabel.text = title
        contentView.backgroundColor = isSelected ? UIColor.systemBlue.withAlphaComponent(0.2) : .secondarySystemBackground
        contentView.layer.borderColor = isSelected ? UIColor.systemBlue.cgColor : UIColor.separator.cgColor
        contentView.layer.borderWidth = isSelected ? 2 : 1
    }
}

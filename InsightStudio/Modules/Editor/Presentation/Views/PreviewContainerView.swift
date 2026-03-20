import UIKit
import AVFoundation

public final class PreviewContainerView: UIView {
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let playerContainer = UIView()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 12

        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        subtitleLabel.font = .systemFont(ofSize: 14)
        subtitleLabel.numberOfLines = 0

        playerContainer.backgroundColor = .black
        playerContainer.layer.cornerRadius = 10
        playerContainer.clipsToBounds = true

        let stack = UIStackView(arrangedSubviews: [playerContainer, titleLabel, subtitleLabel])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            playerContainer.heightAnchor.constraint(equalToConstant: 180)
        ])
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func attach(playerLayer: AVPlayerLayer) {
        playerLayer.frame = playerContainer.bounds
        if playerLayer.superlayer !== playerContainer.layer {
            playerContainer.layer.sublayers?.removeAll()
            playerContainer.layer.addSublayer(playerLayer)
        }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        playerContainer.layer.sublayers?.forEach { $0.frame = playerContainer.bounds }
    }

    public func render(snapshot: PreviewSnapshot) {
        titleLabel.text = snapshot.clipName
        subtitleLabel.text = "timeline: \(String(format: "%.2f", snapshot.timelineTime))s\nclip local: \(String(format: "%.2f", snapshot.localClipTime))s"
    }
}

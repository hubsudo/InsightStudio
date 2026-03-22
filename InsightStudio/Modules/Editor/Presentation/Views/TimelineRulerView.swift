import UIKit

final class TimelineRulerView: UIView {
    var pixelsPerSecond: Double = 56 { didSet { setNeedsDisplay() } }
    var totalDuration: Double = 0 { didSet { setNeedsDisplay() } }
    var leftInset: CGFloat = 16 { didSet { setNeedsDisplay() } }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.clear(rect)
        UIColor.secondarySystemBackground.setFill()
        ctx.fill(rect)

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: UIColor.secondaryLabel,
            .paragraphStyle: paragraph
        ]

        let maxSecond = Int(ceil(totalDuration))
        for second in 0...maxSecond {
            let x = leftInset + CGFloat(Double(second) * pixelsPerSecond)
            let tickHeight: CGFloat = second % 5 == 0 ? 16 : 10
            ctx.setStrokeColor(UIColor.tertiaryLabel.cgColor)
            ctx.setLineWidth(1)
            ctx.move(to: CGPoint(x: x, y: rect.height))
            ctx.addLine(to: CGPoint(x: x, y: rect.height - tickHeight))
            ctx.strokePath()

            guard second < maxSecond else { continue }
            let text = NSString(string: "\(second)s")
            text.draw(in: CGRect(x: x - 14, y: 0, width: 28, height: 12), withAttributes: attrs)
        }
    }
}

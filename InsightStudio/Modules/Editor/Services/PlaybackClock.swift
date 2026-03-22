import Foundation

@MainActor
final class PlaybackClock {
    private var timer: Timer?
    var onTick: ((Double) -> Void)?

    init() {}

    func start(from initial: Double, duration: Double) {
        stop()
        var current = initial
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] timer in
            current += 1.0 / 30.0
            if current >= duration {
                current = duration
                timer.invalidate()
            }
            self?.onTick?(current)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}

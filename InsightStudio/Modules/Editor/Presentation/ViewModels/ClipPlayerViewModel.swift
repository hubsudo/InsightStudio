//
//  ClipPlayerViewModel.swift
//  InsightStudio
//
//  Created by chenrunhuan on 2026/3/25.
//

import Foundation
import AVFoundation
import Combine

@MainActor
final class ClipPlayerViewModel: ObservableObject {
    let player: AVPlayer
    let playerLayer: AVPlayerLayer

    var onPlaybackTimeChange: ((Double) -> Void)?
    var onPlaybackStateChange: ((Bool) -> Void)?

    private(set) var isPlaying: Bool = false
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?

    var onItemDidPlayToEnd: (() -> Void)?

    init(player: AVPlayer = AVPlayer()) {
        self.player = player
        self.playerLayer = AVPlayerLayer(player: player)
        self.playerLayer.videoGravity = .resizeAspect
        self.player.automaticallyWaitsToMinimizeStalling = false

        bindPlayerObservers()
    }

    deinit {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
    }

    private func bindPlayerObservers() {
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1.0 / 30.0, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self, self.player.rate > 0 else { return }
            // Main actor-isolated property 'onPlaybackTimeChange' can not be referenced from a Sendable closure
            Task { @MainActor in
                guard self.player.rate > 0 else { return }
                self.onPlaybackTimeChange?(max(0, time.seconds))
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Main actor-isolated property 'onItemDidPlayToEnd' can not be referenced from a Sendable closure
            guard let self else { return }
            
            Task { @MainActor in
                self.onItemDidPlayToEnd?()
            }
        }
    }

    func replaceCurrentItem(with item: AVPlayerItem?) {
        player.pause()
        player.replaceCurrentItem(with: item)
    }

    func play() {
        player.playImmediately(atRate: 1.0)
        isPlaying = true
        onPlaybackStateChange?(true)
    }

    func pause() {
        player.pause()
        isPlaying = false
        onPlaybackStateChange?(false)
    }

    func seek(to time: CMTime, completion: @escaping (Bool) -> Void) {
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero, completionHandler: completion)
    }

    func clear() {
        pause()
        replaceCurrentItem(with: nil)
        onPlaybackTimeChange?(0)
    }
}

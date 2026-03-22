//
//  PreviewContainerView.swift
//  InsightStudio
//
//  Created by chenrunhuan on 2026/3/22.
//

import UIKit
import AVFoundation

final class PreviewContainerView: UIView {
    private(set) var playerLayer = AVPlayerLayer()

    func attach(playerLayer: AVPlayerLayer) {
        self.playerLayer.removeFromSuperlayer()
        self.playerLayer = playerLayer
        layer.addSublayer(playerLayer)
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}


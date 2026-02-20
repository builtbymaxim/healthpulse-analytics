//
//  LoopingVideoBackground.swift
//  HealthPulse
//
//  Full-screen looping video background. Uses AVPlayerLayer as the backing
//  layer of the UIView so it always fills the view without manual frame sync.
//

import SwiftUI
import AVFoundation

struct LoopingVideoBackground: UIViewRepresentable {
    let videoName: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        guard let url = Bundle.main.url(forResource: videoName, withExtension: "mp4") else {
            return view
        }
        let item = AVPlayerItem(url: url)
        let player = AVQueuePlayer(playerItem: item)
        player.isMuted = true
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        context.coordinator.player = player
        context.coordinator.looper = AVPlayerLooper(player: player, templateItem: item)
        player.play()
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {}

    // MARK: - PlayerView
    // Backing layer is AVPlayerLayer — it auto-fills view bounds on layout.
    final class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
        override func layoutSubviews() {
            super.layoutSubviews()
            playerLayer.frame = bounds
        }
    }

    // MARK: - Coordinator
    class Coordinator {
        var player: AVQueuePlayer?
        var looper: AVPlayerLooper?
        deinit { player?.pause() }
    }
}

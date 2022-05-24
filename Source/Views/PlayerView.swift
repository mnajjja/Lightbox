import UIKit
import AVKit
import AVFoundation

class PlayerView: UIView {
    
    override static var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
    
     var playerLayer: AVPlayerLayer {
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        return layer as! AVPlayerLayer
    }
    
    weak var player: AVPlayer? {
        get { return playerLayer.player }
        set { playerLayer.player = newValue }
    }
}

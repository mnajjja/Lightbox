//
//  PlaybackSlider.swift
//  Lightbox-iOS
//
//  Created by Alexandr on 11.06.2022.
//

import UIKit

open class PlaybackSlider: UISlider {
    open override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        return true
    }
    
    open override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
       var bounds: CGRect = self.bounds
       bounds = bounds.insetBy(dx: -10, dy: -15)
       return bounds.contains(point)
    }
}

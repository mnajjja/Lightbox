//
//  PlaybackSlider.swift
//  Lightbox-iOS
//
//  Created by Alexandr on 11.06.2022.
//

import UIKit

open class PlaybackSlider: UISlider {
    open override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let widthOfThumb: Float = Float(self.thumbImage(for: .focused)?.size.width ?? 20)
        let pointTappedX: Float = Float(touch.location(in: self).x)
        let widthOfSlider: Float = Float(self.frame.size.width)
        var newValue = pointTappedX / widthOfSlider * self.maximumValue
        
        /// Move Forward
        if newValue > self.value {
            newValue += (widthOfThumb / 2) / widthOfSlider * self.maximumValue
        }
        /// Move Back
        else if newValue < self.value{
            newValue -= (widthOfThumb / 2) / widthOfSlider * self.maximumValue
        }
        
        self.setValue(newValue, animated: true)
        
        return true
    }
    
    open override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
       var bounds: CGRect = self.bounds
       bounds = bounds.insetBy(dx: -10, dy: -15)
       return bounds.contains(point)
    }
}

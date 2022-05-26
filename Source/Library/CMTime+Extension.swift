//
//  CMTime+Extension.swift
//  Lightbox-iOS
//
//  Created by Aleksandr on 26.05.2022.
//  Copyright © 2022 Hyper Interaktiv AS. All rights reserved.
//

import AVKit

extension CMTime {
    var stringTime: String? {
        let currentTime = self.seconds
        let timeInSec = abs(Int(currentTime))
        let timeStr = NSString(format: "%02d:%02d", timeInSec/60, timeInSec%60) as String
        
        return timeStr
    }
}

//
//  Date+Extensions.swift
//  Lightbox-iOS
//
//  Created by Aleksandr on 25.05.2022.
//  Copyright © 2022 Hyper Interaktiv AS. All rights reserved.
//

import Foundation

internal extension Date {
    func toString(format: String = "yyyy_MM_dd_HH_mm_ss_SSS") -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.dateFormat = format
        return formatter.string(from: self)
    }
}

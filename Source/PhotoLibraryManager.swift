//
//  PhotoLibraryManager.swift
//  Lightbox-iOS
//
//  Created by Aleksandr on 25.05.2022.
//  Copyright © 2022 Hyper Interaktiv AS. All rights reserved.
//

import Photos
import UIKit
import Foundation

enum PhotoLibraryManager {
    
    static func saveVideo(from url: URL, completionHandler: ((Bool, Error?) -> Void)? = nil) {
        let fileName = url.lastPathComponent
        DispatchQueue.global(qos: .background).async {
            if let urlData = NSData(contentsOf: url) {
                let galleryPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0];
                let filePath="\(galleryPath)/\(fileName)"
                DispatchQueue.main.async {
                    urlData.write(toFile: filePath, atomically: true)
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL:
                                                                                URL(fileURLWithPath: filePath))
                    }, completionHandler: completionHandler)
                }
            } else {
                completionHandler?(false, nil)
            }
        }
    }
    
    static func saveImage(from url: URL, completionHandler: ((Bool, Error?) -> Void)? = nil) {
        DispatchQueue.global(qos: .background).async {
            let fileName = url.lastPathComponent
            if let urlData = NSData(contentsOf: url) {
                let galleryPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0];
                let filePath="\(galleryPath)/\(fileName)"
                DispatchQueue.main.async {
                    urlData.write(toFile: filePath, atomically: true)
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL:
                                                                                URL(fileURLWithPath: filePath))
                    }, completionHandler: completionHandler)
                }
            } else {
                completionHandler?(false, nil)
            }
        }
    }
}

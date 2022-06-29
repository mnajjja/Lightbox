//
//  UIViewController+Extension.swift
//  Lightbox-iOS
//
//  Created by Aleksandr on 16.06.2022.
//

import Foundation
import UIKit

extension UIViewController {
    
    func goToSettings() {
        let alert = UIAlertController(title: "Allow access to your photos",
                                      message: "This lets you save photos and videos.\nGo to your settings and tap \"Photos\".", preferredStyle: UIAlertController.Style.alert)
        
        alert.addAction(UIAlertAction(title: "Settings", style: UIAlertAction.Style.default, handler: { [weak self] _ in
            guard self != nil else { return }
            if let appSettings = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(appSettings) {
                UIApplication.shared.open(appSettings)
            }
            
        }))
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
        
        self.present(alert, animated: true, completion: nil)
    }
}

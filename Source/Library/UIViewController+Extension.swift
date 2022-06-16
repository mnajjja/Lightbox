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
        let alert = UIAlertController(title: "Photo library access denied",
                                      message: "Go to Settings to update permissions", preferredStyle: UIAlertController.Style.alert)
        
        alert.addAction(UIAlertAction(title: "Go to Settings", style: UIAlertAction.Style.default, handler: { [weak self] _ in
            guard self != nil else { return }
            if let appSettings = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(appSettings) {
                UIApplication.shared.open(appSettings)
            }
            
        }))
        alert.addAction(UIAlertAction(title: "Dismiss", style: UIAlertAction.Style.default, handler: nil))
        
        self.present(alert, animated: true, completion: nil)
    }
}

//
//  MessageView.swift
//  Lightbox-iOS
//
//  Created by Aleksandr on 27.05.2022.
//  Copyright © 2022 Hyper Interaktiv AS. All rights reserved.
//

import Foundation
import UIKit

open class MessageView: UIView {
    
    var text: String? {
        didSet {
            textLabel.text = text
        }
    }
    
    open fileprivate(set) lazy var imageView: UIImageView = { [unowned self] in
        let view = UIImageView(frame: CGRect.zero)
        view.frame.size = CGSize(width: 24, height: 24)
        view.image = AssetManager.image("save")
        view.contentMode = .scaleAspectFit

        return view
    }()
    
    open fileprivate(set) lazy var textLabel: UILabel = { [unowned self] in
        let label = UILabel(frame: CGRect.zero)
        label.text = text
        label.textAlignment = .left
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .white
        
        return label
    }()
    
    
    // MARK: - Initializers
    
    public init() {
        super.init(frame: CGRect.zero)
        
        backgroundColor = UIColor.darkGray
        layer.masksToBounds = true
        layer.cornerRadius = 10
        
        [imageView, textLabel].forEach { addSubview($0) }
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open override func layoutSubviews() {
      super.layoutSubviews()

        imageView.frame.origin = CGPoint(
            x: 20,
            y: (frame.height - imageView.frame.height)/2
        )
        
        textLabel.frame = CGRect(
            x: imageView.frame.maxX + 10,
            y: 0,
            width: frame.width - (imageView.frame.maxX + 10),
            height: frame.height
        )
    }
}

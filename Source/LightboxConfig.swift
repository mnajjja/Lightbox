import UIKit
import AVKit
import AVFoundation
import SDWebImage

public class LightboxConfig {
    /// Whether to show status bar while Lightbox is presented
    public static var hideStatusBar = true
    
    /// How to load image onto SDAnimatedImageView
    public static var loadImage: (SDAnimatedImageView, URL, ((UIImage?) -> Void)?) -> Void = { (imageView, imageURL, completion) in
        
        // Use SDWebImage by default
        imageView.sd_setImage(with: imageURL) { image, error, _ , _ in
            completion?(image)
        }
    }
    
    /// Indicator is used to show while image is being fetched
    public static var makeLoadingIndicator: () -> UIView = {
        return LoadingIndicator()
    }
    
    /// Number of images to preload.
    ///
    /// 0 - Preload all images (default).
    public static var preload = 0
    
    /// Number of images left to rich the end
    ///
    /// 0 - Never preload
    public static var itemsToEnd = 0
    
    public struct PageIndicator {
        public static var enabled = false
        public static var separatorColor = UIColor(hex: "3D4757")
        
        public static var textAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor(hex: "899AB8"),
            .paragraphStyle: {
                var style = NSMutableParagraphStyle()
                style.alignment = .center
                return style
            }()
        ]
    }
    
    public struct CloseButton {
        public static var enabled = true
        public static var size = CGSize(width: 50, height: 18)
        public static var text = NSLocalizedString("Back", comment: "")
        public static var image = AssetManager.image("back")
        
        public static var textAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 14),
            .foregroundColor: UIColor.white.withAlphaComponent(0.7),
            .paragraphStyle: {
                var style = NSMutableParagraphStyle()
                style.alignment = .left
                return style
            }()
        ]
    }
    
    public struct DeleteButton {
        public static var enabled = false
        public static var size: CGSize?
        public static var text = NSLocalizedString("Delete", comment: "")
        public static var image: UIImage?
        
        public static var textAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 16),
            .foregroundColor: UIColor(hex: "FA2F5B"),
            .paragraphStyle: {
                var style = NSMutableParagraphStyle()
                style.alignment = .center
                return style
            }()
        ]
    }
    
    public struct SaveButton {
        public static var enabled = true
        public static var size = CGSize(width: 24, height: 24)
        public static var text = NSLocalizedString("", comment: "")
        public static var image = AssetManager.image("save")
        
        public static var textAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 14),
            .foregroundColor: UIColor.white,
            .paragraphStyle: {
                var style = NSMutableParagraphStyle()
                style.alignment = .center
                return style
            }()
        ]
    }
    
    public struct MuteButton {
        public static var enabled = true
        public static var size = CGSize(width: 24, height: 24)
        public static var text = NSLocalizedString("", comment: "")
    }
        
    
    public struct TitleLabel {
        public static var enabled = true
        public static var textColor = UIColor.white
        public static var textAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16, weight: .semibold),
            .foregroundColor: UIColor.white
        ]
    }
    
    public struct InfoLabel {
        public static var enabled = true
        public static var textColor = UIColor.white
        public static var ellipsisText = NSLocalizedString("Show more", comment: "")
        public static var ellipsisColor = UIColor(hex: "899AB9")
        
        public static var textAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.white
        ]
    }
    
    public struct TimeLabel {
        public static var enabled = true
        public static var textColor = UIColor.white
        public static var font = UIFont.systemFont(ofSize: 11)
    }
    
    public struct Zoom {
        public static var minimumScale: CGFloat = 1.0
        public static var maximumScale: CGFloat = 3.0
    }
    
    public struct Footer {
        public static var backgroundColor = UIColor.clear
    }
    
    public struct Header {
        public static var backgroundColor = UIColor(hex: "26252A").withAlphaComponent(0.7)
    }
}

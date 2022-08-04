import UIKit
import SDWebImage

open class LightboxImage {
    
    open fileprivate(set) var image: UIImage?
    open fileprivate(set) var imageURL: URL?
    open fileprivate(set) var videoURL: URL?
    open fileprivate(set) var imageClosure: (() -> UIImage)?
    open var title: String?
    open var description: String?
    open var canZoom: Bool = true
    open var canShowBottomOptions = true
    open var startVideoMuted = false
    open var overlay: UIView?

    var hasVideoContent: Bool {
        return videoURL != nil
    }
    
    var hasImageContent: Bool {
        return (imageURL != nil) || (image != nil)
    }
    
    // MARK: - Initialization

    public init(videoURL: URL?) {
        self.videoURL = videoURL
    }
    
    public init(videoURL: URL? = nil, imageURL: URL? = nil, image: UIImage? = nil) {
        self.videoURL = videoURL
        self.imageURL = imageURL
        self.image = image
    }
    
    public init(imageURL: URL? = nil, title: String? = nil, description: String? = nil, image: UIImage? = nil) {
        self.image = image
        self.imageURL = imageURL
        self.title = title
        self.description = description
    }

    open func addImageTo(_ imageView: SDAnimatedImageView, completion: ((UIImage?) -> Void)? = nil) {
        if let image = image {
            imageView.image = image
            completion?(image)
        } else if let imageURL = imageURL {
            LightboxConfig.loadImage(imageView, imageURL, completion)
        } else if let imageClosure = imageClosure {
            let img = imageClosure()
            imageView.image = img
            completion?(img)
        } else {
            imageView.image = nil
            completion?(nil)
        }
    }
    
    open func updateVideoThumb(url: URL?) {
        imageURL = url
    }
    
    open func updateVideoUrl(newUrl: URL?) {
        videoURL = newUrl
    }
}

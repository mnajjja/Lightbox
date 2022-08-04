import SDWebImage
import UIKit

protocol PageViewDelegate: AnyObject {

  func pageViewDidZoom(_ pageView: PageView)
  func remoteImageDidLoad(_ image: UIImage?, imageView: SDAnimatedImageView)
  func pageViewDidTouch(_ pageView: PageView)
  func playerDidPlayToEndTime(_ pageView: PageView)
}

class PageView: UIScrollView {
    
    lazy var imageView: SDAnimatedImageView = {
        let imageView = SDAnimatedImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.isUserInteractionEnabled = true
        
        return imageView
    }()
    
    lazy var playerView: PlayerView = {
        let playerView = PlayerView()
        playerView.contentMode = .scaleAspectFit
        playerView.clipsToBounds = true
        playerView.isUserInteractionEnabled = true
        
        return playerView
    }()
    
    lazy var playerThumbnailView: UIImageView = {
        let thumbnailView = UIImageView()
        thumbnailView.contentMode = .scaleAspectFit
        thumbnailView.clipsToBounds = true
        thumbnailView.backgroundColor = .clear
        
        return thumbnailView
    }()

    lazy var loadingIndicator: UIView = LightboxConfig.makeLoadingIndicator()
    
    var image: LightboxImage

    var contentFrame = CGRect.zero
    weak var pageViewDelegate: PageViewDelegate?

    var hasZoomed: Bool {
        return zoomScale != 1.0
    }
    var didLayoutOverlay = false
    // MARK: - Initializers
    
    init(image: LightboxImage) {
        self.image = image
        super.init(frame: CGRect.zero)
        
        configure()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Configuration
    
    func configure() {
        configureMediaView()
        delegate = self
        isMultipleTouchEnabled = true
        minimumZoomScale = LightboxConfig.Zoom.minimumScale
        maximumZoomScale = LightboxConfig.Zoom.maximumScale
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        
        let doubleTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(scrollViewDoubleTapped(_:)))
        doubleTapRecognizer.numberOfTapsRequired = 2
        doubleTapRecognizer.numberOfTouchesRequired = 1
        addGestureRecognizer(doubleTapRecognizer)
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(viewTapped(_:)))
        addGestureRecognizer(tapRecognizer)
        
        tapRecognizer.require(toFail: doubleTapRecognizer)
    }
    
    func configureMediaView() {
        if self.image.hasVideoContent, !subviews.contains(playerView) {
            if subviews.contains(imageView) { imageView.removeFromSuperview() }
            playerView.addSubview(playerThumbnailView)
            addSubview(playerView)
        } else if (self.image.hasImageContent && !self.image.hasVideoContent), !subviews.contains(imageView) {
            if subviews.contains(playerView) { playerView.removeFromSuperview() }
            addSubview(imageView)
            fetchImage()
        }
        
        if !subviews.contains(loadingIndicator) { addSubview(loadingIndicator) }
        loadingIndicator.layer.zPosition = 1

        centerMediaViews()
        if let overlay = image.overlay {
            addSubview(overlay)
            overlay.frame = frame
        }
    }

    // MARK: - Update
    func update(with image: LightboxImage) {
        self.image = image
        configureMediaView()
    }

    
    // MARK: - Fetch
    private func fetchImage() {
        loadingIndicator.alpha = 1
        self.image.addImageTo(imageView) { [weak self] image in
            guard let self = self else {
                return
            }
            
            self.isUserInteractionEnabled = true
            self.configureImageView()
            self.pageViewDelegate?.remoteImageDidLoad(image, imageView: self.imageView)
            
            UIView.animate(withDuration: 0.4) {
                self.loadingIndicator.alpha = 0
            }
        }
    }
    
    // MARK: - Recognizers
    
    @objc func scrollViewDoubleTapped(_ recognizer: UITapGestureRecognizer) {
        guard image.canZoom else { return }
        var tappedView: UIView!
        
        if self.image.hasVideoContent, subviews.contains(playerView) {
            tappedView = playerView
        } else {
            tappedView = imageView
        }
                
        let pointInView = recognizer.location(in: tappedView)
        let newZoomScale = zoomScale > minimumZoomScale
        ? minimumZoomScale
        : maximumZoomScale
        
        let width = contentFrame.size.width / newZoomScale
        let height = contentFrame.size.height / newZoomScale
        let x = pointInView.x - (width / 2.0)
        let y = pointInView.y - (height / 2.0)
        
        let rectToZoomTo = CGRect(x: x, y: y, width: width, height: height)
        
        zoom(to: rectToZoomTo, animated: true)
    }
    
    @objc func viewTapped(_ recognizer: UITapGestureRecognizer) {
        pageViewDelegate?.pageViewDidTouch(self)
    }
    
    // MARK: - Layout
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if !didLayoutOverlay {
            didLayoutOverlay = true
            image.overlay?.frame = CGRect(x: 0, y: 0, width: frame.width, height: frame.height)
        }
        let center = image.hasVideoContent ? playerView.center : imageView.center
        loadingIndicator.center = center
    }
    
    func configureImageView() {
        guard let image = imageView.image else {
            centerView(imageView)
            return
        }
        
        let imageViewSize = imageView.frame.size
        let imageSize = image.size
        let realImageViewSize: CGSize
        
        if imageSize.width / imageSize.height > imageViewSize.width / imageViewSize.height {
            realImageViewSize = CGSize(
                width: imageViewSize.width,
                height: imageViewSize.width / imageSize.width * imageSize.height)
        } else {
            realImageViewSize = CGSize(
                width: imageViewSize.height / imageSize.height * imageSize.width,
                height: imageViewSize.height)
        }
        
        imageView.frame = CGRect(origin: CGPoint.zero, size: realImageViewSize)
        
        centerView(imageView)
    }
    
    private func centerView(_ view: UIView) {
        let boundsSize = contentFrame.size
        var imageViewFrame = view.frame
        
        if imageViewFrame.size.width < boundsSize.width {
            imageViewFrame.origin.x = (boundsSize.width - imageViewFrame.size.width) / 2.0
        } else {
            imageViewFrame.origin.x = 0.0
        }
        
        if imageViewFrame.size.height < boundsSize.height {
            imageViewFrame.origin.y = (boundsSize.height - imageViewFrame.size.height) / 2.0
        } else {
            imageViewFrame.origin.y = 0.0
        }
        
        view.frame = imageViewFrame
    }
    
    private func centerMediaViews() {
        if subviews.contains(playerView) {
            centerView(playerView)
            centerView(playerThumbnailView)
        }
        
        if subviews.contains(imageView) { centerView(imageView) }
    }
}

// MARK: - LayoutConfigurable

extension PageView: LayoutConfigurable {

  @objc func configureLayout() {
    contentFrame = frame
    contentSize = frame.size
    imageView.frame = frame
    playerView.frame = frame
    playerThumbnailView.frame = frame
    zoomScale = minimumZoomScale

    configureMediaView()
  }
}

// MARK: - UIScrollViewDelegate

extension PageView: UIScrollViewDelegate {

  func viewForZooming(in scrollView: UIScrollView) -> UIView? {
      guard image.canZoom else { return nil }
      if self.image.hasVideoContent, subviews.contains(playerView) {
          return playerView
      }
      
    return imageView
  }

  func scrollViewDidZoom(_ scrollView: UIScrollView) {
    centerMediaViews()
    pageViewDelegate?.pageViewDidZoom(self)
      if self.zoomScale == self.minimumZoomScale {
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
              self.image.overlay?.isHidden = false
          }
      } else {
          self.image.overlay?.isHidden = true
      }
  }
}

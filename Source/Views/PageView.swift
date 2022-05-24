import SDWebImage
import UIKit
import AVKit

protocol PageViewDelegate: AnyObject {

  func pageViewDidZoom(_ pageView: PageView)
  func remoteImageDidLoad(_ image: UIImage?, imageView: SDAnimatedImageView)
  func pageView(_ pageView: PageView, didTouchPlayButton videoURL: URL)
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
    
    lazy var playButton: UIButton = {
        let button = UIButton(type: .custom)
        button.frame.size = CGSize(width: 60, height: 60)
        var buttonImage = AssetManager.image("lightbox_play")
        
        // Note by Elvis Nuñez on Mon 22 Jun 08:06
        // When using SPM you might find that assets are note included. This is a workaround to provide default assets
        // under iOS 13 so using SPM can work without problems.
        if #available(iOS 13.0, *) {
            if buttonImage == nil {
                buttonImage = UIImage(systemName: "play.circle.fill")
            }
        }
        
        button.setBackgroundImage(buttonImage, for: UIControl.State())
        button.addTarget(self, action: #selector(playButtonTouched(_:)), for: .touchUpInside)
        button.tintColor = .white
        
        button.layer.shadowOffset = CGSize(width: 1, height: 1)
        button.layer.shadowColor = UIColor.gray.cgColor
        button.layer.masksToBounds = false
        button.layer.shadowOpacity = 0.8
        
        return button
    }()
    
    lazy var loadingIndicator: UIView = LightboxConfig.makeLoadingIndicator()
    
    var image: LightboxImage
    
    private var avPlayer : AVPlayer!
    private var asset: AVAsset!
    private var playerItem: AVPlayerItem!
    private var playerItemContext = 0
    private var playerStatus: AVPlayerItem.Status!
    private let requiredAssetKeys = ["playable", "hasProtectedContent"]

    var contentFrame = CGRect.zero
    weak var pageViewDelegate: PageViewDelegate?

    var hasZoomed: Bool {
        return zoomScale != 1.0
    }
    
    // MARK: - Initializers
    
    init(image: LightboxImage) {
        self.image = image
        super.init(frame: CGRect.zero)
        
        configure()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        removeObservers()
    }

    // MARK: - Configuration
    
    func configure() {
        configureMediaView()
        
        addSubview(loadingIndicator)
        
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
            addSubview(playerView)
            addObservers()
        } else if self.image.imageURL != nil, !subviews.contains(imageView) {
            if subviews.contains(playerView) { playerView.removeFromSuperview() }
            if subviews.contains(playButton) { playButton.removeFromSuperview() }
            addSubview(imageView)
            fetchImage()
        }
        
        centerMediaViews()
    }
    
    func updatePlayButton() {
      if self.image.videoURL != nil && !subviews.contains(playButton) {
        addSubview(playButton)
      } else if self.image.videoURL == nil && subviews.contains(playButton) {
        playButton.removeFromSuperview()
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
        
        let center = image.hasVideoContent ? playerView.center : imageView.center

        loadingIndicator.center = center
        playButton.center = center
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
        if subviews.contains(playerView) { centerView(playerView) }
        if subviews.contains(imageView) { centerView(imageView) }
    }
    
    // MARK: - Observers

    private func addObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(pauseVideoForBackgrounding), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(playVideoForForegrounding), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    private func removeObservers() {
        playerItem?.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status))
        NotificationCenter.default.removeObserver(self)
    }

    @objc
    private func pauseVideoForBackgrounding() {
        avPlayer?.pause()
    }
    
    @objc
    private func playVideoForForegrounding() {
        avPlayer?.play()
    }
    
    
    // MARK: - Action
    
    @objc func playButtonTouched(_ button: UIButton) {
        guard let videoUrl = image.videoURL else { return }
        pageViewDelegate?.pageView(self, didTouchPlayButton: videoUrl)
    }
    
    // MARK: - Player
    
    func configurePlayer(_ url: URL) {
        asset = AVAsset(url: url)
        playerItem = AVPlayerItem(asset: asset,
                                  automaticallyLoadedAssetKeys: requiredAssetKeys)
        
        playerItem?.addObserver(self,
                                   forKeyPath: #keyPath(AVPlayerItem.status),
                                   options: [.old, .new],
                                   context: &playerItemContext)
            
        avPlayer = AVPlayer(playerItem: playerItem)
        
        avPlayer?.isMuted = false
        avPlayer?.play()
        playerView.playerLayer.player = avPlayer
        loadingIndicator.alpha = 1
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: self.avPlayer.currentItem, queue: nil) { [weak self] _ in
            guard let self = self else { return }
            self.avPlayer?.seek(to: CMTime.zero)
            self.pageViewDelegate?.playerDidPlayToEndTime(self)
        }
    }
    
    
    func killPlayer() {
        avPlayer?.pause()
        avPlayer = nil
    }
    
    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey : Any]?,
                               context: UnsafeMutableRawPointer?) {

        // Only handle observations for the playerItemContext
        guard context == &playerItemContext else {
            super.observeValue(forKeyPath: keyPath,
                               of: object,
                               change: change,
                               context: context)
            return
        }

        if keyPath == #keyPath(AVPlayerItem.status) {
            let status: AVPlayerItem.Status
            if let statusNumber = change?[.newKey] as? NSNumber {
                status = AVPlayerItem.Status(rawValue: statusNumber.intValue)!
            } else {
                status = .unknown
            }
            playerStatus = status
            UIView.animate(withDuration: 0.4) { self.loadingIndicator.alpha = 0 }
        }
    }
}

// MARK: - LayoutConfigurable

extension PageView: LayoutConfigurable {

  @objc func configureLayout() {
    contentFrame = frame
    contentSize = frame.size
    imageView.frame = frame
    playerView.frame = frame
    zoomScale = minimumZoomScale

    configureMediaView()
  }
}

// MARK: - UIScrollViewDelegate

extension PageView: UIScrollViewDelegate {

  func viewForZooming(in scrollView: UIScrollView) -> UIView? {
      if self.image.hasVideoContent, subviews.contains(playerView) {
          return playerView
      }
      
    return imageView
  }

  func scrollViewDidZoom(_ scrollView: UIScrollView) {
    centerMediaViews()
    pageViewDelegate?.pageViewDidZoom(self)
  }
}

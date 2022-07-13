import AVKit
import Foundation
import Photos
import SDWebImage
import UIKit

public protocol LightboxControllerPageDelegate: AnyObject {
    
    func lightboxController(_ controller: LightboxController, didMoveToPage page: Int)
}

public protocol LightboxControllerDismissalDelegate: AnyObject {
    
    func lightboxControllerWillDismiss(_ controller: LightboxController)
}

public protocol LightboxControllerTouchDelegate: AnyObject {
    
    func lightboxController(_ controller: LightboxController, didTouch image: LightboxImage, at index: Int)
}

public protocol LightboxSaveDelegate: AnyObject {
    
    func lightboxControllerSaveMedia(_ controller: LightboxController?, from url: URL?, result: (Bool, Error?))
}

public protocol LightboxPreloadDelegate: AnyObject {
    
    func lightboxControllerWillReachRightEnd(_ controller: LightboxController?)
    func lightboxControllerWillReachLeftEnd(_ controller: LightboxController?)
    func lightboxControllerUpdated(_ controller: LightboxController?)
}

open class LightboxController: UIViewController {
    
    // MARK: - Internal views
    
    lazy var scrollView: UIScrollView = { [unowned self] in
        let scrollView = UIScrollView()
        scrollView.isPagingEnabled = false
        scrollView.delegate = self
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.decelerationRate = UIScrollView.DecelerationRate.fast
        
        return scrollView
    }()
    
    lazy var overlayTapGestureRecognizer: UITapGestureRecognizer = { [unowned self] in
        let gesture = UITapGestureRecognizer()
        gesture.addTarget(self, action: #selector(overlayViewDidTap(_:)))
        
        return gesture
    }()
    
    lazy var effectView: UIVisualEffectView = {
        let effect = UIBlurEffect(style: .dark)
        let view = UIVisualEffectView(effect: effect)
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        return view
    }()
    
    lazy var backgroundView: SDAnimatedImageView = {
        let view = SDAnimatedImageView()
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        return view
    }()
    
    // MARK: - Public views
    
    
    
    open fileprivate(set) lazy var messageView: MessageView = { [unowned self] in
        let view = MessageView()
        view.alpha = 0
        
        return view
    }()
    
    open fileprivate(set) lazy var headerView: HeaderView = { [unowned self] in
        let view = HeaderView()
        view.backgroundColor = LightboxConfig.Header.backgroundColor
        view.delegate = self
        
        
        return view
    }()
    
    open fileprivate(set) lazy var footerView: FooterView = { [unowned self] in
        let view = FooterView()
        view.backgroundColor = LightboxConfig.Footer.backgroundColor
        view.muteButton.isSelected = LightboxConfig.Footer.mutePlayer
        view.delegate = self
        view.playerContainerView.isHidden = true
        view.imageContainerView.isHidden = false
        
        return view
    }()
    
    open fileprivate(set) lazy var overlayView: UIView = { [unowned self] in
        let view = UIView(frame: CGRect.zero)
        let gradient = CAGradientLayer()
        let colors = [UIColor(hex: "090909").withAlphaComponent(0), UIColor(hex: "040404")]
        
        view.addGradientLayer(colors)
        view.alpha = 0
        
        return view
    }()
    
    open fileprivate(set) lazy var videoThumbnailView: UIImageView = { [unowned self] in
        let view = UIImageView(frame: CGRect.zero)
        view.backgroundColor = .clear
        view.layer.cornerRadius = 8
        view.clipsToBounds = true
        view.contentMode = .scaleAspectFit
        
        return view
    }()
    
    open fileprivate(set) lazy var progressLoadingView: UILabel = {
        let progress = UILabel()
        progress.text = ""
        progress.textAlignment = .center
        progress.frame.origin = CGPoint(x: 20, y: 105)
        progress.frame.size.height = 26
        progress.textColor = .white
        progress.font = UIFont.systemFont(ofSize: 12)
        progress.backgroundColor = .gray.withAlphaComponent(0.75)
        progress.clipsToBounds = true
        progress.layer.cornerRadius = 13
        progress.isHidden = true
        
        return progress
    }()
    
    // MARK: - Properties
    
    open fileprivate(set) var currentPage = 0 {
        didSet {
            let isReachedStartIndex = currentPage == -1
            currentPage = min(numberOfPages - 1, max(0, currentPage))
            
             if oldValue != currentPage {
                 progressLoadingView.isHidden = true
                 progressLoadingView.text?.removeAll()
            }
            
            if oldValue != currentPage, playerItemUrl != pageViews[currentPage].image.videoURL {
                // Stop Playing Video for previous page
                self.killPlayer()
                self.footerView.playerContainerView.isHidden = true

                // Start Playing Video for current page
                if let videoUrl = pageViews[currentPage].image.videoURL {
                    self.configurePlayer(videoUrl)
                } else {
                    self.footerView.imageContainerView.isHidden = false
                }
            }
            
            footerView.updatePage(currentPage + 1, numberOfPages)
            let title = pageViews[currentPage].image.title
            let description = pageViews[currentPage].image.description
            footerView.updateText(title: title, description: description)
            
            if currentPage == numberOfPages - 1 { seen = true }
            
            reconfigurePagesForPreload()
            
            pageDelegate?.lightboxController(self, didMoveToPage: currentPage)
            
            if let image = pageViews[currentPage].imageView.image, dynamicBackground {
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.125) { [weak self] in
                    self?.loadDynamicBackground(image)
                }
            }
            
            if oldValue < currentPage, (pageViews.count - currentPage) <= LightboxConfig.itemsToEnd {
                prelodMediaDelegate?.lightboxControllerWillReachRightEnd(self)
            } else if oldValue > currentPage || isReachedStartIndex, (currentPage - LightboxConfig.itemsToEnd) <= 0 {
                prelodMediaDelegate?.lightboxControllerWillReachLeftEnd(self)
            }
        }
    }
    
    open var numberOfPages: Int {
        return pageViews.count
    }
    
    open var dynamicBackground: Bool = false {
        didSet {
            if dynamicBackground == true {
                effectView.frame = view.frame
                backgroundView.frame = effectView.frame
                view.insertSubview(effectView, at: 0)
                view.insertSubview(backgroundView, at: 0)
            } else {
                effectView.removeFromSuperview()
                backgroundView.removeFromSuperview()
            }
        }
    }
    
    open var spacing: CGFloat = 20 {
        didSet {
            configureLayout(view.bounds.size)
        }
    }
    
    open var images: [LightboxImage] {
        return pageViews.map { $0.image }
    }
    
    open weak var pageDelegate: LightboxControllerPageDelegate?
    open weak var dismissalDelegate: LightboxControllerDismissalDelegate?
    open weak var imageTouchDelegate: LightboxControllerTouchDelegate?
    open weak var mediaSaveDelegate: LightboxSaveDelegate?
    open weak var prelodMediaDelegate: LightboxPreloadDelegate?
    
    open var initialImages: [LightboxImage]
    open var initialPage: Int
    open internal(set) var presented = false
    open fileprivate(set) var seen = false
    
    open var progressLoading: Progress! {
        didSet{
            let formatter = ByteCountFormatter()
            formatter.countStyle = .decimal
            let completed = formatter.string(fromByteCount: progressLoading.completedUnitCount)
            let total = formatter.string(fromByteCount: progressLoading.totalUnitCount)
            progressLoadingView.text = "\(completed) / \(total)"
            progressLoadingView.frame.size.width = progressLoadingView.intrinsicContentSize.width*1.2
            progressLoadingView.isHidden = (progressLoading.completedUnitCount / progressLoading.totalUnitCount) >= 1
        }
    }
    
    lazy var transitionManager: LightboxTransition = LightboxTransition()
    var pageViews = [PageView]()
    var statusBarHidden = false

    
    private var avPlayer : AVPlayer!
    private var asset: AVAsset!
    private var playerItem: AVPlayerItem!
    private var playerItemUrl: URL!
    private var playerItemContext = 0
    private var playerStatus: AVPlayerItem.Status!
    private let requiredAssetKeys = ["playable", "hasProtectedContent"]
    private var pausedForBackgrounding = false
    private var isPlaybackSliderTouchBegan = false

    
    // MARK: - Initializers
    
    public init(images: [LightboxImage] = [], startIndex index: Int = 0) {
        self.initialImages = images
        self.initialPage = index
        super.init(nibName: nil, bundle: nil)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        removeObservers()
    }
    
    // MARK: - View lifecycle
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        addObservers()
        // 9 July 2020: @3lvis
        // Lightbox hasn't been optimized to be used in presentation styles other than fullscreen.
        
        statusBarHidden = UIApplication.shared.isStatusBarHidden
        view.backgroundColor = UIColor.black
        
        modalPresentationStyle = .fullScreen
        if presentationController?.presentationStyle == .fullScreen {
            transitionManager.lightboxController = self
            transitionManager.scrollView = scrollView
            transitioningDelegate = transitionManager
        }
        
        [scrollView, overlayView, headerView, footerView, messageView, progressLoadingView].forEach { view.addSubview($0) }
        overlayView.addGestureRecognizer(overlayTapGestureRecognizer)
        
        configurePages(initialImages)
        
        goTo(initialPage, animated: false)
        
        if pageViews.count > 0 {
            let currentView = pageViews[currentPage]
            
            // Start Play Video for video message type
            if let videoUrl = currentView.image.videoURL {
                configurePlayer(videoUrl)
            } else {
                let title = currentView.image.title
                let description = currentView.image.description
                footerView.updateText(title: title, description: description)
            }
        }
    }
    
    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        scrollView.frame = view.bounds
        
        footerView.frame.size = CGSize(
            width: view.bounds.width,
            height: 118
        )
        
        messageView.frame.size = CGSize(
            width: view.bounds.width - 40,
            height: 50
        )
        
        footerView.frame.origin = CGPoint(
            x: 0,
            y: view.bounds.height - footerView.frame.height
        )
        
        headerView.frame = CGRect(
            x: 0,
            y: 0,
            width: view.bounds.width,
            height: 85
        )
        
        messageView.frame.origin = CGPoint (
            x: 20,
            y: view.frame.maxY - messageView.frame.height - 35
        )
        
        if !presented {
            presented = true
            configureLayout(view.bounds.size)
        }
    }
    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    open override var prefersStatusBarHidden: Bool {
        return LightboxConfig.hideStatusBar
    }
    
    // MARK: - Rotation
    
    override open func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: { [weak self] _ in
            self?.configureLayout(size)
        }, completion: nil)
    }
    
    // MARK: - Images Updating
    
    /// Add new images to Right
    ///
    public func appendNewImages(_ newImages: [LightboxImage]) {
        initialImages.append(contentsOf: newImages)
        configurePages(newImages, setContentOffset: false)
    }
    
    /// Add new images to Left
    ///
    public func insertNewImages(_ newImages: [LightboxImage]) {
        configureNewPages(newImages)
    }
    
    /// Update LightboxImage Video Url
    ///
    public func updateLightboxVideoUrl(_ oldUrl: URL?, with newUrl: URL?) {
        scrollView.subviews.forEach { subview in
            if (subview as? PageView)?.image.videoURL == oldUrl {
                (subview as? PageView)?.image.updateVideoUrl(newUrl: newUrl)
                (subview as? PageView)?.configure()
            }
        }
    }
    
    /// Update LightboxImageThumb Url for Video
    ///
    public func updateLightboxVideoThumbUrl(_ thumbUrl: URL?, for videoUrl: URL?) {
        scrollView.subviews.forEach { subview in
            if (subview as? PageView)?.image.videoURL == videoUrl {
                (subview as? PageView)?.image.updateVideoThumb(url: thumbUrl)
            }
        }
    }
    
    /// Update LightboxImage Image Url
    ///
    public func updateLightboxImageUrl(_ oldUrl: URL?, with newUrl: URL?) {
        scrollView.subviews.forEach { subview in
            if (subview as? PageView)?.image.imageURL == oldUrl {
                (subview as? PageView)?.image = LightboxImage(imageURL: newUrl)
                (subview as? PageView)?.configure()
            }
        }
    }
    
    // MARK: - Configuration

    func configurePages(_ images: [LightboxImage], setContentOffset: Bool = true) {
        //pageViews.forEach { $0.removeFromSuperview() }
        //pageViews = []
        
        let preloadIndicies = calculatePreloadIndicies()
        
        for i in 0..<images.count {
            let pageView = PageView(image: preloadIndicies.contains(i) ? images[i] : LightboxImageStub())
            pageView.pageViewDelegate = self
            
            scrollView.addSubview(pageView)
            pageViews.append(pageView)
        }
        
        configureLayout(view.bounds.size, setContentOffset: setContentOffset)
        self.prelodMediaDelegate?.lightboxControllerUpdated(self)
    }
    
    func configureNewPages(_ images: [LightboxImage]) {
        var newPageViews = [PageView]()
        
        images.forEach { image in
            let pageView = PageView(image: LightboxImageStub())
            pageView.pageViewDelegate = self
            newPageViews.append(pageView)
            scrollView.insertSubview(pageView, at: 0)
        }
        
        /// Update Layout only when scrollViewDidEndDragging
        ///
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let strongSelf = self else { return }
            if !strongSelf.scrollView.isDragging {
                timer.invalidate()

                DispatchQueue.main.async { [weak self]  in
                    guard let self = self else { return }
                    
                    self.initialImages = images + self.initialImages
                    self.pageViews = newPageViews + self.pageViews
                    self.currentPage += images.count
                    self.updateLayout(self.view.bounds.size)
                    self.prelodMediaDelegate?.lightboxControllerUpdated(self)
                }
            }
        }
    }
    
    func reconfigurePagesForPreload() {
        let preloadIndicies = calculatePreloadIndicies()
        
        for i in 0..<initialImages.count {
            let pageView = pageViews[i]
            if preloadIndicies.contains(i) {
                if type(of: pageView.image) == LightboxImageStub.self {
                    pageView.update(with: initialImages[i])
                }
            } else {
                if type(of: pageView.image) != LightboxImageStub.self {
                    pageView.update(with: LightboxImageStub())
                }
            }
        }
    }
    
    // MARK: - Pagination
    
    open func goTo(_ page: Int, animated: Bool = true) {
        guard page >= 0 && page < numberOfPages else {
            return
        }
        
        currentPage = page
        
        var offset = scrollView.contentOffset
        offset.x = CGFloat(page) * (scrollView.frame.width + spacing)
        
        let shouldAnimated = view.window != nil ? animated : false
        
        scrollView.setContentOffset(offset, animated: shouldAnimated)
    }
    
    open func next(_ animated: Bool = true) {
        goTo(currentPage + 1, animated: animated)
    }
    
    open func previous(_ animated: Bool = true) {
        goTo(currentPage - 1, animated: animated)
    }
    
    // MARK: - Actions
    
    @objc func overlayViewDidTap(_ tapGestureRecognizer: UITapGestureRecognizer) {
    }
    
    // MARK: - Layout
    
    open func configureLayout(_ size: CGSize, setContentOffset: Bool = true) {
        scrollView.frame.size = size
        scrollView.contentSize = CGSize(
            width: size.width * CGFloat(numberOfPages) + spacing * CGFloat(numberOfPages - 1),
            height: size.height)
        
        if setContentOffset {
            scrollView.contentOffset = CGPoint(x: CGFloat(currentPage) * (size.width + spacing), y: 0)
        }
        
        for (index, pageView) in pageViews.enumerated() {
            var frame = scrollView.bounds
            frame.origin.x = (frame.width + spacing) * CGFloat(index)
            pageView.frame = frame
            pageView.configureLayout()
            if index != numberOfPages - 1 {
                pageView.frame.size.width += spacing
            }
        }
        
        [headerView, footerView].forEach { ($0 as AnyObject).configureLayout() }
        
        overlayView.frame = scrollView.frame
        overlayView.resizeGradientLayer()
    }
    
    open func updateLayout(_ size: CGSize) {
        scrollView.frame.size = size
        scrollView.contentSize = CGSize(
            width: size.width * CGFloat(numberOfPages) + spacing * CGFloat(numberOfPages - 1),
            height: size.height)
        
        scrollView.contentOffset = CGPoint(x: CGFloat(currentPage) * (size.width + spacing), y: 0)
        
        for (index, pageView) in pageViews.enumerated() {
            var frame = scrollView.bounds
            frame.origin.x = (frame.width + spacing) * CGFloat(index)
            pageView.frame = frame
            pageView.configureLayout()
            if index != numberOfPages - 1 {
                pageView.frame.size.width += spacing
            }
        }
        
        overlayView.frame = scrollView.frame
        overlayView.resizeGradientLayer()
    }
    
    
    fileprivate func loadDynamicBackground(_ image: UIImage) {
        backgroundView.image = image
        backgroundView.layer.add(CATransition(), forKey: "fade")
    }
    
    func toggleControls(pageView: PageView?, visible: Bool, duration: TimeInterval = 0.1, delay: TimeInterval = 0) {
        let alpha: CGFloat = visible ? 1.0 : 0.0
        
        
        UIView.animate(withDuration: duration, delay: delay, options: [], animations: { [weak self] in
            self?.headerView.alpha = alpha
            self?.footerView.alpha = alpha
        }, completion: nil)
    }
    
    // MARK: - Helper functions
    func calculatePreloadIndicies () -> [Int] {
        var preloadIndicies: [Int] = []
        let preload = LightboxConfig.preload
        if preload > 0 {
            let lb = max(0, currentPage - preload)
            let rb = min(initialImages.count, currentPage + preload)
            for i in lb..<rb {
                preloadIndicies.append(i)
            }
        } else {
            preloadIndicies = [Int](0..<initialImages.count)
        }
        return preloadIndicies
    }
    
    
    // MARK: - Observers
    
    private func addObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(pauseVideoForBackgrounding), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(playVideoForForegrounding), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    private func removeObservers() {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc
    private func pauseVideoForBackgrounding() {
        if avPlayer?.rate != 0 {
            avPlayer?.pause()
            pausedForBackgrounding = true
            footerView.setPlayButtonSelected(true)
        }
    }
    
    @objc
    private func playVideoForForegrounding() {
        if pausedForBackgrounding {
            avPlayer?.play()
            pausedForBackgrounding = false
            footerView.setPlayButtonSelected(false)
        }
    }
    
    // MARK: - Player
    
    open func configurePlayer(_ url: URL) {
        showVideoThumbnail()
        
        asset = AVAsset(url: url)
        playerItemUrl = url
        playerItem = AVPlayerItem(asset: asset,
                                  automaticallyLoadedAssetKeys: requiredAssetKeys)
        
        avPlayer = AVPlayer(playerItem: playerItem)
        avPlayer?.isMuted = footerView.muteButton.isSelected
        avPlayer?.play()
        pageViews[currentPage].playerView.playerLayer.player = avPlayer
        pageViews[currentPage].loadingIndicator.alpha = 1
        
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: self.avPlayer?.currentItem, queue: nil) { [weak self] _ in
            self?.avPlayer?.seek(to: CMTime.zero)
            self?.avPlayer?.play()
        }
        
        avPlayer?.addPeriodicTimeObserver(forInterval: CMTimeMake(value: 1, timescale: 10), queue: .main) { [weak self] _ in
            if self?.avPlayer?.currentItem?.status == .readyToPlay, let time = self?.avPlayer?.currentTime() {
                
                DispatchQueue.main.async { [weak self]  in
                    if self?.footerView.playerContainerView.isHidden ?? false { self?.showPlayerView() }
                    
                    // Ignore when Playback Slider Touch Began
                    if !(self?.isPlaybackSliderTouchBegan ?? false) {
                        self?.footerView.playbackSlider.value = Float(time.seconds)
                        self?.footerView.upateLeftTimeLabel(time.stringTime)
                        
                        if let duration = self?.playerItem?.asset.duration {
                            let timeToEnd = (time - duration).stringTime
                            self?.footerView.upateRightTimeLabel(timeToEnd)
                        }
                    }
                }
            }
        }
    }
    
    public func showVideoThumbnail() {
        pageViews[currentPage].playerThumbnailView.alpha = 1.0
        pageViews[currentPage].playerThumbnailView.sd_setImage(with: pageViews[currentPage].image.imageURL)
    }
    
    public func hideVideoThumbnail() {
        self.pageViews[self.currentPage].playerThumbnailView.alpha = 0
    }
    
    func killPlayer() {
        avPlayer?.pause()
        avPlayer = nil
        playerItemUrl = nil
    }
    
    func showPlayerView() {
        if pageViews[self.currentPage].image.hasVideoContent {
            let duration : CMTime = self.playerItem?.asset.duration ?? CMTimeMake(value: 1, timescale: 10)
            let seconds : Float64 = CMTimeGetSeconds(duration)
            footerView.upatePlaybackSlider(Float(seconds))
            footerView.setPlayButtonSelected(false)
            footerView.upateLeftTimeLabel("00:00")
            footerView.upateRightTimeLabel("00:00")
            footerView.imageContainerView.isHidden = true
            footerView.playerContainerView.isHidden = false
            footerView.setSkipButtonsHidden(seconds <= 15.0)
            pageViews[currentPage].loadingIndicator.alpha = 0
            hideVideoThumbnail()
        }
    }
    
    // MARK: - Info Message
    
    func showMessage(text: String) {
        messageView.alpha = 1
        messageView.text = text
        UIView.animate(withDuration: 0.75, delay: 0.75, options: .curveEaseIn, animations: {  [weak self] in
            self?.messageView.alpha = 0
        })
    }
    
    // MARK: - Mute Player
    
    open func muteButtonDidTap(_ headerView: FooterView, _ button: UIButton) {
        if let isMuted = avPlayer?.isMuted {
            avPlayer?.isMuted = !isMuted
            button.isSelected = !isMuted
        }
    }
    
    // MARK: - Video Thumbnail

    private func showVideoThumbnail(for playbackSlider: UISlider) {
        // videoThumbnailView.image = nil

        let trackRect = playbackSlider.trackRect(forBounds: playbackSlider.bounds)
        let thumbRect = playbackSlider.thumbRect(forBounds: playbackSlider.bounds, trackRect: trackRect, value: playbackSlider.value)
        
        if let playbackSliderGlobalPoint = playbackSlider.superview?.convert(thumbRect.origin, to: nil) {

            let imgGenerator: AVAssetImageGenerator = AVAssetImageGenerator(asset: asset)
            imgGenerator.cancelAllCGImageGeneration()
            imgGenerator.appliesPreferredTrackTransform = true
            
            let timeInSec = playbackSlider.value
            let time = CMTime(seconds: Double(timeInSec), preferredTimescale: 1)
            
            if view.subviews.contains(videoThumbnailView), let sliderContainer = playbackSlider.superview {
                let minX = max(0, playbackSliderGlobalPoint.x + (thumbRect.width) - (videoThumbnailView.frame.width / 2))
                let x = min(minX, sliderContainer.frame.width -  videoThumbnailView.frame.width)
                let y = playbackSliderGlobalPoint.y - videoThumbnailView.frame.height - 10
                let newPosition = CGPoint(x: x, y: y)
                videoThumbnailView.frame.origin = newPosition
            }
            
            imgGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { [weak self] (_, image, _, _, error) in
                guard let self = self, self.isPlaybackSliderTouchBegan else { return }
                
                DispatchQueue.main.async {
                    guard timeInSec == playbackSlider.value else { return }
                    
                    if let cgImage = image {
                        let image = UIImage(cgImage: cgImage)
                        self.videoThumbnailView.image = image
                        
                        if !self.view.subviews.contains(self.videoThumbnailView) {
                            let ratio = image.size.height / image.size.width
                            let isVertical = ratio > 1
                            
                            let width = isVertical ? (self.view.frame.width / 4) : (self.view.frame.width / 3)
                            let height = width * ratio
                            self.videoThumbnailView.frame.size = CGSize(width: width, height: height)

                            if let sliderContainer = playbackSlider.superview {
                                let minX = max(0, playbackSliderGlobalPoint.x + (thumbRect.width) - (self.videoThumbnailView.frame.width / 2))
                                let x = min(minX, sliderContainer.frame.width - self.videoThumbnailView.frame.width)
                                let y = playbackSliderGlobalPoint.y - self.videoThumbnailView.frame.height - 10
                                let newPosition = CGPoint(x: x, y: y)
                                self.videoThumbnailView.frame.origin = newPosition
                            }
                            
                            if self.isPlaybackSliderTouchBegan {
                                self.view.addSubview(self.videoThumbnailView)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - UIScrollViewDelegate

extension LightboxController: UIScrollViewDelegate {
    
    public func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        var speed: CGFloat = velocity.x < 0 ? -2 : 2
        
        if velocity.x == 0 {
            speed = 0
        }
        
        let pageWidth = scrollView.bounds.width + spacing
        var x = scrollView.contentOffset.x + speed * 60.0
        
        if speed > 0 {
            x = ceil(x / pageWidth) * pageWidth
        } else if speed < -0 {
            x = floor(x / pageWidth) * pageWidth
        } else {
            x = round(x / pageWidth) * pageWidth
        }
        
        targetContentOffset.pointee.x = x
        currentPage = Int(x / pageWidth)
    }
}

// MARK: - PageViewDelegate

extension LightboxController: PageViewDelegate {
    func playerDidPlayToEndTime(_ pageView: PageView) {
        toggleControls(pageView: pageView, visible: true)
    }
    
    func remoteImageDidLoad(_ image: UIImage?, imageView: SDAnimatedImageView) {
        guard let image = image, dynamicBackground else {
            return
        }
        
        let imageViewFrame = imageView.convert(imageView.frame, to: view)
        guard view.frame.intersects(imageViewFrame) else {
            return
        }
        
        loadDynamicBackground(image)
    }
    
    func pageViewDidZoom(_ pageView: PageView) {
        let duration = pageView.hasZoomed ? 0.1 : 0.5
        toggleControls(pageView: pageView, visible: !pageView.hasZoomed, duration: duration, delay: 0.5)
    }
    
    func pageViewDidTouch(_ pageView: PageView) {
        guard !pageView.hasZoomed else { return }
        
        imageTouchDelegate?.lightboxController(self, didTouch: images[currentPage], at: currentPage)
        
        let visible = (headerView.alpha == 1.0)
        toggleControls(pageView: pageView, visible: !visible)
    }
}


// MARK: - HeaderViewDelegate

extension LightboxController: HeaderViewDelegate {
    
    func headerView(_ headerView: HeaderView, didPressDeleteButton deleteButton: UIButton) {
        deleteButton.isEnabled = false
        
        guard numberOfPages != 1 else {
            pageViews.removeAll()
            self.headerView(headerView, didPressCloseButton: headerView.closeButton)
            return
        }
        
        let prevIndex = currentPage
        
        if currentPage == numberOfPages - 1 {
            previous()
        } else {
            next()
            currentPage -= 1
        }
        
        self.initialImages.remove(at: prevIndex)
        self.pageViews.remove(at: prevIndex).removeFromSuperview()
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) { [weak self]  in
            guard let self = self else { return }
            self.configureLayout(self.view.bounds.size)
            self.currentPage = Int(self.scrollView.contentOffset.x / self.view.bounds.width)
            deleteButton.isEnabled = true
        }
    }
    
    func headerView(_ headerView: HeaderView, didPressCloseButton closeButton: UIButton) {
        closeButton.isEnabled = false
        presented = false
        dismissalDelegate?.lightboxControllerWillDismiss(self)
        dismiss(animated: true, completion: nil)
    }
}

// MARK: - FooterViewDelegate

extension LightboxController: FooterViewDelegate {
    
    public func goBackButtonDidTap(_ headerView: FooterView, _ button: UIButton) {
        if let currentTime = avPlayer?.currentTime() {
            let playerCurrentTime = CMTimeGetSeconds(currentTime)
            let newTime = max(0, playerCurrentTime - 15)
            let time: CMTime = CMTimeMake(value: Int64(newTime * 1000 as Float64), timescale: 1000)
            avPlayer?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        }
    }
    
    public func goForwardButtonDidTap(_ headerView: FooterView, _ button: UIButton) {
        guard let duration = avPlayer?.currentItem?.duration, let currentTime = avPlayer?.currentTime() else { return }
        let playerCurrentTime = CMTimeGetSeconds(currentTime)
        let newTime = playerCurrentTime + 15
        let time: CMTime!
        
        if newTime < CMTimeGetSeconds(duration) {
            time = CMTimeMake(value: Int64(newTime * 1000 as Float64), timescale: 1000)
        } else {
            time = .zero
            avPlayer?.pause()
            footerView.setPlayButtonSelected(true)
        }
        
        avPlayer?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)

    }
    
    public func saveButtonDidTap(_ headerView: FooterView, _ saveButton: UIButton) {
        guard images.count > 0 else { return }

        if let videoUrl = images[currentPage].videoURL {
            
            saveButton.isUserInteractionEnabled = false
            PhotoLibraryManager.saveVideo(from: videoUrl) { success, error in
                DispatchQueue.main.async { [weak self] in
                    saveButton.isUserInteractionEnabled = true
                    self?.mediaSaveDelegate?.lightboxControllerSaveMedia(self, from: videoUrl, result: (success, error))
                    
                    if success {
                        self?.showMessage(text: "Video saved to Photos.")
                    } else {
                        self?.goToSettings()
                    }
                }
            }
        } else if let imageUrl = images[currentPage].imageURL {
            
            saveButton.isUserInteractionEnabled = false
            PhotoLibraryManager.saveImage(from: imageUrl) { success, error in
                DispatchQueue.main.async { [weak self] in
                    saveButton.isUserInteractionEnabled = true
                    self?.mediaSaveDelegate?.lightboxControllerSaveMedia(self, from: imageUrl, result: (success, error))
                    if success {
                        self?.showMessage(text: "Image saved to Photos.")
                    } else {
                        self?.goToSettings()
                    }
                }
            }
        } else if let image = images[currentPage].image {
            
            saveButton.isUserInteractionEnabled = false
            PhotoLibraryManager.saveImage(image) { [weak self] success, error in
                DispatchQueue.main.async { [weak self] in
                    saveButton.isUserInteractionEnabled = true
                    self?.mediaSaveDelegate?.lightboxControllerSaveMedia(self, from: nil, result: (success, error))
                    if success {
                        self?.showMessage(text: "Image saved to Photos.")
                    } else {
                        self?.goToSettings()
                    }
                }
            }
        }
    }
    
    public func playButtonDidTap(_ footerView: FooterView, _ button: UIButton) {
        if avPlayer?.rate == 0  {
            avPlayer?.play()
            button.isSelected = false
        } else {
            avPlayer?.pause()
            button.isSelected = true
        }
    }
    
    public func playbackSliderTouchBegan(_ footerView: FooterView, playbackSlider: UISlider) {
        isPlaybackSliderTouchBegan = true
        showVideoThumbnail(for: playbackSlider)
    }

    public func playbackSliderValueChanged(_ footerView: FooterView, playbackSlider: UISlider) {
        showVideoThumbnail(for: playbackSlider)
        
        let timeInSec = playbackSlider.value
        let time = CMTime(seconds: Double(timeInSec), preferredTimescale: 1)
        
        footerView.upateLeftTimeLabel(time.stringTime)
        if let duration = playerItem?.asset.duration {
            let timeToEnd = (time - duration).stringTime
            footerView.upateRightTimeLabel(timeToEnd)
        }
    }
    
    public func playbackSliderTouchEnded(_ footerView: FooterView, playbackSlider: UISlider) {
        isPlaybackSliderTouchBegan = false
        
        let seconds : Int64 = Int64(playbackSlider.value)
        let targetTime: CMTime = CMTimeMake(value: seconds, timescale: 1)
        avPlayer?.seek(to: targetTime)
        
        videoThumbnailView.removeFromSuperview()
    }
    
    public func footerView(_ footerView: FooterView, didExpand expanded: Bool) {
        UIView.animate(withDuration: 0.25, animations: {  [weak self] in
            guard let self = self else { return }
            self.overlayView.alpha = expanded ? 1.0 : 0.0
            self.headerView.deleteButton.alpha = expanded ? 0.0 : 1.0
        })
    }
}

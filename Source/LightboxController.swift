import UIKit
import SDWebImage
import AVKit

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
    
    // MARK: - Properties
    
    open fileprivate(set) var currentPage = 0 {
        didSet {
            let isReachedStartIndex = currentPage == -1

            currentPage = min(numberOfPages - 1, max(0, currentPage))
            footerView.updatePage(currentPage + 1, numberOfPages)
            let title = pageViews[currentPage].image.title
            let description = pageViews[currentPage].image.description
            footerView.updateText(title: title, description: description)
            
            if currentPage == numberOfPages - 1 { seen = true }
            
            reconfigurePagesForPreload()
            
            pageDelegate?.lightboxController(self, didMoveToPage: currentPage)
            
            if let image = pageViews[currentPage].imageView.image, dynamicBackground {
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.125) {
                    self.loadDynamicBackground(image)
                }
            }

            if oldValue != currentPage {
                self.killPlayer()
                self.footerView.playerContainerView.isHidden = true
                self.footerView.imageContainerView.isHidden = false
            }
            
            // Start Playing Video for currentPage
            if let videoUrl = pageViews[currentPage].image.videoURL {
                guard oldValue != currentPage else { return }
                self.configurePlayer(videoUrl)

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
    
    open internal(set) var presented = false
    open fileprivate(set) var seen = false
    
    lazy var transitionManager: LightboxTransition = LightboxTransition()
    var pageViews = [PageView]()
    var statusBarHidden = false
    var initialImages: [LightboxImage]
    var initialPage: Int
    
    private var avPlayer : AVPlayer!
    private var asset: AVAsset!
    private var playerItem: AVPlayerItem!
    private var playerItemContext = 0
    private var playerStatus: AVPlayerItem.Status!
    private let requiredAssetKeys = ["playable", "hasProtectedContent"]
    private var pausedForBackgrounding = false

    
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
        modalPresentationStyle = .fullScreen
        
        statusBarHidden = UIApplication.shared.isStatusBarHidden
        
        view.backgroundColor = UIColor.black
        transitionManager.lightboxController = self
        transitionManager.scrollView = scrollView
        transitioningDelegate = transitionManager
        
        [scrollView, overlayView, headerView, footerView, messageView].forEach { view.addSubview($0) }
        overlayView.addGestureRecognizer(overlayTapGestureRecognizer)
        
        configurePages(initialImages)
        
        goTo(initialPage, animated: false)
        
        // Start Play Video for currentPage
        if pageViews.count > 0, let videoUrl = pageViews[currentPage].image.videoURL {
            configurePlayer(videoUrl)
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
    
    open override var prefersStatusBarHidden: Bool {
        return LightboxConfig.hideStatusBar
    }
    
    // MARK: - Rotation
    
    override open func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: { _ in
            self.configureLayout(size)
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
        initialImages = newImages + initialImages
        configureNewPages(newImages)
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
    }
    
    func configureNewPages(_ images: [LightboxImage]) {
        for i in 0..<images.count {
            let pageView = PageView(image: LightboxConfig.preload > i ? images[i] : LightboxImageStub())
            pageView.pageViewDelegate = self
            
            scrollView.insertSubview(pageView, at: 0)
            pageViews.insert(pageView, at: 0)
        }
        
        self.currentPage += images.count
        
        /// Update Layout only when scrollViewDidEndDragging
        ///
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if !self.scrollView.isDragging {
                DispatchQueue.main.async {
                    self.updateLayout(self.view.bounds.size)
                    timer.invalidate()
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
        
        
        UIView.animate(withDuration: duration, delay: delay, options: [], animations: {
            self.headerView.alpha = alpha
            self.footerView.alpha = alpha
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
        playerItem?.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status))
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
        pageViews[currentPage].playerView.playerLayer.player = avPlayer
        pageViews[currentPage].loadingIndicator.alpha = 1
        footerView.muteButton.isSelected = false
        
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: self.avPlayer.currentItem, queue: nil) { [weak self] _ in
            self?.avPlayer?.seek(to: CMTime.zero)
            self?.avPlayer?.play()
        }
        
        avPlayer?.addPeriodicTimeObserver(forInterval: CMTimeMake(value: 1, timescale: 10), queue: .main) { [weak self] _ in
            if self?.avPlayer?.currentItem?.status == .readyToPlay, let time = self?.avPlayer?.currentTime() {
                
                DispatchQueue.main.async {
                    self?.footerView.playbackSlider.value = Float(time.seconds)
                    self?.footerView.upateLeftTimeLabel(time.stringTime)
                    if let duration = self?.playerItem.asset.duration {
                        let timeToEnd = (time - duration).stringTime
                        self?.footerView.upateRightTimeLabel(timeToEnd)
                    }
                }
            }
        }
    }
    
    
    func killPlayer() {
        avPlayer?.pause()
        avPlayer = nil
    }
    
    open override func observeValue(forKeyPath keyPath: String?,
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
            UIView.animate(withDuration: 0.4) {
                if status == .readyToPlay, self.pageViews[self.currentPage].image.hasVideoContent {
                    self.pageViews[self.currentPage].loadingIndicator.alpha = 0
                    let duration : CMTime = self.playerItem.asset.duration
                    let seconds : Float64 = CMTimeGetSeconds(duration)
                    self.footerView.upatePlaybackSlider(Float(seconds))
                    self.footerView.setPlayButtonSelected(false)
                    self.footerView.upateLeftTimeLabel("00:00")
                    self.footerView.upateRightTimeLabel("00:00")
                    self.footerView.imageContainerView.isHidden = true
                    self.footerView.playerContainerView.isHidden = false
                    self.footerView.setSkipButtonsHidden(seconds <= 15.0)
                }
            }
        }
    }
    
    // MARK: - Info Message
    
    func showMessage(text: String) {
        messageView.alpha = 1
        messageView.text = text
        UIView.animate(withDuration: 0.75, delay: 0.75, options: .curveEaseIn, animations: {
            self.messageView.alpha = 0
        })
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
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
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
            var newTime = playerCurrentTime - 5
            if newTime < 0 { newTime = 0 }
            let time2: CMTime = CMTimeMake(value: Int64(newTime * 1000 as Float64), timescale: 1000)
            avPlayer?.seek(to: time2, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero)
        }
    }
    
    public func goForwardButtonDidTap(_ headerView: FooterView, _ button: UIButton) {
        guard let duration = avPlayer?.currentItem?.duration, let currentTime = avPlayer?.currentTime() else { return }
        let playerCurrentTime = CMTimeGetSeconds(currentTime)
        let newTime = playerCurrentTime + 5
        
        if newTime < (CMTimeGetSeconds(duration) - 5) {
            let time2: CMTime = CMTimeMake(value: Int64(newTime * 1000 as Float64), timescale: 1000)
            avPlayer?.seek(to: time2, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero)
        }
    }
    
    public func muteButtonDidTap(_ headerView: FooterView, _ button: UIButton) {
        if let isMuted = avPlayer?.isMuted {
            avPlayer?.isMuted = !isMuted
            button.isSelected = !isMuted
        }
    }
    
    public func saveButtonDidTap(_ headerView: FooterView, _ saveButton: UIButton) {
        guard images.count > 0 else { return }
        
        if let videoUrl = images[currentPage].videoURL {
            
            saveButton.isUserInteractionEnabled = false
            PhotoLibraryManager.saveVideo(from: videoUrl) { [weak self] success, error in
                DispatchQueue.main.async {
                    saveButton.isUserInteractionEnabled = true
                    self?.mediaSaveDelegate?.lightboxControllerSaveMedia(self, from: videoUrl, result: (success, error))
                    
                    if success {
                        self?.showMessage(text: "Video saved to Photos.")
                    } else {
                        self?.showMessage(text: "Video not saved. Error: \(error?.localizedDescription ?? "")")
                    }
                }
            }
        } else if let imageUrl = images[currentPage].imageURL {
            
            saveButton.isUserInteractionEnabled = false
            PhotoLibraryManager.saveImage(from: imageUrl) { [weak self] success, error in
                DispatchQueue.main.async {
                    saveButton.isUserInteractionEnabled = true
                    self?.mediaSaveDelegate?.lightboxControllerSaveMedia(self, from: imageUrl, result: (success, error))
                    if success {
                        self?.showMessage(text: "Image saved to Photos.")
                    } else {
                        self?.showMessage(text: "Image not saved. Error: \(error?.localizedDescription ?? "")")
                    }
                }
            }
        } else if let image = images[currentPage].image {
            
            saveButton.isUserInteractionEnabled = false
            PhotoLibraryManager.saveImage(image) { [weak self] success, error in
                DispatchQueue.main.async {
                    saveButton.isUserInteractionEnabled = true
                    self?.mediaSaveDelegate?.lightboxControllerSaveMedia(self, from: nil, result: (success, error))
                    if success {
                        self?.showMessage(text: "Image saved to Photos.")
                    } else {
                        self?.showMessage(text: "Image not saved. Error: \(error?.localizedDescription ?? "")")
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
    
    public func playbackSliderValueChanged(_ footerView: FooterView, playbackSlider: UISlider) {
        let seconds : Int64 = Int64(playbackSlider.value)
        let targetTime: CMTime = CMTimeMake(value: seconds, timescale: 1)
        avPlayer?.seek(to: targetTime)
    }
    
    
    public func footerView(_ footerView: FooterView, didExpand expanded: Bool) {
        UIView.animate(withDuration: 0.25, animations: {
            self.overlayView.alpha = expanded ? 1.0 : 0.0
            self.headerView.deleteButton.alpha = expanded ? 0.0 : 1.0
        })
    }
}

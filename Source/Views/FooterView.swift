import UIKit

public protocol FooterViewDelegate: AnyObject {
    
    func footerView(_ footerView: FooterView, didExpand expanded: Bool)
    
    func playbackSliderTouchBegan(_ footerView: FooterView, playbackSlider: UISlider)
    func playbackSliderValueChanged(_ footerView: FooterView, playbackSlider: UISlider)
    func playbackSliderTouchEnded(_ footerView: FooterView, playbackSlider: UISlider)
    func playButtonDidTap(_ footerView: FooterView, _ button: UIButton)
    
    func saveButtonDidTap(_ headerView: FooterView, _ button: UIButton)
    func muteButtonDidTap(_ headerView: FooterView, _ button: UIButton)
    func goBackButtonDidTap(_ headerView: FooterView, _ button: UIButton)
    func goForwardButtonDidTap(_ headerView: FooterView, _ button: UIButton)
}

open class FooterView: UIView {
    
    
    open fileprivate(set) lazy var playerContainerView: UIView = { [unowned self] in
        let view = UIView(frame: CGRect.zero)
        view.backgroundColor = UIColor(hex: "26252A").withAlphaComponent(0.7)
        
        return view
    }()
    
    open fileprivate(set) lazy var imageContainerView: UIView = { [unowned self] in
        let view = UIView(frame: CGRect.zero)
        view.backgroundColor = UIColor(hex: "26252A").withAlphaComponent(0.7)
        
        return view
    }()
    

    open fileprivate(set) lazy var playbackSlider: PlaybackSlider = { [unowned self] in
        let slider = PlaybackSlider(frame: CGRect.zero)
        slider.minimumValue = 0
        
        let smallCircleImage = makeCircleWith(size: CGSize(width: 10, height: 10), backgroundColor: .white)
        let largeCircleImage = makeCircleWith(size: CGSize(width: 20, height: 20), backgroundColor: .white)

        slider.setThumbImage(smallCircleImage, for: .normal)
        slider.setThumbImage(largeCircleImage, for: .highlighted)
        slider.isContinuous = true
        slider.tintColor = .white
        slider.maximumTrackTintColor = UIColor(hex: "787880").withAlphaComponent(0.32)
        slider.addTarget(self, action: #selector(onSliderValChanged(slider:event:)), for: .valueChanged)
        
        return slider
    }()
    
    open fileprivate(set) lazy var leftTimeLabel: UILabel = { [unowned self] in
        let label = UILabel(frame: CGRect.zero)
        label.numberOfLines = 1
        label.isHidden = !LightboxConfig.TimeLabel.enabled
        label.textColor = LightboxConfig.TimeLabel.textColor
        label.font = LightboxConfig.TimeLabel.font
        label.textAlignment = .left
        
        return label
    }()
    
    open fileprivate(set) lazy var rightTimeLabel: UILabel = { [unowned self] in
        let label = UILabel(frame: CGRect.zero)
        label.numberOfLines = 1
        label.isHidden = !LightboxConfig.TimeLabel.enabled
        label.textColor = LightboxConfig.TimeLabel.textColor
        label.font = LightboxConfig.TimeLabel.font
        label.textAlignment = .right
        
        return label
    }()
    
    open fileprivate(set) lazy var playButton: UIButton = { [unowned self] in
        let button = UIButton(type: .custom)
        button.frame.size = CGSize(width: 20, height: 22)
        
        var playButtonImage = AssetManager.image("play")
        var pauseButtonImage = AssetManager.image("pause")

        button.setBackgroundImage(playButtonImage, for: .selected)
        button.setBackgroundImage(pauseButtonImage, for: .normal)
        button.isSelected = false

        button.addTarget(self, action: #selector(playButtonTouched(_:)), for: .touchUpInside)
        button.tintColor = .white

        return button
    }()
    
    open fileprivate(set) lazy var goForwardButton: UIButton = { [unowned self] in
        let button = UIButton(type: .custom)
        button.frame.size = CGSize(width: 18, height: 20)
        
        var goforwardButtonImage = AssetManager.image("forward")

        button.setBackgroundImage(goforwardButtonImage, for: UIControl.State())
        button.addTarget(self, action: #selector(goForwardButtonDidTap(_:)), for: .touchUpInside)
        button.tintColor = .white

        return button
    }()
    
    open fileprivate(set) lazy var goBackButton: UIButton = { [unowned self] in
        let button = UIButton(type: .custom)
        button.frame.size = CGSize(width: 18, height: 20)

        var gobackwardButtonImage = AssetManager.image("back")

        button.setBackgroundImage(gobackwardButtonImage, for: UIControl.State())
        button.addTarget(self, action: #selector(goBackButtonDidTap(_:)), for: .touchUpInside)
        button.tintColor = .white
        
        return button
    }()
    
    open fileprivate(set) lazy var muteButton: UIButton = { [unowned self] in
        let button = UIButton(type: .custom)
        button.frame.size = LightboxConfig.MuteButton.size
        button.isHidden = !LightboxConfig.MuteButton.enabled
        
        var isNotMutedButtonImage = AssetManager.image("unmute")
        var isMutedButtonImage = AssetManager.image("mute")
        
        button.setBackgroundImage(isNotMutedButtonImage, for: .normal)
        button.setBackgroundImage(isMutedButtonImage, for: .selected)
        button.isSelected = false

        button.addTarget(self, action: #selector(muteButtonTouched(_:)), for: .touchUpInside)
        button.tintColor = .white.withAlphaComponent(0.7)

        return button
    }()
    
    open fileprivate(set) lazy var saveButton: UIButton = { [unowned self] in
      let title = NSAttributedString(
        string: LightboxConfig.SaveButton.text,
        attributes: LightboxConfig.SaveButton.textAttributes)

      let button = UIButton(type: .system)

      button.setAttributedTitle(title, for: .normal)
      button.frame.size = LightboxConfig.SaveButton.size
      button.setImage(LightboxConfig.SaveButton.image, for: UIControl.State())
      button.tintColor = .white
        
      button.addTarget(self, action: #selector(saveButtonDidTap(_:)), for: .touchUpInside)

      if let image = LightboxConfig.DeleteButton.image {
          button.setBackgroundImage(image, for: UIControl.State())
      }

      button.isHidden = !LightboxConfig.SaveButton.enabled

      return button
    }()
    
    open fileprivate(set) lazy var titleLabel: UILabel = { [unowned self] in
        let label = UILabel(frame: CGRect.zero)
        label.isHidden = !LightboxConfig.TitleLabel.enabled
        label.textColor = LightboxConfig.TitleLabel.textColor
        label.numberOfLines = 1
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)

        return label
    }()
    
    open fileprivate(set) lazy var descriptionLabel: UILabel = { [unowned self] in
        let label = UILabel(frame: CGRect.zero)
        label.isHidden = !LightboxConfig.DescriptionLabel.enabled
        label.textColor = LightboxConfig.DescriptionLabel.textColor
        label.numberOfLines = 1
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 14)
        
        return label
    }()
    
    open fileprivate(set) lazy var infoLabel: UILabel = { [unowned self] in
        let label = InfoLabel(text: "")
        label.isHidden = !LightboxConfig.InfoLabel.enabled
        label.textColor = LightboxConfig.InfoLabel.textColor
        label.numberOfLines = 1
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 14)
        label.delegate = self
        
        return label
    }()
    
    open fileprivate(set) lazy var pageLabel: UILabel = { [unowned self] in
        let label = UILabel(frame: CGRect.zero)
        label.isHidden = !LightboxConfig.PageIndicator.enabled
        label.numberOfLines = 1
        
        return label
    }()
    
    open fileprivate(set) lazy var separatorView: UIView = { [unowned self] in
        let view = UILabel(frame: CGRect.zero)
        view.isHidden = !LightboxConfig.PageIndicator.enabled
        view.backgroundColor = LightboxConfig.PageIndicator.separatorColor
        
        return view
    }()
    
    let gradientColors = [UIColor(hex: "040404").withAlphaComponent(0.1), UIColor(hex: "040404")]
    open weak var delegate: FooterViewDelegate?
    
    // MARK: - Actions
    
    @objc func onSliderValChanged(slider: UISlider, event: UIEvent){
        if let touchEvent = event.allTouches?.first {
            switch touchEvent.phase {
            case .began:
                delegate?.playbackSliderTouchBegan(self, playbackSlider: playbackSlider)
            case .moved:
                delegate?.playbackSliderValueChanged(self, playbackSlider: playbackSlider)
            case .ended:
                delegate?.playbackSliderTouchEnded(self, playbackSlider: playbackSlider)
            default:
                break
            }
        }
    }
    
    @objc func playButtonTouched(_ button: UIButton) {
        delegate?.playButtonDidTap(self, button)
    }
    
    @objc func goBackButtonDidTap(_ button: UIButton) {
        delegate?.goBackButtonDidTap(self, button)
    }
    
    @objc func goForwardButtonDidTap(_ button: UIButton) {
        delegate?.goForwardButtonDidTap(self, button)
    }
    
    @objc func muteButtonTouched(_ button: UIButton) {
        delegate?.muteButtonDidTap(self, button)
    }
    
    @objc func saveButtonDidTap(_ button: UIButton) {
        delegate?.saveButtonDidTap(self, button)
    }
    
    // MARK: - Initializers
    
    public init() {
        super.init(frame: CGRect.zero)
        
        backgroundColor = UIColor.clear
       // _ = addGradientLayer(gradientColors)
        
        [playbackSlider, leftTimeLabel, rightTimeLabel, playButton, goBackButton, goForwardButton, muteButton].forEach { playerContainerView.addSubview($0) }
        [titleLabel, descriptionLabel].forEach { imageContainerView.addSubview($0) }
        [imageContainerView, playerContainerView, saveButton].forEach { addSubview($0) }
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Helpers
    
    
    private func makeCircleWith(size: CGSize, backgroundColor: UIColor) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(backgroundColor.cgColor)
        context?.setStrokeColor(UIColor.clear.cgColor)
        let bounds = CGRect(origin: .zero, size: size)
        context?.addEllipse(in: bounds)
        context?.drawPath(using: .fill)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image
    }

    func updatePage(_ page: Int, _ numberOfPages: Int) {
        let text = "\(page)/\(numberOfPages)"
        
        pageLabel.attributedText = NSAttributedString(string: text,
                                                      attributes: LightboxConfig.PageIndicator.textAttributes)
        pageLabel.sizeToFit()
    }
    
    func setPlayButtonSelected(_ selected: Bool) {
        playButton.isSelected = selected
    }
    
    func upatePlaybackSlider(_ maximumValue: Float ) {
        playbackSlider.maximumValue = maximumValue
        playbackSlider.value = 0
    }
    
    func setSkipButtonsHidden(_ isHidden: Bool ) {
        goForwardButton.isHidden = isHidden
        goBackButton.isHidden = isHidden
    }
    
    func upateLeftTimeLabel(_ text: String?) {
        leftTimeLabel.text = text
    }
    
    func upateRightTimeLabel(_ text: String?) {
        rightTimeLabel.text = text
    }
    
    func updateText(title: String?, description: String?) {
        titleLabel.text = title
        descriptionLabel.text = description
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        
        do {
            let bottomPadding: CGFloat
            if #available(iOS 11, *) {
                bottomPadding = safeAreaInsets.bottom
            } else {
                bottomPadding = 0
            }
            
            pageLabel.frame.origin = CGPoint(
                x: (frame.width - pageLabel.frame.width) / 2,
                y: frame.height - pageLabel.frame.height - 2 - bottomPadding
            )
        }
        
        playerContainerView.frame = CGRect(
            x: 0,
            y: 0,
            width: frame.width,
            height: frame.height
        )
        
        imageContainerView.frame = CGRect(
            x: 0,
            y: frame.height - 85,
            width: frame.width,
            height: 85
        )
        
        playbackSlider.frame = CGRect(
            x: 15,
            y: 16,
            width: playerContainerView.frame.width - 30,
            height: 5
        )
        
        leftTimeLabel.frame = CGRect(
            x: 15,
            y: playbackSlider.frame.maxY + 8,
            width: 100,
            height: 13
        )
        
        rightTimeLabel.frame = CGRect(
            x: playerContainerView.frame.width - rightTimeLabel.frame.width - 15,
            y: playbackSlider.frame.maxY + 8,
            width: 100,
            height: 13
        )

        saveButton.frame.origin = CGPoint(
          x: playerContainerView.frame.width - saveButton.frame.width - 15,
          y: playerContainerView.frame.height - saveButton.frame.height - 41
        )
        
        muteButton.frame.origin = CGPoint(
          x: 15,
          y: saveButton.frame.minY
        )
                
        playButton.center.x = center.x
        playButton.center.y = saveButton.center.y
        
        goForwardButton.frame.origin = CGPoint(
          x: playButton.frame.maxX + 30,
          y: playButton.frame.minY
        )
        
        goBackButton.frame.origin = CGPoint(
          x: playButton.frame.minX - goBackButton.frame.width - 30,
          y: playButton.frame.minY
        )
        
        separatorView.frame = CGRect(
            x: 0,
            y: pageLabel.frame.minY - 2.5,
            width: frame.width,
            height: 0.5
        )

        titleLabel.frame = CGRect(x: 50,
                                  y: 14,
                                  width: frame.width - 50 * 2,
                                  height: 20)
        
        descriptionLabel.frame = CGRect(x: 50,
                                 y: titleLabel.frame.maxY + 5,
                                 width: frame.width - 50 * 2,
                                 height: 16)

        resizeGradientLayer()
    }
}

// MARK: - LayoutConfigurable

extension FooterView: LayoutConfigurable {
    
    @objc public func configureLayout() {
        infoLabel.frame = CGRect(x: 50, y: 0, width: frame.width - 50 * 2, height: 16)
    }
}

extension FooterView: InfoLabelDelegate {
    
    public func infoLabel(_ infoLabel: InfoLabel, didExpand expanded: Bool) {
     //   _ = (expanded || infoLabel.fullText.isEmpty) ? removeGradientLayer() : addGradientLayer(gradientColors)
        delegate?.footerView(self, didExpand: expanded)
    }
}

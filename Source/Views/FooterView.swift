import UIKit

public protocol FooterViewDelegate: AnyObject {
    
    func footerView(_ footerView: FooterView, didExpand expanded: Bool)
    func playbackSliderValueChanged(_ footerView: FooterView, playbackSlider: UISlider)
    func playButtonDidTap(_ footerView: FooterView, _ button: UIButton)
}

open class FooterView: UIView {
    
    open fileprivate(set) lazy var playbackSlider: UISlider = { [unowned self] in
        let slider = UISlider(frame: CGRect.zero)
        slider.minimumValue = 0
        let circleImage = makeCircleWith(size: CGSize(width: 10, height: 10), backgroundColor: .white)
        slider.setThumbImage(circleImage, for: .normal)
        slider.setThumbImage(circleImage, for: .highlighted)
        slider.isContinuous = true
        slider.tintColor = .white
        slider.maximumTrackTintColor = .darkGray
        slider.addTarget(self, action: #selector(self.playbackSliderValueChanged(_:)), for: .valueChanged)
        
        return slider
    }()
    
    open fileprivate(set) lazy var timeLabel: UILabel = { [unowned self] in
        let label = UILabel(frame: CGRect.zero)
        label.numberOfLines = 1
        label.isHidden = !LightboxConfig.TimeLabel.enabled
        label.textColor = LightboxConfig.TimeLabel.textColor
        label.font = LightboxConfig.TimeLabel.font
        
        return label
    }()
    
    open fileprivate(set) lazy var playButton: UIButton = { [unowned self] in
        let button = UIButton(type: .custom)
        button.frame.size = CGSize(width: 24, height: 24)
        
        var playButtonImage = AssetManager.image("lightbox_play")
        var pauseButtonImage = AssetManager.image("lightbox_play")
        
        // Note by Elvis Nuñez on Mon 22 Jun 08:06
        // When using SPM you might find that assets are note included. This is a workaround to provide default assets
        // under iOS 13 so using SPM can work without problems.
        if #available(iOS 13.0, *) {
            playButtonImage = UIImage(systemName: "play.circle.fill")
            pauseButtonImage = UIImage(systemName: "pause.circle.fill")
        }
        
        button.setBackgroundImage(playButtonImage, for: .selected)
        button.setBackgroundImage(pauseButtonImage, for: .normal)
        button.isSelected = false

        button.addTarget(self, action: #selector(playButtonTouched(_:)), for: .touchUpInside)
        button.tintColor = .white
        
        button.layer.shadowOffset = CGSize(width: 1, height: 1)
        button.layer.shadowColor = UIColor.gray.cgColor
        button.layer.masksToBounds = false
        button.layer.shadowOpacity = 0.8
        
        return button
    }()
    
    
    open fileprivate(set) lazy var infoLabel: InfoLabel = { [unowned self] in
        let label = InfoLabel(text: "")
        label.isHidden = !LightboxConfig.InfoLabel.enabled
        
        label.textColor = LightboxConfig.InfoLabel.textColor
        label.isUserInteractionEnabled = true
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
    
    @objc func playbackSliderValueChanged(_ playbackSlider: UISlider){
        delegate?.playbackSliderValueChanged(self, playbackSlider: playbackSlider)
    }
    
    @objc func playButtonTouched(_ button: UIButton) {
        delegate?.playButtonDidTap(self, button)
    }
    
    // MARK: - Initializers
    
    public init() {
        super.init(frame: CGRect.zero)
        
        backgroundColor = UIColor.clear
        _ = addGradientLayer(gradientColors)
        
        [playbackSlider, timeLabel, playButton].forEach { addSubview($0) }
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
    
    
    func expand(_ expand: Bool) {
        expand ? infoLabel.expand() : infoLabel.collapse()
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
    
    func upatetimeLabel(_ text: String ) {
        timeLabel.text = text
    }
    
    func updateText(_ text: String) {
        infoLabel.fullText = text
        
        if text.isEmpty {
            _ = removeGradientLayer()
        } else if !infoLabel.expanded {
            _ = addGradientLayer(gradientColors)
        }
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
        
        playbackSlider.frame = CGRect(
            x: 0,
            y: 5,
            width: frame.width,
            height: 20
        )
        
        timeLabel.frame = CGRect(
            x: 5,
            y: playbackSlider.frame.maxY + 10,
            width: 100,
            height: 20
        )
        
        playButton.frame.origin = CGPoint(
            x: ((frame.width) / 2) - 12,
            y: playbackSlider.frame.maxY + 10
        )
        
        separatorView.frame = CGRect(
            x: 0,
            y: pageLabel.frame.minY - 2.5,
            width: frame.width,
            height: 0.5
        )
        
        infoLabel.frame.origin.y = separatorView.frame.minY - infoLabel.frame.height - 15
        timeLabel.frame.origin.y = playbackSlider.frame.maxY + 10
        
        resizeGradientLayer()
    }
}

// MARK: - LayoutConfigurable

extension FooterView: LayoutConfigurable {
    
    @objc public func configureLayout() {
        infoLabel.frame = CGRect(x: 17, y: 0, width: frame.width - 17 * 2, height: 35)
        infoLabel.configureLayout()
    }
}

extension FooterView: InfoLabelDelegate {
    
    public func infoLabel(_ infoLabel: InfoLabel, didExpand expanded: Bool) {
        _ = (expanded || infoLabel.fullText.isEmpty) ? removeGradientLayer() : addGradientLayer(gradientColors)
        delegate?.footerView(self, didExpand: expanded)
    }
}

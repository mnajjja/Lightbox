import UIKit
import Lightbox

class ViewController: UIViewController {
    
    var controller: LightboxController!
    
    let images = [
        LightboxImage(title: "Bryan Nguyen", description: "yesterday at 18:28", image: UIImage(named: "photo2")!),
        LightboxImage(videoURL: URL(string: "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4")),
        LightboxImage(videoURL: URL(string: "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4")),
        LightboxImage(title: "Bryan Nguyen", description: "yesterday at 19:08", image: UIImage(named: "photo2")!),
        LightboxImage(title: "Bryan Nguyen", description: "yesterday at 22:21", image: UIImage(named: "photo2")!),
        LightboxImage(imageURL: URL(string: "https://picsum.photos/200/300")),
        LightboxImage(videoURL: URL(string: "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4")),
        LightboxImage(videoURL: URL(string: "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4")),
    ]
        
    lazy var showButton: UIButton = { [unowned self] in
        let button = UIButton()
        button.addTarget(self, action: #selector(showLightbox), for: .touchUpInside)
        button.setTitle("Show me the lightbox", for: UIControl.State())
        button.setTitleColor(UIColor(red:0.47, green:0.6, blue:0.13, alpha:1), for: UIControl.State())
        button.titleLabel?.font = UIFont(name: "AvenirNextCondensed-DemiBold", size: 30)
        button.frame = UIScreen.main.bounds
        button.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin, .flexibleRightMargin, .flexibleBottomMargin]
        
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin, .flexibleRightMargin, .flexibleBottomMargin]
        view.backgroundColor = UIColor.white
        view.addSubview(showButton)
        title = "Lightbox"
        LightboxConfig.preload = 3
        LightboxConfig.itemsToEnd = 5
    }
    
    // MARK: - Action methods
    
    @objc func showLightbox() {
        controller = LightboxController(images: images, startIndex: 3)
        controller.prelodMediaDelegate = self
        
        controller.modalPresentationStyle = .fullScreen
        present(controller, animated: true)
    }
}

extension ViewController: LightboxPreloadDelegate {
    func lightboxControllerUpdated(_ controller: LightboxController?) {
    }
    
    func lightboxControllerWillReachRightEnd(_ controller: LightboxController?) {
        print("lightboxControllerWillReachRightEnd")
        controller?.appendNewImages(images)
    }
    
    func lightboxControllerWillReachLeftEnd(_ controller: LightboxController?) {
        print("lightboxControllerWillReachLeftEnd")
        controller?.insertNewImages(images)
    }
}

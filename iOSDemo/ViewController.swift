import UIKit
import Lightbox

class ViewController: UIViewController {
  
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
    LightboxConfig.preload = 2
  }
  
  // MARK: - Action methods
  
    @objc func showLightbox() {
        let images = [
            LightboxImage(image: UIImage(named: "photo2")!, title: "Bryan Nguyen", description: "yesterday at 18:28"),
            LightboxImage(videoURL: URL(string: "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4")),
            LightboxImage(videoURL: URL(string: "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4")),
            LightboxImage(title: "Bryan Nguyen", description: "yesterday at 18:28", imageURL: URL(string: "https://media.giphy.com/media/Ku65904QQe4yez448B/giphy.gif")!),
            LightboxImage(title: "Bryan Nguyen", description: "AddInstanceForFactory: No factory registered for id",imageURL: URL(string: "https://media.giphy.com/media/lQDLwWUMPaAHvh8pAG/giphy.gif")!),
            LightboxImage(imageURL: URL(string: "https://media.giphy.com/media/ontKwPWJxARsuKaKqJ/giphy.gif")!)]
        
        let controller = LightboxController(images: images)
        //controller.dynamicBackground = true
        controller.modalPresentationStyle = .fullScreen
        present(controller, animated: true, completion: nil)
    }
}


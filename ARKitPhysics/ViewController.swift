//
//  ViewController.swift
//  ARKitPhysics
//
//  Created by mac126 on 2018/4/2.
//  Copyright © 2018年 mac126. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import Photos

class ViewController: UIViewController, RecordARDelegate, RenderARDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    @IBOutlet weak var toast: UIVisualEffectView!
    @IBOutlet weak var label: UILabel!
    
    var planeNodes = [SCNNode]()
    var chameleon = Chameleon()
    var lastScaleFactor: Float = 1.0
    
    var recorder:RecordAR?
    let recordingQueue = DispatchQueue(label: "recordingThread", attributes: .concurrent)
    
    @IBOutlet weak var segmentedControl: SegmentedControl!
    @IBOutlet weak var squishBtn: SquishButton!
    
    private var nowImage: UIImage!
    private var nowVedioUrl: URL!
    private var isVedio: Bool!
    
    fileprivate var player = Player()
    private weak var bgImageView: UIImageView!
    
    private let configuration = ARWorldTrackingConfiguration()
    
    deinit {
        self.player.willMove(toParentViewController: self)
        self.player.view.removeFromSuperview()
        self.player.removeFromParentViewController()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupPlayer()
        
        setupSceneView()
        
        configureLighting()
        addTapGestureToSceneView()
        addPanGestureToSceneView()
        addPinchGestureToSceneView()
        
        // 录制
        setUpRecordVideo()
        
        // 切换
        configureSegmentedControl()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Prepare the recorder with sessions configuration
        recorder?.prepare(configuration)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard ARWorldTrackingConfiguration.isSupported else {
            fatalError("设备不支持")
        }

        UIApplication.shared.isIdleTimerDisabled = true

        startNewSession()
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
        
        if recorder?.status == .recording {
            recorder?.stopAndExport()
        }
        recorder?.onlyRenderWhileRecording = true
        recorder?.prepare(ARWorldTrackingConfiguration())
        
        // Switch off the orientation lock for UIViewControllers with AR Scenes
        recorder?.rest()
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
    
    
    // MARK: - 初始化方法
    func setupPlayer() {
        self.player.view.frame = self.view.bounds
        self.addChildViewController(self.player)
        self.view.addSubview(self.player.view)
        self.player.didMove(toParentViewController: self)
        
        self.player.playbackLoops = true
        
        let bgImageView = UIImageView(frame: self.view.bounds)
        bgImageView.isHidden = true
        self.bgImageView = bgImageView
        
        self.player.view.addSubview(bgImageView)
        
        let cancelBtn = UIButton(type: .custom)
        cancelBtn.setImage(UIImage(named: "btn_cancel"), for: UIControlState.normal)
        cancelBtn.addTarget(self, action: #selector(self.btnAfreshDidClick(_:)), for: .touchUpInside)
        
        let insert:CGFloat = 50.0
        let y = self.view.bounds.height - 44/2 - insert
        cancelBtn.frame = CGRect(x: insert, y: y, width: 44, height: 44)
        self.player.view.addSubview(cancelBtn)
        
        let confirmBtn = UIButton(type: .custom)
        confirmBtn.setImage(UIImage(named: "btn_confirm"), for: UIControlState.normal)
        confirmBtn.addTarget(self, action: #selector(self.btnEnsureDidClick(_:)), for: .touchUpInside)
        
        let x = self.view.bounds.width - 44/2 - insert
        confirmBtn.frame = CGRect(x: x, y: y, width: 44, height: 44)
        self.player.view.addSubview(confirmBtn)
    }
    
    // MARK: - ARVideoKit
    func setUpRecordVideo() {
        // Initialize ARVideoKit recorder
        recorder = RecordAR(ARSceneKit: sceneView)
        
        /*----👇---- ARVideoKit Configuration ----👇----*/
        
        // Set the recorder's delegate
        recorder?.delegate = self
        
        // Set the renderer's delegate
        recorder?.renderAR = self
        
        // Configure the renderer to perform additional image & video processing 👁
        recorder?.onlyRenderWhileRecording = false
        
        // Configure ARKit content mode. Default is .auto
        recorder?.contentMode = .aspectFill
        
        // Set the UIViewController orientations
        recorder?.inputViewOrientations = [.landscapeLeft, .landscapeRight, .portrait]
        // Configure RecordAR to store media files in local app directory
        recorder?.deleteCacheWhenExported = false
    }
    
    // MARK: - SegmentedControl
    
    fileprivate func configureSegmentedControl() {
        let titleStrings = ["可拍照", "录视频"]
        let titles: [NSAttributedString] = {
            let attributes: [NSAttributedStringKey: Any] = [.font: UIFont.systemFont(ofSize: 15), .foregroundColor: UIColor.lightGray]
            var titles = [NSAttributedString]()
            for titleString in titleStrings {
                let title = NSAttributedString(string: titleString, attributes: attributes)
                titles.append(title)
            }
            return titles
        }()
        let selectedTitles: [NSAttributedString] = {
            let attributes: [NSAttributedStringKey: Any] = [.font: UIFont.systemFont(ofSize: 15), .foregroundColor: UIColor.white]
            var selectedTitles = [NSAttributedString]()
            for titleString in titleStrings {
                let selectedTitle = NSAttributedString(string: titleString, attributes: attributes)
                selectedTitles.append(selectedTitle)
            }
            return selectedTitles
        }()
        segmentedControl.setTitles(titles, selectedTitles: selectedTitles)
        segmentedControl.delegate = self
        segmentedControl.selectionBoxStyle = .none
        segmentedControl.minimumSegmentWidth = 375.0 / 4.0
        segmentedControl.selectionBoxColor = UIColor.clear
        segmentedControl.selectionIndicatorStyle = .none
        
        // segmentedControl.selectionIndicatorColor = UIColor(white: 0.3, alpha: 1)
    }
    
    // MARK: - Exported UIAlert present method
    func exportMessage(success: Bool, status:PHAuthorizationStatus) {
        if success {
            let alert = UIAlertController(title: "导出", message: "导出相册成功", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "ok", style: .cancel, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }else if status == .denied || status == .restricted || status == .notDetermined {
            let errorView = UIAlertController(title: "😅", message: "相册权限", preferredStyle: .alert)
            let settingsBtn = UIAlertAction(title: "OpenSettings", style: .cancel) { (_) -> Void in
                guard let settingsUrl = URL(string: UIApplicationOpenSettingsURLString) else {
                    return
                }
                if UIApplication.shared.canOpenURL(settingsUrl) {
                    if #available(iOS 10.0, *) {
                        UIApplication.shared.open(settingsUrl, completionHandler: { (success) in
                        })
                    } else {
                        UIApplication.shared.openURL(URL(string:UIApplicationOpenSettingsURLString)!)
                    }
                }
            }
            errorView.addAction(UIAlertAction(title: "Later", style: UIAlertActionStyle.default, handler: {
                (UIAlertAction)in
            }))
            errorView.addAction(settingsBtn)
            self.present(errorView, animated: true, completion: nil)
        }else{
            let alert = UIAlertController(title: "Exporting Failed", message: "There was an error while exporting your media file.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    // MARK: - 按钮点击
    @IBAction func recordVideo(_ sender: SquishButton) {
        if sender.type == ButtonType.camera {
            isVedio = false
            
            nowImage = self.recorder?.photo()
            self.player.url = Bundle.main.url(forResource: "a", withExtension: "mp4")
            self.player.playFromBeginning()
            self.player.pause()
            bgImageView.isHidden = false
            bgImageView.image = nowImage
            
        } else if sender.type == ButtonType.video {
            isVedio = true
            //Record
            if recorder?.status == .readyToRecord {
                sender.setTitle("停止", for: .normal)
                
                recordingQueue.async {
                    self.recorder?.record()
                }
            }else if recorder?.status == .recording {
                sender.setTitle("录制", for: .normal)
                recorder?.stop({ (url) in
                    DispatchQueue.main.async {
                        self.bgImageView.isHidden = true
                    }
                    
                    self.nowVedioUrl = url
                    self.player.url = url
                    self.player.playFromBeginning()
                })
            }
        }
    }
    
    @objc func btnAfreshDidClick(_ sender: UIButton) {
        self.player.pause()
        self.player.view.isHidden = true
    }
    
    @objc func btnEnsureDidClick(_ sender: UIButton) {
        if isVedio {
            recorder?.export(video: nowVedioUrl, { (saved, status) in
                DispatchQueue.main.sync {
                    self.exportMessage(success: saved, status: status)
                }
            })
            
        } else {
            self.recorder?.export(UIImage: nowImage) { saved, status in
                if saved {
                    self.exportMessage(success: saved, status: status)
                }
            }
        }
        
        self.player.pause()
        self.player.view.isHidden = true
        
    }
    
    
    func setupSceneView() {
        sceneView.delegate = self
        sceneView.scene = chameleon
        
        chameleon.hide()
        
        sceneView.showsStatistics = true
        sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
    }
    
    ///  启动世界追踪
    func startNewSession() {
        // 隐藏toast
        self.toast.alpha = 0
        self.toast.frame = self.toast.frame.insetBy(dx: 5, dy: 5)
        
        chameleon.hide()
        
        
        configuration.planeDetection = .horizontal

        sceneView.session.run(configuration, options: [.removeExistingAnchors, .resetTracking])
    }
    
    /// 添加单击和双击手势
    func addTapGestureToSceneView() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.switchAnimation(recognizer:)))
        tapGesture.numberOfTapsRequired = 1
        sceneView.addGestureRecognizer(tapGesture)
        
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(self.addChameleonToSceneView(recognizer:)))
        doubleTapGesture.numberOfTapsRequired = 2
        sceneView.addGestureRecognizer(doubleTapGesture)
        
        tapGesture.require(toFail: doubleTapGesture)
    }
    

    
    /// 添加拖拽手势
    func addPanGestureToSceneView() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(self.didPan(recognizer:)))
        sceneView.addGestureRecognizer(panGesture)
    }
    
    func addPinchGestureToSceneView() {
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(self.didPinch(recognizer:)))
        sceneView.addGestureRecognizer(pinchGesture)
    }
    
    func configureLighting() {
        // 是否自动更新场景的照明
        sceneView.automaticallyUpdatesLighting = true
        // 是否自动点亮没有光源的场景
        sceneView.autoenablesDefaultLighting = true
    }
    
    ///  添加恐龙
    @objc func addChameleonToSceneView(recognizer: UIGestureRecognizer) {
        
//        let tapLocation = recognizer.location(in: sceneView)
//        let hitTestResults = sceneView.hitTest(tapLocation, types: .existingPlaneUsingExtent)
//        guard let hitTestResult = hitTestResults.first else {
//            return
//        }
//
//        chameleon.setTransform(hitTestResult.worldTransform)
//        chameleon.show()
//
//        // 隐藏toast
//        DispatchQueue.main.async {
//            self.hideToast()
//        }
        
        startNewSession()
        
    }

    /// 切换动画
    @objc func switchAnimation(recognizer: UIGestureRecognizer) {
        let i = arc4random_uniform(10)
        if i % 2 == 0 {
            chameleon.turnRight()
        } else {
            chameleon.turnLeft()
        }
    }
    
    /// 手势拖拽
    @objc func didPan(recognizer: UIPanGestureRecognizer) {
        let location = recognizer.location(in: sceneView)
        
        let arHitTestResult = sceneView.hitTest(location, types: .existingPlane)
        if !arHitTestResult.isEmpty {
            let hit = arHitTestResult.first!
            chameleon.setTransform(hit.worldTransform)
        }
    }
    /// 捏合手势
    @objc func didPinch(recognizer: UIPinchGestureRecognizer) {
        
        print("didPinch")
        let factor = Float(recognizer.scale)
        print("factor", factor)
        if factor > 1 { // 放大
            chameleon.zoomWithScale(lastScaleFactor + factor - 1)
        } else { // 缩小
            chameleon.zoomWithScale(lastScaleFactor * factor)
        }
        
        if recognizer.state == UIGestureRecognizerState.ended {
            if factor > 1 {
                lastScaleFactor = lastScaleFactor + factor - 1
            } else {
                lastScaleFactor = lastScaleFactor * factor
            }
        }
    }
    
    // MARK: - button点击
    
    /// 返回
    @IBAction func backBtnDidClick(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    
}

// MARK: - ARSessionObserver
extension ViewController: ARSessionObserver {
    
    func sessionWasInterrupted(_ session: ARSession) {
        showToast("Session was interrupted")
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        startNewSession()
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        showToast("Session failed: \(error.localizedDescription)")
        startNewSession()
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        var message: String? = nil
        
        switch camera.trackingState {
        case .notAvailable:
            message = "无法找到合适水平面请调整手机位置"
        case .limited(.initializing):
            message = "初始化"
        case .limited(.excessiveMotion):
            message = "慢慢移动你的手机"
        case .limited(.insufficientFeatures):
            message = "尝试调亮灯光并稍作移动"
        case .normal:
            if !chameleon.isVisible() {
                message = "移动手机寻找水平面"
            }
        default:
            message = "Camera changed tracking state"
        }
        
        message != nil ? showToast(message!) : hideToast()
    }
}

// MARK: - ARSCNViewDelegate

extension ViewController: ARSCNViewDelegate {

    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else {
            return
        }
        // 创建平面
        let width = CGFloat(planeAnchor.extent.x)
        let height = CGFloat(planeAnchor.extent.z)
        let plane = SCNPlane(width: width, height: height)
        plane.materials.first?.diffuse.contents = UIColor.transparentWhite
        let planeNode = SCNNode(geometry: plane)
        
        planeNode.position = SCNVector3Make(planeAnchor.center.x, planeAnchor.center.y - 0.1, planeAnchor.center.z)
        planeNode.eulerAngles.x = -.pi / 2
        node.addChildNode(planeNode)
        planeNodes.append(planeNode)
        
//        DispatchQueue.main.async {
//            self.showToast("双击屏幕放置恐龙")
//        }
        
        
        if chameleon.isVisible() { return }
        if anchor is ARPlaneAnchor {
            
            chameleon.setTransform(anchor.transform)
            chameleon.show()
            
            DispatchQueue.main.async {
                self.hideToast()
            }
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        guard anchor is ARPlaneAnchor, let planeNode = node.childNodes.first  else {
            return
        }
        
        planeNodes = planeNodes.filter({ (node) -> Bool in
            node != planeNode
        })
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor,
            let planeNode = node.childNodes.first,
        let plane = planeNode.geometry as? SCNPlane else {
            return
        }
        
        let width = CGFloat(planeAnchor.extent.x)
        let height = CGFloat(planeAnchor.extent.z)
        plane.width = width
        plane.height = height
        
        planeNode.position = SCNVector3Make(planeAnchor.center.x, planeAnchor.center.y, planeAnchor.center.z)
    }

}

extension float4x4 {
    var translation: float3 {
        let translation = self.columns.3
        return float3(x: translation.x, y: translation.y, z: translation.z)
    }
}

extension UIColor {
    open class var transparentWhite: UIColor {
        return UIColor.white.withAlphaComponent(0.5)
    }
}

// MARK: - 展示和隐藏toast
extension ViewController {
    
    func showToast(_ text: String) {
        label.text = text
        
        guard toast.alpha == 0 else {
            return
        }
        
        toast.layer.masksToBounds = true
        toast.layer.cornerRadius = 7.5
        
        UIView.animate(withDuration: 0.25, animations: {
            self.toast.alpha = 1
            self.toast.frame = self.toast.frame.insetBy(dx: -5, dy: -5)
        })
        
    }
    
    func hideToast() {
        UIView.animate(withDuration: 0.25, animations: {
            self.toast.alpha = 0
            self.toast.frame = self.toast.frame.insetBy(dx: 5, dy: 5)
        })
    }  
}

// MARK: - ARVideoKit Delegate Methods

extension ViewController {
    func frame(didRender buffer: CVPixelBuffer, with time: CMTime, using rawBuffer: CVPixelBuffer) {
        // Do some image/video processing.
    }
    
    func recorder(didEndRecording path: URL, with noError: Bool) {
        if noError {
            // Do something with the video path.
            print("---", path)
        }
    }
    
    func recorder(didFailRecording error: Error?, and status: String) {
        // Inform user an error occurred while recording.
    }
    
    func recorder(willEnterBackground status: RecordARStatus) {
        // Use this method to pause or stop video recording. Check [applicationWillResignActive(_:)](https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1622950-applicationwillresignactive) for more information.
        if status == .recording {
            recorder?.stopAndExport()
        }
    }
}

// MARK: - SegmentedControlDelegate

extension ViewController: SegmentedControlDelegate {
    func segmentedControl(_ segmentedControl: SegmentedControl, didSelectIndex selectedIndex: Int) {
        print("Did select index \(selectedIndex)")
        switch segmentedControl.style {
        case .text:
            print("The title is “\(segmentedControl.titles[selectedIndex].string)”\n")
        case .image:
            print("The image is “\(segmentedControl.images[selectedIndex])”\n")
        }
        
        switch selectedIndex {
        case 0: //
            squishBtn.type = ButtonType.camera
        case 1:
            squishBtn.type = ButtonType.video
        default:
            print("hhhhh")
        }
    }
    
    func segmentedControl(_ segmentedControl: SegmentedControl, didLongPressIndex longPressIndex: Int) {
        print("Did long press index \(longPressIndex)")
        if UIDevice.current.userInterfaceIdiom == .pad {
            let viewController = UIViewController()
            viewController.modalPresentationStyle = .popover
            viewController.preferredContentSize = CGSize(width: 200, height: 300)
            if let popoverController = viewController.popoverPresentationController {
                popoverController.sourceView = view
                let yOffset: CGFloat = 10
                popoverController.sourceRect = view.convert(CGRect(origin: CGPoint(x: 70 * CGFloat(longPressIndex), y: yOffset), size: CGSize(width: 70, height: 30)), from: navigationItem.titleView)
                popoverController.permittedArrowDirections = .any
                present(viewController, animated: true, completion: nil)
            }
        } else {
            let message = segmentedControl.style == .text ? "Long press title “\(segmentedControl.titles[longPressIndex].string)”" : "Long press image “\(segmentedControl.images[longPressIndex])”"
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .actionSheet)
            let cancelAction = UIAlertAction(title: "OK", style: .cancel, handler: nil)
            alert.addAction(cancelAction)
            present(alert, animated: true, completion: nil)
        }
    }
}

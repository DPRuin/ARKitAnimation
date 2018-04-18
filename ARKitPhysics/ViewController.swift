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

class ViewController: UIViewController {

    @IBOutlet var sceneView: ARSCNView!
    
    @IBOutlet weak var toast: UIVisualEffectView!
    
    @IBOutlet weak var label: UILabel!
    
    var planeNodes = [SCNNode]()
    // let rocketshipNodeName = "rocketship"
    
    var chameleon = Chameleon()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureLighting()
        addTapGestureToSceneView()
        // addSwipeGestureToSceneView()
        addPanGestureToSceneView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupSceneView()
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
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
    
    
    // MARK: - 初始化方法
    
    func setupSceneView() {
        sceneView.delegate = self
        sceneView.scene = chameleon
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
    }
    
    ///  启动世界追踪
    func startNewSession() {
        // 隐藏toast
        self.toast.alpha = 0
        self.toast.frame = self.toast.frame.insetBy(dx: 5, dy: 5)
        
        chameleon.hide()
        
        let configuration = ARWorldTrackingConfiguration()
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
    
    func addSwipeGestureToSceneView() {
        let swipeUpGesture = UISwipeGestureRecognizer(target: self, action: #selector(self.applyForceToRocketship(recognizer:)))
        swipeUpGesture.direction = .up
        sceneView.addGestureRecognizer(swipeUpGesture)
        
        let swipeDownGesture = UISwipeGestureRecognizer(target: self, action: #selector(self.launchRocketship(recognizer:)))
        swipeDownGesture.direction = .down
        sceneView.addGestureRecognizer(swipeDownGesture)
    }
    
    /// 添加拖拽手势
    func addPanGestureToSceneView() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(self.didPan(recognizer:)))
        sceneView.addGestureRecognizer(panGesture)
    }
    
    func configureLighting() {
        // 是否自动更新场景的照明
        sceneView.automaticallyUpdatesLighting = true
        // 是否自动点亮没有光源的场景
        sceneView.autoenablesDefaultLighting = true
    }
    
    ///  添加恐龙
    @objc func addChameleonToSceneView(recognizer: UIGestureRecognizer) {
        let tapLocation = recognizer.location(in: sceneView)
        let hitTestResults = sceneView.hitTest(tapLocation, types: .existingPlaneUsingExtent)
        guard let hitTestResult = hitTestResults.first else {
            return
        }

        chameleon.setTransform(hitTestResult.worldTransform)
        chameleon.show()
        
    }

    /// 切换动画
    @objc func switchAnimation(recognizer: UIGestureRecognizer) {
        chameleon.turnRight()
    }
    
    /// 手势拖拽
    @objc func didPan(recognizer: UIGestureRecognizer) {
        let location = recognizer.location(in: sceneView)
        
        let arHitTestResult = sceneView.hitTest(location, types: .existingPlane)
        if !arHitTestResult.isEmpty {
            let hit = arHitTestResult.first!
            chameleon.setTransform(hit.worldTransform)
        }
    }
    
    /// 添加作用力
    @objc func applyForceToRocketship(recognizer: UIGestureRecognizer) {
        // 右转
        chameleon.turnRight()
    }
    
    /// 发射火箭
    @objc func launchRocketship(recognizer: UIGestureRecognizer) {
        // 恐龙左转
        chameleon.turnLeft()
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
        var planeNode = SCNNode(geometry: plane)
        
        planeNode.position = SCNVector3Make(planeAnchor.center.x, planeAnchor.center.y, planeAnchor.center.z)
        planeNode.eulerAngles.x = -.pi / 2
        // 更新平面刚体
        update(&planeNode, withGeometry: plane, type: .static)
        
        node.addChildNode(planeNode)
        
        planeNodes.append(planeNode)
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
        var planeNode = node.childNodes.first,
        let plane = planeNode.geometry as? SCNPlane else {
            return
        }
        
        let width = CGFloat(planeAnchor.extent.x)
        let height = CGFloat(planeAnchor.extent.z)
        plane.width = width
        plane.height = height
        
        planeNode.position = SCNVector3Make(planeAnchor.center.x, planeAnchor.center.y, planeAnchor.center.z)
        update(&planeNode, withGeometry: plane, type: .static)
    }
    
    // 更新平面节点的物理刚体
    func update(_ node: inout SCNNode, withGeometry geometry: SCNGeometry, type: SCNPhysicsBodyType)  {
        let shape = SCNPhysicsShape(geometry: geometry, options: nil)
        let physicsBody = SCNPhysicsBody(type: type, shape: shape)
        node.physicsBody = physicsBody
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

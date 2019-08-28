//
//  SceneController.swift
//  GCSample
//
//  Created by Toshihiro Goto on 2019/08/14.
//  Copyright © 2019 Toshihiro Goto. All rights reserved.
//

import SceneKit

// Collision bit masks
struct Bitmask: OptionSet {
    let rawValue: Int
    static let character = Bitmask(rawValue: 1 << 0) // the main character
    static let collision = Bitmask(rawValue: 1 << 1) // the ground and walls
    static let enemy = Bitmask(rawValue: 1 << 2) // the enemies
    static let trigger = Bitmask(rawValue: 1 << 3) // the box that triggers camera changes and other actions
    static let collectable = Bitmask(rawValue: 1 << 4) // the collectables (gems and key)
}

class SceneController: NSObject, SCNSceneRendererDelegate {
    
    // Global settings
    static let DefaultCameraTransitionDuration = 1.0
    static let NumberOfFiends = 100
    static let CameraOrientationSensitivity: Float = 0.05
    
    private var scene: SCNScene?
    private weak var sceneRenderer: SCNSceneRenderer?
    
    // Camera and targets
    private var cameraNode = SCNNode()
    private var lookAtTarget = SCNNode()
    private var lastActiveCamera: SCNNode?
    private var lastActiveCameraFrontDirection = simd_float3.zero
    private var activeCamera: SCNNode?
    private var playingCinematic: Bool = false
    
    private var constraints:Array<SCNConstraint>?
    
    // Character
    private var character: Character?
    
    // Game Object
    private var GameObject_pasteNode: SCNNode!
    private var GameObject_BoxCount = 0
    private var GameObject_BoxMaxCount = 5
    private var GameObject_Box: SCNNode!
    
    // Reset Scene
    private var ResetSceneCount = 0
    
    
    // MARK: - Controlling the character
    func controllerAttack() {
        if !self.character!.isAttacking {
            self.character!.attack()
        }
    }
    
    func controllerHide() {
        if !self.character!.isDisappear {
            self.character!.hideCharacter()
        }
    }
    
    // Put Box
    var isPutBox: Bool {
        return GameObject_BoxCount > 0
    }
    
    func putBox() {
        GameObject_BoxCount += 1
        
        let randomPosX:Float = Float.random(in: -8 ..< 6)
        print(randomPosX)
        
        GameObject_Box = scene?.rootNode.childNode(withName: "Box", recursively: true)!.clone()
        GameObject_Box.simdPosition = SIMD3<Float>(randomPosX, 4.0, 6.0)
        GameObject_Box.isHidden = false
        
        GameObject_pasteNode.addChildNode(GameObject_Box)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.GameObject_BoxCount -= 1
        }
    }
    
    func deletePutBox(){
        for node in GameObject_pasteNode.childNodes {
            node.removeFromParentNode()
        }
    }
    
    func controllerPutBox() {
        if !isPutBox {
            putBox()
        }
    }
    
    // Reset Scene
    var isResetSceneCount: Bool {
        return ResetSceneCount > 0
    }
    
    func controllerSceneReset() {
        if !isResetSceneCount {
            resetCharacter()
        }
    }
    
    
    func resetCharacter(){
        ResetSceneCount += 1
        
        setActiveCamera("reset Camera", animationDuration: 0)
        self.character!.resetCharacterPosision()
        
        let oldCameraNode = scene?.rootNode.childNode(withName: "camLookAt_cameraGame", recursively: true)
        oldCameraNode?.removeFromParentNode()
        
        let resetCameraNode = (scene?.rootNode.childNode(withName: "reset Camera", recursively: true)!.clone())!
        resetCameraNode.name = "camLookAt_cameraGame"
        resetCameraNode.constraints = constraints
        scene?.rootNode.addChildNode(resetCameraNode)
        
        self.setActiveCamera("camLookAt_cameraGame", animationDuration: 1)
        
        // Delete Box
        deletePutBox()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.ResetSceneCount -= 1
        }
    }
    
    var characterDirection: vector_float2 {
        get {
            return character!.direction
        }
        set {
            var direction = newValue
            let l = simd_length(direction)
            if l > 1.0 {
                direction *= 1 / l
            }
            character!.direction = direction
        }
    }
    
    // Camera
    var cameraDirection = vector_float2.zero {
        didSet {
            let l = simd_length(cameraDirection)
            if l > 1.0 {
                cameraDirection *= 1 / l
            }
            //cameraDirection.y = 0
        }
    }
    
    init(scnView: SCNView) {
        super.init()
        
        sceneRenderer = scnView
        sceneRenderer!.delegate = self
        scene = scnView.scene

        // setup character
        setupCharacter()
        
        setupGameObject()
        
        // setup camera
        setupCamera()
        
        //select the point of view to use
        sceneRenderer!.pointOfView = cameraNode
    }
    
    func setupCharacter() {
        character = Character(scene: scene!)
        
        // keep a pointer to the physicsWorld from the character because we will need it when updating the character's position
        character!.physicsWorld = scene!.physicsWorld
        scene!.rootNode.addChildNode(character!.node!)
    }
    
    func setupGameObject(){
        GameObject_pasteNode = SCNNode()
        scene?.rootNode.addChildNode(GameObject_pasteNode)
    }
    
    // the follow camera behavior make the camera to follow the character, with a constant distance, altitude and smoothed motion
    func setupFollowCamera(_ cameraNode: SCNNode) {
        
        // look at "lookAtTarget"
        let lookAtConstraint = SCNLookAtConstraint(target: self.lookAtTarget)
        lookAtConstraint.influenceFactor = 0.07
        lookAtConstraint.isGimbalLockEnabled = true
        
        // distance constraints
        let follow = SCNDistanceConstraint(target: self.lookAtTarget)
        let distance = CGFloat(simd_length(cameraNode.simdPosition))
        follow.minimumDistance = distance
        follow.maximumDistance = distance
        
        // configure a constraint to maintain a constant altitude relative to the character
        let desiredAltitude = abs(cameraNode.simdWorldPosition.y)
        weak var weakSelf = self
        
        let keepAltitude = SCNTransformConstraint.positionConstraint(inWorldSpace: true, with: {(_ node: SCNNode, _ position: SCNVector3) -> SCNVector3 in
            guard let strongSelf = weakSelf else { return position }
            var position = SIMD3<Float>(position)
            position.y = strongSelf.character!.baseAltitude + desiredAltitude
            return SCNVector3( position )
        })
        
        let accelerationConstraint = SCNAccelerationConstraint()
        accelerationConstraint.maximumLinearVelocity = 1500.0
        accelerationConstraint.maximumLinearAcceleration = 50.0
        accelerationConstraint.damping = 0.05
        
        // use a custom constraint to let the user orbit the camera around the character
        let transformNode = SCNNode()
        let orientationUpdateConstraint = SCNTransformConstraint(inWorldSpace: true) { (_ node: SCNNode, _ transform: SCNMatrix4) -> SCNMatrix4 in
            guard let strongSelf = weakSelf else { return transform }
            if strongSelf.activeCamera != node {
                return transform
            }
            
            // Slowly update the acceleration constraint influence factor to smoothly reenable the acceleration.
            accelerationConstraint.influenceFactor = min(1, accelerationConstraint.influenceFactor + 0.01)
            
            let targetPosition = strongSelf.lookAtTarget.presentation.simdWorldPosition
            let cameraDirection = strongSelf.cameraDirection
            if cameraDirection.allZero() {
                return transform
            }
            
            // Disable the acceleration constraint.
            accelerationConstraint.influenceFactor = 0
            
            let characterWorldUp = strongSelf.character?.node?.presentation.simdWorldUp
            
            transformNode.transform = transform
            
            let q = simd_mul(
                simd_quaternion(SceneController.CameraOrientationSensitivity * cameraDirection.x, characterWorldUp!),
                simd_quaternion(SceneController.CameraOrientationSensitivity * cameraDirection.y, transformNode.simdWorldRight)
            )
            
            transformNode.simdRotate(by: q, aroundTarget: targetPosition)
            return transformNode.transform
        }
        
        constraints = [follow, keepAltitude, accelerationConstraint, orientationUpdateConstraint, lookAtConstraint]
        
        cameraNode.constraints = constraints
    }
    
    func setupCameraNode(_ node: SCNNode) {
        guard let cameraName = node.name else { return }
        
        if cameraName.hasPrefix("camLookAt") {
            setupFollowCamera(node)
        }
    }
    
    func setupCamera() {
        
        //The lookAtTarget node will be placed slighlty above the character using a constraint
        weak var weakSelf = self
        
        self.lookAtTarget.constraints = [ SCNTransformConstraint.positionConstraint(
            inWorldSpace: true, with: { (_ node: SCNNode, _ position: SCNVector3) -> SCNVector3 in
                guard let strongSelf = weakSelf else { return position }
                
                guard var worldPosition = strongSelf.character?.node?.simdWorldPosition else { return position }
                worldPosition.y = strongSelf.character!.baseAltitude + 0.5
                return SCNVector3(worldPosition)
        })]
        
        self.scene?.rootNode.addChildNode(lookAtTarget)
        
        self.scene?.rootNode.enumerateHierarchy({(_ node: SCNNode, _ _: UnsafeMutablePointer<ObjCBool>) -> Void in
            if node.camera != nil {
                self.setupCameraNode(node)
            }
        })
        
        self.cameraNode.camera = SCNCamera()
        self.cameraNode.name = "mainCamera"
        self.cameraNode.camera!.zNear = 0.1
        self.scene!.rootNode.addChildNode(cameraNode)
        
        setActiveCamera("camLookAt_cameraGame", animationDuration: 0.0)
    }
    

    // MARK: - Camera transitions

    // transition to the specified camera
    // this method will reparent the main camera under the camera named "cameraNamed"
    // and trigger the animation to smoothly move from the current position to the new position
    func setActiveCamera(_ cameraName: String, animationDuration duration: CFTimeInterval) {
        
        guard let camera = scene?.rootNode.childNode(withName: cameraName, recursively: true) else { return }

        if self.activeCamera == camera {
            return
        }
        
        self.lastActiveCamera = activeCamera
        if activeCamera != nil {
            self.lastActiveCameraFrontDirection = (activeCamera?.presentation.simdWorldFront)!
        }
        self.activeCamera = camera
        
        // save old transform in world space
        let oldTransform: SCNMatrix4 = cameraNode.presentation.worldTransform

        // re-parent
        camera.addChildNode(cameraNode)

        // compute the old transform relative to our new parent node (yeah this is the complex part)
        let parentTransform = camera.presentation.worldTransform
        let parentInv = SCNMatrix4Invert(parentTransform)

        // with this new transform our position is unchanged in workd space (i.e we did re-parent but didn't move).
        cameraNode.transform = SCNMatrix4Mult(oldTransform, parentInv)

        // now animate the transform to identity to smoothly move to the new desired position
        SCNTransaction.begin()
        SCNTransaction.animationDuration = duration
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
            cameraNode.transform = SCNMatrix4Identity
        SCNTransaction.commit()
    }
    
    // MARK: - Update
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        
        guard (character != nil) else {
            return
        }
        character!.update(atTime: time, with: renderer)
    }
}

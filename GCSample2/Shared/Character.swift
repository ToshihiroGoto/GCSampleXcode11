//
//  Character.swift
//  GCSample
//
//  Created by Toshihiro Goto on 2019/08/13.
//  Copyright © 2019 Toshihiro Goto. All rights reserved.
//

import Foundation
import SceneKit
import simd

// Returns plane / ray intersection distance from ray origin.
func planeIntersect(planeNormal: SIMD3<Float>, planeDist: Float, rayOrigin: SIMD3<Float>, rayDirection: SIMD3<Float>) -> Float {
    return (planeDist - simd_dot(planeNormal, rayOrigin)) / simd_dot(planeNormal, rayDirection)
}

class Character: NSObject {
    
    enum GroundType: Int {
        case grass
        case rock
        case water
        case inTheAir
        case count
    }
    
    static private let speedFactor: CGFloat = 2.0
    static private let stepsCount = 10
    
    static private let initialPosition = SIMD3<Float>(0.0, -0.2, 0)
    
    // Character handle
    private var characterNode: SCNNode!
    private var characterOrientation: SCNNode!
    private var model: SCNNode!
    private var fireBallCount = 0
    private var fireBall_RefNode: SCNNode!
    
    private var scene:SCNScene!
    
    // some constants
    static private let gravity = Float(0.004)
    static private let minAltitude = Float(-10)
    static private let collisionMargin = Float(0.04)
    static private let modelOffset = SIMD3<Float>(0, -collisionMargin, 0)
    static private let collisionMeshBitMask = 8
    
    // actions
    var direction = SIMD2<Float>()
    var physicsWorld: SCNPhysicsWorld?
    
    // Physics
    private var characterCollisionShape: SCNPhysicsShape?
    private var collisionShapeOffsetFromModel = SIMD3<Float>.zero
    private var downwardAcceleration: Float = 0
    
    private var groundNode: SCNNode?
    private var groundNodeLastPosition = SIMD3<Float>.zero
    
    // void playing the step sound too often
    private var lastStepFrame: Int = 0
    private var frameCounter: Int = 0
    
    // states
    private var attackCount: Int = 0
    private var lastHitTime: TimeInterval = 0
    
    private var disappearCount: Int = 0
    private var greenCloudParticleNode: SCNNode!
    private var boostWalk:Float = 1
    
    // Particle systems
    private var spinParticle: SCNParticleSystem!
    private var spinCircleParticle: SCNParticleSystem!
    
    private var spinParticleAttach: SCNNode!
    
    var baseAltitude: Float = 0
    
    // Direction
    private var previousUpdateTime: TimeInterval = 0
    private var controllerDirection = SIMD2<Float>()
    
    init(scene: SCNScene) {
        super.init()
        
        loadCharacter()
        loadParticles()
        loadAnimations()
        
        self.scene = scene
    }
    
    private func loadCharacter() {
        /// Load character from external file
        let scene = SCNScene( named: "Art.scnassets/character/max.scn")!
        model = scene.rootNode.childNode( withName: "Max_rootNode", recursively: true)
        model.simdPosition = Character.modelOffset
        model.simdScale = SIMD3<Float>(repeating: 1.6)
        
        characterOrientation = SCNNode()
        characterOrientation.addChildNode(model)
        
        characterNode = SCNNode()
        characterNode.name = "character"
        characterNode.simdPosition = Character.initialPosition
        characterNode.addChildNode(characterOrientation)
        
        let collider = model.childNode(withName: "collider", recursively: true)!
        collider.physicsBody?.collisionBitMask = Int(([ .enemy, .trigger, .collectable ] as Bitmask).rawValue)
        
        // Setup collision shape
        let (min, max) = model.boundingBox
        let collisionCapsuleRadius = CGFloat(max.x - min.x) * CGFloat(0.4)
        let collisionCapsuleHeight = CGFloat(max.y - min.y)

        let collisionGeometry = SCNCapsule(capRadius: collisionCapsuleRadius, height: collisionCapsuleHeight)
        characterCollisionShape = SCNPhysicsShape(geometry: collisionGeometry, options:[.collisionMargin: Character.collisionMargin])
        collisionShapeOffsetFromModel = SIMD3<Float>(0, Float(collisionCapsuleHeight) * 0.51, 0.0)
        
        let fireBall_Scene = SCNScene(named: "Art.scnassets/particles/fireball.scn")!
        fireBall_RefNode = fireBall_Scene.rootNode.childNode(withName: "FireBall", recursively: true)!
    }
    
    // MARK: - Controlling the character
    
    private var directionAngle: CGFloat = 0.0 {
        didSet {
            characterOrientation.runAction(
                SCNAction.rotateTo(x: 0.0, y: directionAngle, z: 0.0, duration: 0.1, usesShortestUnitArc:true))
        }
    }
    
    func update(atTime time: TimeInterval, with renderer: SCNSceneRenderer) {
        frameCounter += 1
        
        var characterVelocity = SIMD3<Float>.zero
        
        // setup
        //var groundMove = SIMD3<Float>.zero
        
        let direction = characterDirection(withPointOfView:renderer.pointOfView)

        if previousUpdateTime == 0.0 {
            previousUpdateTime = time
        }
        
        let deltaTime = time - previousUpdateTime
        let characterSpeed = CGFloat(deltaTime) * Character.speedFactor * walkSpeed
        previousUpdateTime = time
        
        // move
        if !direction.allZero() {
            characterVelocity = direction * Float(characterSpeed)
            
            walkSpeed = CGFloat(simd_length(direction) * boostWalk)
            
            // move character
            directionAngle = CGFloat(atan2f(direction.x, direction.z))
            
            isWalking = true
        } else {
            isWalking = false
        }
        
        if simd_length_squared(characterVelocity) > 10E-4 * 10E-4 {
            let startPosition = characterNode!.presentation.simdWorldPosition + collisionShapeOffsetFromModel
            slideInWorld(fromPosition: startPosition, velocity: characterVelocity)
        }
    }
    
    private func loadAnimations() {
        let idleAnimation = Character.loadAnimation(fromSceneNamed: "Art.scnassets/character/max_idle.scn")
        model.addAnimationPlayer(idleAnimation, forKey: "idle")
        idleAnimation.play()
        
        let walkAnimation = Character.loadAnimation(fromSceneNamed: "Art.scnassets/character/max_walk.scn")
        walkAnimation.speed = Character.speedFactor
        walkAnimation.stop()
        
        walkAnimation.animation.animationEvents = [
            SCNAnimationEvent(keyTime: 0.1, block: { _, _, _ in }),
            SCNAnimationEvent(keyTime: 0.6, block: { _, _, _ in })
        ]
        model.addAnimationPlayer(walkAnimation, forKey: "walk")
        
        let jumpAnimation = Character.loadAnimation(fromSceneNamed: "Art.scnassets/character/max_jump.scn")
        jumpAnimation.animation.isRemovedOnCompletion = false
        jumpAnimation.stop()
        jumpAnimation.animation.animationEvents = [SCNAnimationEvent(keyTime: 0, block: { _, _, _ in })]
        model.addAnimationPlayer(jumpAnimation, forKey: "jump")
        
        let spinAnimation = Character.loadAnimation(fromSceneNamed: "Art.scnassets/character/max_spin.scn")
        spinAnimation.animation.isRemovedOnCompletion = false
        spinAnimation.speed = 1.5
        spinAnimation.stop()
        spinAnimation.animation.animationEvents = [SCNAnimationEvent(keyTime: 0, block: { _, _, _ in })]
        model!.addAnimationPlayer(spinAnimation, forKey: "spin")
    }

    // MARK: - Animation: Walk
    var isWalking: Bool = false {
        didSet {
            if oldValue != isWalking {
                // Update node animation.
                if isWalking {
                    model.animationPlayer(forKey: "walk")?.play()
                } else {
                    model.animationPlayer(forKey: "walk")?.stop(withBlendOutDuration: 0.2)
                }
            }
        }
    }
    
    var walkSpeed: CGFloat = 1.0 {
        didSet {
            model.animationPlayer(forKey: "walk")?.speed = Character.speedFactor * walkSpeed
        }
    }
    
    func characterDirection(withPointOfView pointOfView: SCNNode?) -> SIMD3<Float> {
        let controllerDir = self.direction
        if controllerDir.allZero() {
            return SIMD3<Float>.zero
        }
        
        var directionWorld = SIMD3<Float>.zero
        if let pov = pointOfView {
            let p1 = pov.presentation.simdConvertPosition(SIMD3<Float>(controllerDir.x, 0.0, controllerDir.y), to: nil)
            let p0 = pov.presentation.simdConvertPosition(SIMD3<Float>.zero, to: nil)
            directionWorld = p1 - p0
            directionWorld.y = 0
            if simd_any(directionWorld != SIMD3<Float>()) {
                let minControllerSpeedFactor = Float(0.2)
                let maxControllerSpeedFactor = Float(1.0)
                let speed = simd_length(controllerDir) * (maxControllerSpeedFactor - minControllerSpeedFactor) + minControllerSpeedFactor
                directionWorld = speed * simd_normalize(directionWorld)
            }
        }
        return directionWorld
    }
    
    private func loadParticles() {
        //greenCloudParticle
        let greenParticleScene = SCNScene(named:"Art.scnassets/particles/cloud_green.scn")!
        greenCloudParticleNode = greenParticleScene.rootNode.childNode(withName: "particle", recursively:true)!
    }
    
    // MARK: utils
    class func loadAnimation(fromSceneNamed sceneName: String) -> SCNAnimationPlayer {
        let scene = SCNScene( named: sceneName )!
        // find top level animation
        var animationPlayer: SCNAnimationPlayer! = nil
        scene.rootNode.enumerateChildNodes { (child, stop) in
            if !child.animationKeys.isEmpty {
                animationPlayer = child.animationPlayer(forKey: child.animationKeys[0])
                stop.pointee = true
            }
        }
        return animationPlayer
    }
    
    var node: SCNNode! {
        return characterNode
    }
    
    
    // MARK: - physics contact
    func slideInWorld(fromPosition start: SIMD3<Float>, velocity: SIMD3<Float>) {
        let maxSlideIteration: Int = 4
        var iteration = 0
        var stop: Bool = false
        
        var replacementPoint = start
        
        var start = start
        var velocity = velocity
        let options: [SCNPhysicsWorld.TestOption: Any] = [
            SCNPhysicsWorld.TestOption.collisionBitMask: Bitmask.collision.rawValue,
            SCNPhysicsWorld.TestOption.searchMode: SCNPhysicsWorld.TestSearchMode.closest]
        while !stop {
            var from = matrix_identity_float4x4
            from.position = start
            
            var to: matrix_float4x4 = matrix_identity_float4x4
            to.position = start + velocity
            
            let contacts = physicsWorld!.convexSweepTest(
                with: characterCollisionShape!,
                from: SCNMatrix4(from),
                to: SCNMatrix4(to),
                options: options)
            if !contacts.isEmpty {
                (velocity, start) = handleSlidingAtContact(contacts.first!, position: start, velocity: velocity)
                iteration += 1
                
                if simd_length_squared(velocity) <= (10E-3 * 10E-3) || iteration >= maxSlideIteration {
                    replacementPoint = start
                    stop = true
                }
            } else {
                replacementPoint = start + velocity
                stop = true
            }
        }
        characterNode!.simdWorldPosition = replacementPoint - collisionShapeOffsetFromModel
    }
    
    private func handleSlidingAtContact(_ closestContact: SCNPhysicsContact, position start: SIMD3<Float>, velocity: SIMD3<Float>)
        -> (computedVelocity: SIMD3<Float>, colliderPositionAtContact: SIMD3<Float>) {
            let originalDistance: Float = simd_length(velocity)
            
            let colliderPositionAtContact = start + Float(closestContact.sweepTestFraction) * velocity
            
            // Compute the sliding plane.
            let slidePlaneNormal = SIMD3<Float>(closestContact.contactNormal)
            let slidePlaneOrigin = SIMD3<Float>(closestContact.contactPoint)
            let centerOffset = slidePlaneOrigin - colliderPositionAtContact
            
            // Compute destination relative to the point of contact.
            let destinationPoint = slidePlaneOrigin + velocity
            
            // We now project the destination point onto the sliding plane.
            let distPlane = simd_dot(slidePlaneOrigin, slidePlaneNormal)
            
            // Project on plane.
            var t = planeIntersect(planeNormal: slidePlaneNormal, planeDist: distPlane,
                                   rayOrigin: destinationPoint, rayDirection: slidePlaneNormal)
            
            let normalizedVelocity = velocity * (1.0 / originalDistance)
            let angle = simd_dot(slidePlaneNormal, normalizedVelocity)
            
            var frictionCoeff: Float = 0.3
            if abs(angle) < 0.9 {
                t += 10E-3
                frictionCoeff = 1.0
            }
            let newDestinationPoint = (destinationPoint + t * slidePlaneNormal) - centerOffset
            
            // Advance start position to nearest point without collision.
            let computedVelocity = frictionCoeff * Float(1.0 - closestContact.sweepTestFraction)
                * originalDistance * simd_normalize(newDestinationPoint - start)
            
            return (computedVelocity, colliderPositionAtContact)
    }
}

// MARK: - Action
extension Character{
    
    var isAttacking: Bool {
        return attackCount > 0
    }
    
    func attack() {
        attackCount += 1
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.attackCount -= 1
        }
        
        let shotPointNode = SCNNode()
        let fireBallNode = fireBall_RefNode.clone()
        
        let rotation = characterOrientation.simdRotation
        
        shotPointNode.simdTransform = characterNode.simdWorldTransform
        shotPointNode.simdRotation = rotation
        shotPointNode.addChildNode(fireBallNode)
        scene.rootNode.addChildNode(shotPointNode)
        
        var scale:Float = 3.0
        var posY:Float = 0.4
        var posZ:Float = 0.6
        
        if fireBallCount >= 3 {
            scale = 10
            posY = 0.6
            posZ = 1.6
            fireBallCount = 0
        }
        fireBallCount += 1
        
        fireBallNode.simdPosition = SIMD3<Float>(0, posY, posZ)
        fireBallNode.simdScale = SIMD3<Float>(repeating: scale)
        shotPointNode.addChildNode(fireBallNode)
        
        fireBallNode.runAction(SCNAction.group([
            SCNAction.move(by: SCNVector3(0,0,6), duration: 2.0),
            SCNAction.sequence([
                SCNAction.wait(duration: 1.8),
                SCNAction.fadeOut(duration: 0.2)
                ])
            ])
            
            , completionHandler: {
                shotPointNode.removeFromParentNode()
        })
        
        // collider
        let ball = fireBallNode.childNode(withName: "Ball", recursively: true)!
        let collider = SCNNode(geometry: SCNSphere(radius: 0.13))
        collider.simdPosition = SIMD3<Float>(0, posY, posZ)
        collider.simdScale = SIMD3<Float>(repeating: scale)
        
        let colliderShape = SCNPhysicsShape(node: collider, options: [:])
        
        let colliderBody = SCNPhysicsBody(type: .kinematic, shape: colliderShape)
        colliderBody.categoryBitMask = 3
        colliderBody.collisionBitMask = 1
        ball.physicsBody = colliderBody
    }
    
    var isDisappear: Bool {
        return disappearCount > 0
    }
    
    func hideCharacter() {
        disappearCount += 1
        
        boostWalk = 4
        model.opacity = 0
        setGreenParticle()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.disappearCount -= 1
            
            self.boostWalk = 1
            self.model.opacity = 1
            self.setGreenParticle()
        }
    }
    
    func setGreenParticle(){
        let node = SCNNode()
        node.simdPosition = model.simdWorldPosition
        node.simdPosition.y += 0.3
        node.addParticleSystem(greenCloudParticleNode.particleSystems!.first!)
        node.runAction(SCNAction.sequence([
            SCNAction.wait(duration: 0.8),
            SCNAction.removeFromParentNode()
            ]))
        scene.rootNode.addChildNode(node)
    }
    
    func resetCharacterPosision(){
        characterOrientation.simdRotation = SIMD4<Float>(repeating: 0)
        characterNode.simdWorldPosition = Character.initialPosition
    }
}

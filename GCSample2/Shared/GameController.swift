//
//  GameController.swift
//  GCSample
//
//  Created by Toshihiro Goto on 2019/08/24.
//  Copyright © 2019 Toshihiro Goto. All rights reserved.
//

import GameController
import SceneKit

class GameController: SceneController {
    
    init(view: SCNView) {
        super.init(scnView: view)
        
        setupGameController()
    }
    
    
    // Setup: Game Controller
    func setupGameController() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(self.handleControllerDidConnect),
            name: NSNotification.Name.GCControllerDidConnect, object: nil)
        
        NotificationCenter.default.addObserver(
            self, selector: #selector(self.handleControllerDidDisconnect),
            name: NSNotification.Name.GCControllerDidDisconnect, object: nil)
        
        guard let controller = GCController.controllers().first else {
            return
        }
        registerGameController(controller)
    }
    
    // Notification: Connection
    @objc
    func handleControllerDidConnect(_ notification: Notification){
        print("ゲームコントローラーの接続が通知されました")

        guard let gameController = notification.object as? GCController else {
            return
        }

        registerGameController(gameController)
    }
    
    // Notification: Disconnection
    @objc
    func handleControllerDidDisconnect(_ notification: Notification){
        print("ゲームコントローラーの切断が通知されました")
        
        guard let gameController = notification.object as? GCController else {
            return
        }
        
        unregisterGameController()

        for controller: GCController in GCController.controllers() where gameController != controller {
            registerGameController(controller)
        }
    }

    // Connection
    func registerGameController(_ gameController: GCController){
        print("ゲームコントローラーが接続されました")
        print("Name: \(gameController.vendorName!)")
        print("Category: \(gameController.productCategory)")
        
        var leftThumbstick:  GCControllerDirectionPad?
        var rightThumbstick: GCControllerDirectionPad?
        var directionPad:    GCControllerDirectionPad?
        
        var buttonA: GCControllerButtonInput?
        var buttonB: GCControllerButtonInput?
        var buttonX: GCControllerButtonInput?
        var buttonY: GCControllerButtonInput?
        
        var leftShoulder:  GCControllerButtonInput?
        var rightShoulder: GCControllerButtonInput?
        var leftTrigger:   GCControllerButtonInput?
        var rightTrigger:  GCControllerButtonInput?
        
        var buttonMenu:    GCControllerButtonInput?
        var buttonOptions: GCControllerButtonInput?
        
        // Extended Gamepad
        if let gamepad = gameController.extendedGamepad {
            
            directionPad    = gamepad.dpad
            leftThumbstick  = gamepad.leftThumbstick
            rightThumbstick = gamepad.rightThumbstick
            
            buttonA = gamepad.buttonA
            buttonB = gamepad.buttonB
            buttonX = gamepad.buttonX
            buttonY = gamepad.buttonY

            leftShoulder  = gamepad.leftShoulder
            rightShoulder = gamepad.rightShoulder
            leftTrigger   = gamepad.leftTrigger
            rightTrigger  = gamepad.rightTrigger

            buttonMenu    = gamepad.buttonMenu
            buttonOptions = gamepad.buttonOptions
            
        // Micro Controller (Siri Remote)
        }else if let gamepad = gameController.microGamepad {
            // Support Rotation
            gamepad.allowsRotation = true
            
            directionPad = gamepad.dpad
            buttonA = gamepad.buttonA
            buttonB = gamepad.buttonX
            
            buttonMenu = gamepad.buttonMenu
        }
        
        // Direction Pad
        directionPad!.valueChangedHandler = directionPadValue()
                
        // Stick
        if leftThumbstick != nil {
            leftThumbstick!.valueChangedHandler = directionPadValue()
        }
        
        if rightThumbstick != nil {
            rightThumbstick!.valueChangedHandler = cameraDirection()
        }
        
        // Buttons
        buttonMenu!.valueChangedHandler = buttonResetScene()
        buttonA!.valueChangedHandler = buttonAttack()
        buttonB!.valueChangedHandler = buttonHide()
        
        if buttonX != nil {
            buttonX!.valueChangedHandler = buttonPutBox()
        }
        
        if buttonY != nil {
            buttonY!.valueChangedHandler = buttonResetScene()
        }
        
        // Shoulder
        if leftTrigger != nil {
            leftShoulder!.valueChangedHandler = buttonHide()
        }
        
        if leftTrigger != nil {
            rightShoulder!.valueChangedHandler = buttonHide()
        }
        
        // Trigger
        if leftTrigger != nil {
            leftTrigger!.valueChangedHandler = buttonAttack()
        }
        
        if rightTrigger != nil {
            rightTrigger!.valueChangedHandler = buttonAttack()
        }
        
        // Option
        if buttonOptions != nil {
            buttonOptions!.valueChangedHandler = buttonPutBox()
        }
    }
    
    // Disconnection
    func unregisterGameController() {
        print("ゲームコントローラーが切断されました")
    }
    
    // Closure: DirectionPad
    func directionPadValue() -> GCControllerDirectionPadValueChangedHandler {
        return {(_ dpad: GCControllerDirectionPad, _ xValue: Float, _ yValue: Float) -> Void in
            self.characterDirection = SIMD2<Float>(xValue, -yValue)
        }
    }
    
    // Closure: Camera Direction
    func cameraDirection() -> GCControllerDirectionPadValueChangedHandler {
        return {(_ dpad: GCControllerDirectionPad, _ xValue: Float, _ yValue: Float) -> Void in
            self.cameraDirection = SIMD2<Float>(xValue, yValue)
        }
    }
    
    // Closure: Attack
    func buttonAttack() -> GCControllerButtonValueChangedHandler {
        return {(_ button: GCControllerButtonInput, _ value: Float, _ pressed: Bool) -> Void in
            self.controllerAttack()
        }
    }
    
    // Closure: Hide
    func buttonHide() -> GCControllerButtonValueChangedHandler {
        return {(_ button: GCControllerButtonInput, _ value: Float, _ pressed: Bool) -> Void in
            self.controllerHide()
        }
    }
    
    // Closure: Put Box
    func buttonPutBox() -> GCControllerButtonValueChangedHandler {
        return {(_ button: GCControllerButtonInput, _ value: Float, _ pressed: Bool) -> Void in
            self.controllerPutBox()
        }
    }
    
    // Closure: Reset Scene
    func buttonResetScene() -> GCControllerButtonValueChangedHandler {
        return {(_ button: GCControllerButtonInput, _ value: Float, _ pressed: Bool) -> Void in
            self.controllerSceneReset()
        }
    }
}

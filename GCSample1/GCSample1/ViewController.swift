//
//  ViewController.swift
//  GCSample1
//
//  Created by Toshihiro Goto on 2019/08/24.
//  Copyright © 2019 Toshihiro Goto. All rights reserved.
//

import Cocoa
import GameController

class ViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

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
        
        unregisterGameController()
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
        
        var leftThumbstickButton:  GCControllerButtonInput?
        var rightThumbstickButton: GCControllerButtonInput?
        
        var buttonMenu:    GCControllerButtonInput?
        var buttonOptions: GCControllerButtonInput?
        
        if let gamepad = gameController.extendedGamepad {
            
            print("isSnapshot: \(gameController.isSnapshot)")
            print("isAttachedToDevice: \(gameController.isAttachedToDevice)")
            
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
            
            leftThumbstickButton  = gamepad.leftThumbstickButton
            rightThumbstickButton = gamepad.rightThumbstickButton
            
            buttonMenu    = gamepad.buttonMenu
            buttonOptions = gamepad.buttonOptions
            
        }
        
        leftThumbstick!.valueChangedHandler = printDirectionPadValue("leftThumbstick")
        rightThumbstick!.valueChangedHandler = printDirectionPadValue("rightThumbstick")
        directionPad!.valueChangedHandler = printDirectionPadValue("directionPad")
        
        buttonA!.valueChangedHandler = printButtonValue("buttonA")
        buttonB!.valueChangedHandler = printButtonValue("buttonB")
        buttonX!.valueChangedHandler = printButtonValue("buttonX")
        buttonY!.valueChangedHandler = printButtonValue("buttonY")
        
        leftShoulder!.valueChangedHandler = printButtonValue("leftShoulder")
        rightShoulder!.valueChangedHandler = printButtonValue("rightShoulder")
        leftTrigger!.valueChangedHandler = printButtonValue("leftTrigger")
        rightTrigger!.valueChangedHandler = printButtonValue("rightTrigger")
        
        leftThumbstickButton!.valueChangedHandler = printButtonValue("leftThumbstickButton")
        rightThumbstickButton!.valueChangedHandler = printButtonValue("rightThumbstickButton")
        
        buttonMenu!.valueChangedHandler = printButtonValue("buttonMenu")
        buttonOptions!.valueChangedHandler = printButtonValue("buttonOptions")
    }
    
    // Disconnection
    func unregisterGameController() {
        print("ゲームコントローラーが切断されました")
    }
    
    // Closure: DirectionPad
    func printDirectionPadValue(_ text:String) -> GCControllerDirectionPadValueChangedHandler {
        return {(_ dpad: GCControllerDirectionPad, _ xValue: Float, _ yValue: Float) -> Void in
            print("\(text) x:\(xValue), y:\(-yValue)")
        }
    }
    
    // Closure: Button
    func printButtonValue(_ text:String) -> GCControllerButtonValueChangedHandler {
        return {(_ button: GCControllerButtonInput, _ value: Float, _ pressed: Bool) -> Void in
            print("\(text) value:\(value), pressed:\(pressed)")
        }
    }
        
    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
}


//
//  GameViewController.swift
//  GCSample2
//
//  Created by Toshihiro Goto on 2019/08/29.
//  Copyright © 2019 Toshihiro Goto. All rights reserved.
//

import SceneKit

class GameViewController: NSViewController{
    
    var sceneController: SceneController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // create a new scene
        let scene = SCNScene(named: "Art.scnassets/scene/main.scn")
        
        // retrieve the SCNView
        let scnView = self.view as! SCNView
        
        scnView.scene = scene
        scnView.showsStatistics = true
        scnView.backgroundColor = NSColor.black
    
        sceneController = GameController(view: scnView)
        
        // Event
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            self.keyDown(with: $0)
            return $0
        }
        
        NSEvent.addLocalMonitorForEvents(matching: .keyUp) {
            self.keyUp(with: $0)
            return $0
        }
    }
    
    override func keyDown(with theEvent: NSEvent) {
        var characterDirection = self.sceneController!.characterDirection
        var cameraDirection = self.sceneController!.cameraDirection
        
        var updateCamera = false
        var updateCharacter = false
        
        let keyCode = theEvent.keyCode
        print(keyCode)
        
        switch keyCode {
        case 126:
            // Up
            if !theEvent.isARepeat {
                characterDirection.y = -1
                updateCharacter = true
            }
        case 125:
            // Down
            if !theEvent.isARepeat {
                characterDirection.y = 1
                updateCharacter = true
            }
        case 123:
            // Left
            if !theEvent.isARepeat {
                characterDirection.x = -1
                updateCharacter = true
            }
        case 124:
            // Right
            if !theEvent.isARepeat {
                characterDirection.x = 1
                updateCharacter = true
            }
        case 13:
            // Camera Up
            if !theEvent.isARepeat {
                cameraDirection.y = 1
                updateCamera = true
            }
        case 1:
            // Camera Down
            if !theEvent.isARepeat {
                cameraDirection.y = -1
                updateCamera = true
            }
        case 0:
            // Camera Left
            if !theEvent.isARepeat {
                cameraDirection.x = -1
                updateCamera = true
            }
        case 2:
            // Camera Right
            if !theEvent.isARepeat {
                cameraDirection.x = 1
                updateCamera = true
            }
        case 49:
            // Space
            if !theEvent.isARepeat {
                sceneController!.resetCharacter()
            }
        case 6:
            // z
            if !theEvent.isARepeat {
                sceneController!.controllerAttack()
            }
        case 7:
            // x
            if !theEvent.isARepeat {
                sceneController!.controllerHide()
            }
        case 8:
            // c
            if !theEvent.isARepeat {
                sceneController!.controllerPutBox()
            }
        default:
            break
        }
        
        if updateCharacter {
            self.sceneController?.characterDirection = characterDirection.allZero() ? characterDirection: simd_normalize(characterDirection)
        }

        if updateCamera {
            self.sceneController?.cameraDirection = cameraDirection.allZero() ? cameraDirection: simd_normalize(cameraDirection)
        }
    }
    
    override func keyUp(with theEvent: NSEvent) {
        var characterDirection = self.sceneController!.characterDirection
        var cameraDirection = self.sceneController!.cameraDirection
        
        var updateCamera = false
        var updateCharacter = false
        
        switch theEvent.keyCode {
        case 36:
            if !theEvent.isARepeat {
                //sceneController!.resetPlayerPosition()
            }
        case 126:
            // Up
            if !theEvent.isARepeat && characterDirection.y < 0 {
                characterDirection.y = 0
                updateCharacter = true
            }
        case 125:
            // Down
            if !theEvent.isARepeat && characterDirection.y > 0 {
                characterDirection.y = 0
                updateCharacter = true
            }
        case 123:
            // Left
            if !theEvent.isARepeat && characterDirection.x < 0 {
                characterDirection.x = 0
                updateCharacter = true
            }
        case 124:
            // Right
            if !theEvent.isARepeat && characterDirection.x > 0 {
                characterDirection.x = 0
                updateCharacter = true
            }
        case 13:
            // Camera Up
            if !theEvent.isARepeat && cameraDirection.y > 0 {
                cameraDirection.y = 0
                updateCamera = true
            }
        case 1:
            // Camera Down
            if !theEvent.isARepeat && cameraDirection.y < 0 {
                cameraDirection.y = 0
                updateCamera = true
            }
        case 0:
            // Camera Left
            if !theEvent.isARepeat && cameraDirection.x < 0 {
                cameraDirection.x = 0
                updateCamera = true
            }
        case 2:
            // Camera Right
            if !theEvent.isARepeat && cameraDirection.x > 0 {
                cameraDirection.x = 0
                updateCamera = true
            }
        default:
            break
        }
        
        if updateCharacter {
            self.sceneController?.characterDirection = characterDirection.allZero() ? characterDirection: simd_normalize(characterDirection)
        }
        
        if updateCamera {
            self.sceneController?.cameraDirection = cameraDirection.allZero() ? cameraDirection: simd_normalize(cameraDirection)
        }
    }
}

//
//  GameViewController.swift
//  GCSample2
//
//  Created by Toshihiro Goto on 2019/08/29.
//  Copyright © 2019 Toshihiro Goto. All rights reserved.
//

import UIKit
import QuartzCore
import SceneKit

class GameViewController: UIViewController {

    var sceneController: SceneController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // create a new scene
        let scene = SCNScene(named: "Art.scnassets/scene/main.scn")
        
        // retrieve the SCNView
        let scnView = self.view as! SCNView
        
        // Configure the view
        scnView.scene = scene
        scnView.showsStatistics = true
        scnView.backgroundColor = UIColor.black
        
        sceneController = GameController(view: scnView)
    }
}

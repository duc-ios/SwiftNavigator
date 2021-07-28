//
//  ViewController.swift
//  SwiftNavigator
//
//  Created by Duc iOS on 07/28/2021.
//  Copyright (c) 2021 Duc iOS. All rights reserved.
//

import UIKit
import SwiftNavigator

class ViewController: UIViewController {
    
    lazy var stackView = UIStackView(arrangedSubviews: [pushButton, showButton])
    let pushButton = UIButton(type: .system)
    let showButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        
        stackView.axis = .vertical
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)
        
        stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        
        pushButton.setTitle("Push", for: [])
        pushButton.addAction(UIAction(handler: { _ in
            Navigator.push(Scene.sceneA())
        }), for: .touchUpInside)
        
        showButton.setTitle("Show", for: [])
        showButton.addAction(UIAction(handler: { _ in
            Navigator.show(Scene.sceneB())
        }), for: .touchUpInside)
    }
    
}

struct Scene: SceneProtocol {
    let scene: UIViewController
    var sceneWithNav: UINavigationController { UINavigationController(rootViewController: scene) }
    init(_ scene: UIViewController) {
        self.scene = scene
    }
}

extension Scene {
    static let root = Scene(ViewController())
    static func sceneA() -> Scene {
        let scene = UIViewController()
        scene.view.backgroundColor = .orange
        return Scene(scene)
    }
    static func sceneB() -> Scene {
        let scene = UIViewController()
        scene.view.backgroundColor = .blue
        scene.view.addGestureRecognizer(UITapGestureRecognizer(target: scene, action: #selector(UIViewController.close)))
        return Scene(scene)
    }
}

extension UIViewController {
    @objc func close() { dismiss(animated: true, completion: nil) }
}

//
//  SceneDelegate.swift
//  Salat
//
//  Created by Parsa Saraydarpour on 4/10/21.
//

import UIKit

var mainWindow: UIWindow?

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let windowScene = scene as? UIWindowScene {
            mainWindow = UIWindow(frame: windowScene.coordinateSpace.bounds)
            mainWindow?.windowScene = windowScene
            mainWindow?.backgroundColor = UIColor(named: "Background")
            mainWindow?.rootViewController = ViewController()
            mainWindow?.makeKeyAndVisible()
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        
    }

    func sceneWillResignActive(_ scene: UIScene) {
        
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        
    }
}


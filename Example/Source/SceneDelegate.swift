//
//  SceneDelegate.swift
//  iOS Example
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UINavigationController(rootViewController: ViewController())
        window.makeKeyAndVisible()
        self.window = window

        // The OAuth callback URL is intercepted directly by ASWebAuthenticationSession
        // (via CDYahooAuthSession) and never reaches this scene delegate.
    }
}

//
//  SceneDelegate.swift
//  iOS (App)
//
//  Created by i on 7/25/26.
//

import UIKit

/// Connects the iOS host app's window scene and incoming magnet links.
class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard scene is UIWindowScene else {
            return
        }

        if let url = connectionOptions.urlContexts.first?.url {
            DispatchQueue.main.async { [weak self] in
                self?.deliver(url)
            }
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else {
            return
        }

        deliver(url)
    }

    /// Delivers a registered magnet URL to the native app interface.
    private func deliver(_ url: URL) {
        guard
            url.scheme?.lowercased() == "magnet",
            let viewController = window?.rootViewController as? ViewController
        else {
            return
        }

        viewController.handleMagnetURL(url)
    }
}

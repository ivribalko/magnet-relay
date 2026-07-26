//
//  AppDelegate.swift
//  iOS (App)
//
//  Created by i on 7/25/26.
//

import UIKit

@main
/// Coordinates application-level lifecycle events for the iOS host app.
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

}

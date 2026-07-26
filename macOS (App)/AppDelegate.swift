//
//  AppDelegate.swift
//  macOS (App)
//
//  Created by i on 7/25/26.
//

import Cocoa

@main
/// Coordinates application-level lifecycle events for the macOS host app.
class AppDelegate: NSObject, NSApplicationDelegate {

    private var pendingMagnetURLs: [URL] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.deliverPendingMagnetURLs()
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        pendingMagnetURLs.append(
            contentsOf: urls.filter { $0.scheme?.lowercased() == "magnet" }
        )
        deliverPendingMagnetURLs()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    /// Delivers registered magnet URLs to the native app interface.
    private func deliverPendingMagnetURLs() {
        guard
            let viewController = NSApp.windows
                .compactMap(\.contentViewController)
                .compactMap({ $0 as? ViewController })
                .first
        else {
            return
        }

        let urls = pendingMagnetURLs
        pendingMagnetURLs.removeAll()
        urls.forEach(viewController.handleMagnetURL)
    }
}

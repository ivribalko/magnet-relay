//
//  ViewController.swift
//  Shared (App)
//
//  Created by i on 7/25/26.
//

import Foundation
import WebKit

#if os(iOS)
import UIKit
typealias PlatformViewController = UIViewController
#elseif os(macOS)
import Cocoa
typealias PlatformViewController = NSViewController
#endif

/// Presents setup guidance, qBittorrent status, and magnet-link results.
class ViewController: PlatformViewController, WKNavigationDelegate, WKScriptMessageHandler {

    @IBOutlet var webView: WKWebView!

    private var pageLoaded = false
    private var serverURL: URL?
    private var statusRequestID = UUID()
    private var statusTask: URLSessionDataTask?
    private var statusClient: QBittorrentClient?
    private var magnetTask: URLSessionDataTask?
    private var magnetClient: QBittorrentClient?
    private var pendingMagnetURL: URL?

    override func viewDidLoad() {
        super.viewDidLoad()

        webView.navigationDelegate = self

#if os(iOS)
        webView.scrollView.isScrollEnabled = false
        let activeNotification = UIApplication.didBecomeActiveNotification
#elseif os(macOS)
        let activeNotification = NSApplication.didBecomeActiveNotification
#endif

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: activeNotification,
            object: nil
        )
        webView.configuration.userContentController.add(self, name: "controller")

        let pageURL = Bundle.main.url(forResource: "Main", withExtension: "html")!
        webView.loadFileURL(pageURL, allowingReadAccessTo: Bundle.main.resourceURL!)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        pageLoaded = true

#if os(iOS)
        let applicationIsActive = UIApplication.shared.applicationState == .active
#elseif os(macOS)
        let applicationIsActive = NSApp.isActive
#endif

        if let pendingMagnetURL {
            self.pendingMagnetURL = nil
            handleMagnetURL(pendingMagnetURL)
        } else if applicationIsActive {
            refreshConnectionStatus()
        }
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let action = message.body as? String else {
            return
        }

        switch action {
        case "refresh-status":
            refreshConnectionStatus()
        case "open-server":
            openServer()
        default:
            break
        }
    }

    @objc private func applicationDidBecomeActive() {
        guard pageLoaded else {
            return
        }

        if let pendingMagnetURL {
            self.pendingMagnetURL = nil
            handleMagnetURL(pendingMagnetURL)
            return
        }

        refreshConnectionStatus()
    }

    /// Adds an incoming magnet URL and opens qBittorrent after success.
    func handleMagnetURL(_ url: URL) {
        guard pageLoaded else {
            pendingMagnetURL = url
            return
        }

        guard url.scheme?.lowercased() == "magnet" else {
            showOperationStatus(
                message: "The selected URL is not a valid magnet link.",
                state: "error"
            )
            return
        }

        guard let configuration = ServerConfiguration() else {
            serverURL = nil
            showOperationStatus(
                message: "Configure the server in local.xcconfig.",
                state: "error"
            )
            return
        }

        magnetTask?.cancel()
        serverURL = configuration.baseURL

        let client = QBittorrentClient(configuration: configuration)
        magnetClient = client
        showOperationStatus(message: "Adding magnet link…", busy: true)

        magnetTask = client.addMagnet(url) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else {
                    return
                }

                self.magnetTask = nil
                switch result {
                case .success:
                    self.showOperationStatus(
                        message: "Added magnet link to qBittorrent.",
                        state: "success"
                    )
                    self.refreshConnectionStatus()
                    self.openServer()
                case let .failure(error):
                    self.showOperationStatus(
                        message: self.message(for: error),
                        state: "error"
                    )
                }
            }
        }
    }

    /// Requests the qBittorrent version and presents structured connection diagnostics.
    private func refreshConnectionStatus() {
        statusTask?.cancel()
        statusRequestID = UUID()
        let requestID = statusRequestID

        guard let configuration = ServerConfiguration() else {
            serverURL = nil
            showStatus(
                lanPermission: "Not verified",
                lanState: "warning",
                serverAddress: "Not configured",
                serverPort: "Not configured",
                serverVersion: "Not configured",
                serverState: "error",
                message: "Configure the server in local.xcconfig.",
                messageState: "error",
                canOpen: false
            )
            return
        }

        serverURL = configuration.baseURL
        showStatus(
            lanPermission: "Checking…",
            lanState: "checking",
            serverAddress: configuration.address,
            serverPort: configuration.port,
            serverVersion: "Checking…",
            serverState: "checking",
            message: "Testing connection…",
            messageState: "",
            canOpen: true,
            checking: true
        )

        let client = QBittorrentClient(configuration: configuration)
        statusClient = client
        statusTask = client.fetchVersion { [weak self] result in
            DispatchQueue.main.async {
                self?.finishStatusRequest(
                    requestID: requestID,
                    configuration: configuration,
                    result: result
                )
            }
        }
    }

    /// Converts a completed version request into native-app status values.
    private func finishStatusRequest(
        requestID: UUID,
        configuration: ServerConfiguration,
        result: Result<String, Error>
    ) {
        guard statusRequestID == requestID else {
            return
        }
        statusTask = nil

        switch result {
        case let .success(version):
            showStatus(
                lanPermission: "Allowed",
                lanState: "success",
                serverAddress: configuration.address,
                serverPort: configuration.port,
                serverVersion: "qBittorrent \(version)",
                serverState: "success",
                message: "",
                messageState: "",
                canOpen: true
            )
        case let .failure(error):
            let reachedServer = error is QBittorrentClientError
            showStatus(
                lanPermission: reachedServer ? "Allowed" : "Not verified",
                lanState: reachedServer ? "success" : "warning",
                serverAddress: configuration.address,
                serverPort: configuration.port,
                serverVersion: reachedServer ? "Rejected" : "Unreachable",
                serverState: "error",
                message: message(for: error),
                messageState: "error",
                canOpen: true
            )
        }
    }

    /// Produces a concise user-facing message for a server request failure.
    private func message(for error: Error) -> String {
        if let urlError = error as? URLError,
           [
               .cannotConnectToHost,
               .cannotFindHost,
               .networkConnectionLost,
               .notConnectedToInternet,
               .timedOut
           ].contains(urlError.code) {
            return "Could not reach qBittorrent. Check Local Network access."
        }

        return error.localizedDescription
    }

    /// Sends connection status to the bundled app page.
    private func showStatus(
        lanPermission: String,
        lanState: String,
        serverAddress: String,
        serverPort: String,
        serverVersion: String,
        serverState: String,
        message: String,
        messageState: String,
        canOpen: Bool,
        checking: Bool = false
    ) {
        let payload: [String: Any] = [
            "lanPermission": lanPermission,
            "lanState": lanState,
            "serverAddress": serverAddress,
            "serverPort": serverPort,
            "serverVersion": serverVersion,
            "serverState": serverState,
            "message": message,
            "messageState": messageState,
            "canOpen": canOpen,
            "checking": checking
        ]

        guard
            let data = try? JSONSerialization.data(withJSONObject: payload),
            let json = String(data: data, encoding: .utf8)
        else {
            return
        }

        webView.evaluateJavaScript("showConnectionStatus(\(json))")
    }

    /// Sends the latest magnet-link result to the bundled app page.
    private func showOperationStatus(
        message: String,
        state: String = "",
        busy: Bool = false
    ) {
        let payload: [String: Any] = [
            "message": message,
            "state": state,
            "busy": busy
        ]

        guard
            let data = try? JSONSerialization.data(withJSONObject: payload),
            let json = String(data: data, encoding: .utf8)
        else {
            return
        }

        webView.evaluateJavaScript("showOperationStatus(\(json))")
    }

    /// Opens the configured qBittorrent server in the default browser.
    private func openServer() {
        guard let serverURL else {
            return
        }

#if os(iOS)
        UIApplication.shared.open(serverURL)
#elseif os(macOS)
        NSWorkspace.shared.open(serverURL)
#endif
    }

}

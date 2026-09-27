//
//  QBittorrentClient.swift
//  Shared (App)
//

import Foundation

/// Combines the saved server address with the configured scheme and port.
struct ServerConfiguration {
    let baseURL: URL
    let address: String
    let port: String

    static var savedAddress: String {
        get { UserDefaults.standard.string(forKey: "serverAddress") ?? "192.168.1." }
        set { UserDefaults.standard.set(newValue, forKey: "serverAddress") }
    }

    init?(bundle: Bundle = .main) {
        let host = Self.savedAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let schemeValue = bundle.object(forInfoDictionaryKey: "MagnetRelayServerScheme") as? String,
            let portValue = bundle.object(forInfoDictionaryKey: "MagnetRelayServerPort") as? String,
            ["http", "https"].contains(schemeValue.lowercased()),
            !host.isEmpty,
            !host.hasSuffix("."),
            !host.contains(where: { $0.isWhitespace }),
            !host.contains(where: { "/:@?#".contains($0) }),
            let portNumber = Int(portValue),
            (1...65_535).contains(portNumber)
        else {
            return nil
        }

        var components = URLComponents()
        components.scheme = schemeValue.lowercased()
        components.host = host
        components.port = portNumber

        guard let url = components.url else {
            return nil
        }

        baseURL = url
        address = host
        port = portValue
    }

    /// Builds an API URL while preserving any configured base path.
    func endpoint(_ path: String) -> URL {
        path.split(separator: "/").reduce(baseURL) { result, component in
            result.appendingPathComponent(String(component))
        }
    }
}

/// Describes failures returned by the qBittorrent Web API.
enum QBittorrentClientError: LocalizedError {
    case invalidMagnet
    case rejected(status: Int, message: String)
    case unexpectedResponse

    var errorDescription: String? {
        switch self {
        case .invalidMagnet:
            return "The selected URL is not a valid magnet link."
        case let .rejected(status, message):
            let detail = message.isEmpty ? "No response details." : message
            return "qBittorrent returned HTTP \(status): \(detail)"
        case .unexpectedResponse:
            return "qBittorrent returned an unexpected response."
        }
    }
}

/// Performs isolated qBittorrent status and torrent-add requests.
final class QBittorrentClient {
    let configuration: ServerConfiguration

    private let session: URLSession

    init(configuration: ServerConfiguration) {
        self.configuration = configuration

        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.timeoutIntervalForRequest = 12
        sessionConfiguration.timeoutIntervalForResource = 20
        sessionConfiguration.httpCookieAcceptPolicy = .always
        session = URLSession(configuration: sessionConfiguration)
    }

    /// Reads the qBittorrent version as a non-mutating connection test.
    @discardableResult
    func fetchVersion(
        completion: @escaping (Result<String, Error>) -> Void
    ) -> URLSessionDataTask {
        let request = URLRequest(url: configuration.endpoint("api/v2/app/version"))
        return perform(request) { result in
            completion(
                result.flatMap { data in
                    let version = String(decoding: data, as: UTF8.self)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    return version.isEmpty
                        ? .failure(QBittorrentClientError.unexpectedResponse)
                        : .success(version)
                }
            )
        }
    }

    /// Sends one magnet URL to qBittorrent.
    @discardableResult
    func addMagnet(
        _ magnetURL: URL,
        completion: @escaping (Result<Void, Error>) -> Void
    ) -> URLSessionDataTask? {
        guard magnetURL.scheme?.lowercased() == "magnet" else {
            completion(.failure(QBittorrentClientError.invalidMagnet))
            return nil
        }

        var request = URLRequest(url: configuration.endpoint("api/v2/torrents/add"))
        request.httpMethod = "POST"
        request.setValue(
            "application/x-www-form-urlencoded; charset=utf-8",
            forHTTPHeaderField: "Content-Type"
        )
        request.httpBody = formBody(["urls": magnetURL.absoluteString])

        return perform(request) { result in
            completion(result.map { _ in () })
        }
    }

    /// Executes one request and validates its HTTP response.
    private func perform(
        _ request: URLRequest,
        completion: @escaping (Result<Data, Error>) -> Void
    ) -> URLSessionDataTask {
        let task = session.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(QBittorrentClientError.unexpectedResponse))
                return
            }

            let responseData = data ?? Data()
            guard (200..<300).contains(httpResponse.statusCode) else {
                let message = String(decoding: responseData, as: UTF8.self)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                completion(
                    .failure(
                        QBittorrentClientError.rejected(
                            status: httpResponse.statusCode,
                            message: message
                        )
                    )
                )
                return
            }

            completion(.success(responseData))
        }
        task.resume()
        return task
    }

    /// Encodes values using the HTML form rules required by qBittorrent.
    private func formBody(_ values: [String: String]) -> Data {
        values
            .map { "\(formEncode($0.key))=\(formEncode($0.value))" }
            .sorted()
            .joined(separator: "&")
            .data(using: .utf8) ?? Data()
    }

    /// Percent-encodes one form value without corrupting plus signs.
    private func formEncode(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._*"))
        return value
            .addingPercentEncoding(withAllowedCharacters: allowed)?
            .replacingOccurrences(of: "%20", with: "+") ?? ""
    }
}

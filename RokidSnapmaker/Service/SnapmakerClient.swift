import Foundation

enum SnapmakerError: LocalizedError {
    case invalidHost
    case noToken
    case httpError(Int)
    case decodingError
    case unreachable

    var errorDescription: String? {
        switch self {
        case .invalidHost: return "Invalid IP address."
        case .noToken: return "No token. Connect first."
        case .httpError(let c): return "HTTP \(c) from machine."
        case .decodingError: return "Unexpected response from machine."
        case .unreachable: return "Could not reach machine."
        }
    }
}

actor SnapmakerClient {
    static let port = 8080

    func connect(host: String, appName: String = "RokidSnapmaker") async throws -> String {
        guard !host.isEmpty,
              let url = URL(string: "http://\(host):\(Self.port)/api/v1/connect") else {
            throw SnapmakerError.invalidHost
        }
        var req = URLRequest(url: url, timeoutInterval: 12)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONEncoder().encode(["token": appName])

        let (data, response) = try await urlSession.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw SnapmakerError.unreachable }
        guard http.statusCode == 200 else { throw SnapmakerError.httpError(http.statusCode) }
        guard let decoded = try? JSONDecoder().decode(ConnectResponse.self, from: data) else {
            throw SnapmakerError.decodingError
        }
        return decoded.token
    }

    func getStatus(host: String, token: String) async throws -> MachineState {
        guard !host.isEmpty else { throw SnapmakerError.invalidHost }
        guard !token.isEmpty else { throw SnapmakerError.noToken }

        var components = URLComponents(string: "http://\(host):\(Self.port)/api/v1/status")!
        components.queryItems = [URLQueryItem(name: "token", value: token)]
        guard let url = components.url else { throw SnapmakerError.invalidHost }

        var req = URLRequest(url: url, timeoutInterval: 8)
        req.setValue("Token \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await urlSession.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw SnapmakerError.unreachable }
        guard http.statusCode == 200 else { throw SnapmakerError.httpError(http.statusCode) }
        guard let decoded = try? JSONDecoder().decode(SnapmakerStatusResponse.self, from: data) else {
            throw SnapmakerError.decodingError
        }
        return decoded.toMachineState()
    }

    private var urlSession: URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        return URLSession(configuration: config)
    }
}

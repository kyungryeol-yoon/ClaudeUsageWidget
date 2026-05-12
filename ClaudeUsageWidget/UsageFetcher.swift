import Foundation

enum UsageFetchError: LocalizedError {
    case invalidResponse
    case unauthorized
    case rateLimited
    case httpError(Int)
    case decodingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse: return String(localized: "Invalid response.")
        case .unauthorized:    return String(localized: "Authentication failed. Run 'claude login' again.")
        case .rateLimited:     return String(localized: "Rate limit reached. Will retry shortly.")
        case .httpError(let code): return String(localized: "HTTP error: \(code)")
        case .decodingFailed(let msg): return String(localized: "Failed to parse response: \(msg)")
        }
    }
}

struct UsageResponse: Codable {
    let fiveHour: UsageBucket
    let sevenDay: UsageBucket
}

struct UsageBucket: Codable {
    let utilization: Double
    let resetsAt: String?
}

enum UsageFetcher {
    static func fetch(accessToken: String) async throws -> UsageResponse {
        guard let url = URL(string: "https://api.anthropic.com/api/oauth/usage") else {
            throw UsageFetchError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse else {
            throw UsageFetchError.invalidResponse
        }
        
        switch http.statusCode {
        case 200: break
        case 401: throw UsageFetchError.unauthorized
        case 429: throw UsageFetchError.rateLimited
        default:  throw UsageFetchError.httpError(http.statusCode)
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(UsageResponse.self, from: data)
        } catch {
            throw UsageFetchError.decodingFailed(String(describing: error))
        }
    }
}

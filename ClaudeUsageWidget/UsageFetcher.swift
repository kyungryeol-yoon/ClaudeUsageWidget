import Foundation

enum UsageFetchError: LocalizedError {
    case invalidResponse
    case unauthorized
    case rateLimited
    case httpError(Int)
    case decodingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "잘못된 응답입니다."
        case .unauthorized:    return "인증 실패. 'claude login'을 다시 실행하세요."
        case .rateLimited:     return "사용량 한도 도달. 잠시 후 다시 시도합니다."
        case .httpError(let code): return "HTTP 오류: \(code)"
        case .decodingFailed(let msg): return "응답 파싱 실패: \(msg)"
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

//
//  CredentialsLoader.swift
//  ClaudeUsageWidget
//
//  Created by 윤경렬 on 4/19/26.
//

import Foundation
import Security

struct ClaudeCredentials: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Int64
    let subscriptionType: String?
}

struct CredentialsWrapper: Codable {
    let claudeAiOauth: ClaudeCredentials
}

enum CredentialsError: LocalizedError {
    case notFound
    case accessDenied(OSStatus)
    case invalidFormat
    
    var errorDescription: String? {
        switch self {
        case .notFound:
            return String(localized: "Claude Code login required. Run 'claude login' in a terminal.")
        case .accessDenied(let status):
            return String(localized: "Keychain access denied (code: \(Int(status)))")
        case .invalidFormat:
            return String(localized: "Keychain data is in an unexpected format.")
        }
    }
}

enum CredentialsLoader {
    static func load() throws -> ClaudeCredentials {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw CredentialsError.notFound
            }
            throw CredentialsError.accessDenied(status)
        }
        
        guard let data = result as? Data else {
            throw CredentialsError.invalidFormat
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let wrapper = try decoder.decode(CredentialsWrapper.self, from: data)
            return wrapper.claudeAiOauth
        } catch {
            throw CredentialsError.invalidFormat
        }
    }
}

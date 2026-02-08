import Foundation
import AuthenticationServices
#if os(iOS)
import UIKit
#endif

/// Authentication manager supporting Email, Apple, and Google sign-in
@Observable
@MainActor
final class AuthManager {
    static let shared = AuthManager()
    
    private let supabaseURL = "https://yzacvyfuhmguelbpzrxn.supabase.co"
    private let supabaseAnonKey = "sb_publishable_iR35kgSqCf1bAb18oSjBOQ_FvMbIwS_"
    
    // MARK: - State
    
    private(set) var currentUser: AuthUser?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    
    var isAuthenticated: Bool {
        currentUser != nil
    }
    
    private var accessToken: String? {
        didSet {
            if let token = accessToken {
                UserDefaults.standard.set(token, forKey: "supabase_access_token")
            } else {
                UserDefaults.standard.removeObject(forKey: "supabase_access_token")
            }
        }
    }
    
    private var refreshToken: String? {
        didSet {
            if let token = refreshToken {
                UserDefaults.standard.set(token, forKey: "supabase_refresh_token")
            } else {
                UserDefaults.standard.removeObject(forKey: "supabase_refresh_token")
            }
        }
    }
    
    // MARK: - Init
    
    private init() {
        // Restore session on init
        accessToken = UserDefaults.standard.string(forKey: "supabase_access_token")
        refreshToken = UserDefaults.standard.string(forKey: "supabase_refresh_token")
        
        Task {
            await restoreSession()
        }
    }
    
    // MARK: - Email/Password Auth
    
    func signUp(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        let url = URL(string: "\(supabaseURL)/auth/v1/signup")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email, "password": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            handleAuthResponse(authResponse)
        } else {
            let error = try? JSONDecoder().decode(AuthErrorResponse.self, from: data)
            throw AuthError.serverError(error?.message ?? "Sign up failed")
        }
    }
    
    func signIn(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        let url = URL(string: "\(supabaseURL)/auth/v1/token?grant_type=password")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email, "password": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            handleAuthResponse(authResponse)
        } else {
            let error = try? JSONDecoder().decode(AuthErrorResponse.self, from: data)
            throw AuthError.serverError(error?.message ?? "Sign in failed")
        }
    }
    
    // MARK: - Apple Sign In
    
    #if os(iOS)
    func signInWithApple() async throws {
        isLoading = true
        errorMessage = nil
        
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.email, .fullName]
        
        let result = try await performAppleSignIn(request: request)
        
        guard let credential = result.credential as? ASAuthorizationAppleIDCredential,
              let identityToken = credential.identityToken,
              let idTokenString = String(data: identityToken, encoding: .utf8) else {
            isLoading = false
            throw AuthError.invalidCredential
        }
        
        // Send to Supabase
        try await signInWithIdToken(provider: .apple, idToken: idTokenString)
        isLoading = false
    }
    
    private func performAppleSignIn(request: ASAuthorizationAppleIDRequest) async throws -> ASAuthorization {
        try await withCheckedThrowingContinuation { continuation in
            let controller = ASAuthorizationController(authorizationRequests: [request])
            let delegate = AppleSignInDelegate(continuation: continuation)
            controller.delegate = delegate
            controller.performRequests()
            
            // Keep delegate alive
            objc_setAssociatedObject(controller, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    #if !APPEXTENSION
    // MARK: - Google Sign In (via Supabase OAuth)
    
    func signInWithGoogle() async throws {
        isLoading = true
        errorMessage = nil
        
        // Use Supabase's built-in OAuth flow via ASWebAuthenticationSession
        let authURL = URL(string: "\(supabaseURL)/auth/v1/authorize?provider=google&redirect_to=watertracker://auth-callback")!
        
        let callbackURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: "watertracker") { url, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let url = url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: AuthError.invalidResponse)
                }
            }
            session.prefersEphemeralWebBrowserSession = false
            session.presentationContextProvider = WebAuthContextProvider.shared
            
            DispatchQueue.main.async {
                session.start()
            }
        }
        
        // Extract tokens from callback URL
        try await handleOAuthCallback(url: callbackURL)
        isLoading = false
    }
    #endif
    
    private func handleOAuthCallback(url: URL) async throws {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let fragment = components.fragment else {
            throw AuthError.invalidResponse
        }
        
        // Parse fragment: access_token=...&refresh_token=...
        var params: [String: String] = [:]
        for pair in fragment.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                params[String(parts[0])] = String(parts[1])
            }
        }
        
        guard let accessToken = params["access_token"],
              let refreshToken = params["refresh_token"] else {
            throw AuthError.invalidCredential
        }
        
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        
        // Fetch user info
        currentUser = try await fetchUser(token: accessToken)
    }
    #endif
    
    // MARK: - OAuth Token Exchange
    
    private func signInWithIdToken(provider: OAuthProvider, idToken: String) async throws {
        let url = URL(string: "\(supabaseURL)/auth/v1/token?grant_type=id_token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "provider": provider.rawValue,
            "id_token": idToken
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            handleAuthResponse(authResponse)
        } else {
            let error = try? JSONDecoder().decode(AuthErrorResponse.self, from: data)
            throw AuthError.serverError(error?.message ?? "OAuth sign in failed")
        }
    }
    
    // MARK: - Session Management
    
    func signOut() {
        accessToken = nil
        refreshToken = nil
        currentUser = nil
    }
    
    func restoreSessionPublic() async {
        await restoreSession()
    }
    
    /// Handle OAuth callback URL
    func handleURLCallback(_ url: URL) async throws {
        #if os(iOS)
        try await handleOAuthCallback(url: url)
        #endif
    }
    
    private func restoreSession() async {
        guard let token = accessToken else { return }
        
        // Verify token by fetching user
        do {
            let user = try await fetchUser(token: token)
            currentUser = user
        } catch {
            // Token expired, try refresh
            if let refresh = refreshToken {
                do {
                    try await refreshSession(refreshToken: refresh)
                } catch {
                    signOut()
                }
            } else {
                signOut()
            }
        }
    }
    
    private func refreshSession(refreshToken: String) async throws {
        let url = URL(string: "\(supabaseURL)/auth/v1/token?grant_type=refresh_token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["refresh_token": refreshToken]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthError.sessionExpired
        }
        
        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        handleAuthResponse(authResponse)
    }
    
    private func fetchUser(token: String) async throws -> AuthUser {
        let url = URL(string: "\(supabaseURL)/auth/v1/user")!
        var request = URLRequest(url: url)
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthError.invalidResponse
        }
        
        return try JSONDecoder().decode(AuthUser.self, from: data)
    }
    
    private func handleAuthResponse(_ response: AuthResponse) {
        accessToken = response.accessToken
        refreshToken = response.refreshToken
        currentUser = response.user
    }
    
    // MARK: - Public Accessors
    
    func getAccessToken() -> String? {
        accessToken
    }
    
    func getUserId() -> String? {
        currentUser?.id
    }
}

// MARK: - Models

struct AuthUser: Codable {
    let id: String
    let email: String?
    let createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case createdAt = "created_at"
    }
}

struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let user: AuthUser
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
    }
}

struct AuthErrorResponse: Codable {
    let message: String
    let error: String?
}

enum OAuthProvider: String {
    case apple = "apple"
    case google = "google"
}

enum AuthError: LocalizedError {
    case invalidResponse
    case invalidCredential
    case noViewController
    case sessionExpired
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid server response"
        case .invalidCredential: return "Invalid credentials"
        case .noViewController: return "Cannot present sign-in"
        case .sessionExpired: return "Session expired, please sign in again"
        case .serverError(let msg): return msg
        }
    }
}

// MARK: - Apple Sign In Delegate

#if os(iOS)
private class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate {
    let continuation: CheckedContinuation<ASAuthorization, Error>
    
    init(continuation: CheckedContinuation<ASAuthorization, Error>) {
        self.continuation = continuation
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        continuation.resume(returning: authorization)
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation.resume(throwing: error)
    }
}

// MARK: - Web Auth Context Provider

#if !APPEXTENSION
private class WebAuthContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = WebAuthContextProvider()
    
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}
#endif
#endif

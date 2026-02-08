import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @State private var authManager = AuthManager.shared
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Logo/Title
                VStack(spacing: 8) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)
                    
                    Text("WaterTracker")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Track your hydration")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)
                
                Spacer()
                
                // Email/Password Form
                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(isSignUp ? .newPassword : .password)
                    
                    Button {
                        Task {
                            await handleEmailAuth()
                        }
                    } label: {
                        if authManager.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(isSignUp ? "Sign Up" : "Sign In")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(email.isEmpty || password.isEmpty || authManager.isLoading)
                    
                    Button(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up") {
                        isSignUp.toggle()
                    }
                    .font(.footnote)
                }
                .padding(.horizontal)
                
                // Divider
                HStack {
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(.secondary.opacity(0.3))
                    Text("or")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(.secondary.opacity(0.3))
                }
                .padding(.horizontal)
                
                // Social Sign In
                VStack(spacing: 12) {
                    // Sign in with Apple
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.email, .fullName]
                    } onCompletion: { result in
                        Task {
                            await handleAppleSignIn(result)
                        }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    
                    // Sign in with Google
                    Button {
                        Task {
                            await handleGoogleSignIn()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "g.circle.fill")
                                .font(.title2)
                            Text("Sign in with Google")
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Auth Handlers
    
    private func handleEmailAuth() async {
        do {
            if isSignUp {
                try await authManager.signUp(email: email, password: password)
            } else {
                try await authManager.signIn(email: email, password: password)
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityToken = credential.identityToken,
                  let idTokenString = String(data: identityToken, encoding: .utf8) else {
                errorMessage = "Failed to get Apple ID token"
                showError = true
                return
            }
            
            do {
                // Use the token with Supabase
                try await signInWithAppleToken(idTokenString)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            
        case .failure(let error):
            // User cancelled is not an error
            if (error as? ASAuthorizationError)?.code != .canceled {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func signInWithAppleToken(_ idToken: String) async throws {
        // Direct API call for Apple sign in
        let url = URL(string: "https://yzacvyfuhmguelbpzrxn.supabase.co/auth/v1/token?grant_type=id_token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("sb_publishable_iR35kgSqCf1bAb18oSjBOQ_FvMbIwS_", forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "provider": "apple",
            "id_token": idToken
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let errorResponse = try? JSONDecoder().decode(AuthErrorResponse.self, from: data)
            throw AuthError.serverError(errorResponse?.message ?? "Apple sign in failed")
        }
        
        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        
        // Update AuthManager state
        UserDefaults.standard.set(authResponse.accessToken, forKey: "supabase_access_token")
        UserDefaults.standard.set(authResponse.refreshToken, forKey: "supabase_refresh_token")
        
        // Trigger refresh
        await AuthManager.shared.restoreSessionPublic()
    }
    
    private func handleGoogleSignIn() async {
        do {
            try await authManager.signInWithGoogle()
        } catch {
            // User cancelled is common, don't show error
            if !error.localizedDescription.contains("cancel") {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

#Preview {
    AuthView()
}

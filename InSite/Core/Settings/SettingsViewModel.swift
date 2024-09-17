//
//  SettingsViewModel.swift
//  InSite
//
//  Created by Anand Parikh on 12/26/24.
//

import Foundation
import SwiftUI

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var authProviders: [AuthProviderOption] = []
    
    func loadAuthProviders() {
        if let providers = try? AuthManager.shared.getProvider() {
            authProviders = providers
        }
    }
    func logOut() throws {
        try AuthManager.shared.signOut()
    }
    
    func resetPassword() async throws {
        let authUser = try AuthManager.shared.getAuthenticatedUser()
        guard let email = authUser.email else {
            throw URLError(.fileDoesNotExist)
        }
        try await AuthManager.shared.resetPassword(email: email)
    }
    
    func updateEmail() async throws {
        let email = "hello123@testing.com"
        try await AuthManager.shared.updateEmail(email: email)
    }
    
    func updatePassword() async throws {
        let password = "HelloTrying123!"
        try await AuthManager.shared.updatePassword(password: password)
    }
}

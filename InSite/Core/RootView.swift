//
//  RootView.swift
//  InSite
//
//  Created by Anand Parikh on 9/12/24.
//

import SwiftUI

struct RootView: View {
    
    @State private var showSignInView: Bool = false
    @State private var restoredChameliaUserId: String?
    
    
    var body: some View {
        ZStack {
            if !showSignInView{
                NavigationStack{
//                    SettingsView(showSignInView: $showSignInView)
                    ProfileView(showSignInView: $showSignInView)
                }
            }
        }
        .onAppear {
            do {
                let authUser = try AuthManager.shared.getAuthenticatedUser()
                self.showSignInView = false
                self.restoreChameliaStateIfNeeded(for: authUser)
                _ = try AuthManager.shared.getProvider()
            } catch {
                print("Auth error: \(error)")
                self.showSignInView = true
                self.restoredChameliaUserId = nil
            }
        }
        .onChange(of: showSignInView) { isShowingSignIn in
            guard !isShowingSignIn else {
                restoredChameliaUserId = nil
                return
            }

            do {
                let authUser = try AuthManager.shared.getAuthenticatedUser()
                restoreChameliaStateIfNeeded(for: authUser)
            } catch {
                print("Auth error: \(error)")
            }
        }
        .fullScreenCover(isPresented: $showSignInView) {
            NavigationStack{
                AuthView(showSignInView: $showSignInView)
            }
        }
    }

    private func restoreChameliaStateIfNeeded(for authUser: AuthDataResultModel) {
        guard !authUser.isAnonymous else { return }
        guard restoredChameliaUserId != authUser.uid else { return }

        restoredChameliaUserId = authUser.uid

        Task {
            do {
                _ = try await ChameliaStateManager.shared.loadFromFirebase(userId: authUser.uid)
            } catch {
                restoredChameliaUserId = nil
                print("Chamelia load error: \(error)")
            }
        }
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
    }
}

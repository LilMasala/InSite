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
    @State private var showChameliaOnboarding = false
    
    
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
                self.updateOnboardingPresentation(for: authUser)
                if !showChameliaOnboarding {
                    self.restoreChameliaStateIfNeeded(for: authUser)
                }
                _ = try AuthManager.shared.getProvider()
            } catch {
                print("Auth error: \(error)")
                self.showSignInView = true
                self.restoredChameliaUserId = nil
                self.showChameliaOnboarding = false
            }
        }
        .onChange(of: showSignInView) { isShowingSignIn in
            guard !isShowingSignIn else {
                restoredChameliaUserId = nil
                showChameliaOnboarding = false
                return
            }

            do {
                let authUser = try AuthManager.shared.getAuthenticatedUser()
                updateOnboardingPresentation(for: authUser)
                if !showChameliaOnboarding {
                    restoreChameliaStateIfNeeded(for: authUser)
                }
            } catch {
                print("Auth error: \(error)")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .requestChameliaQuestionnaireOnboarding)) { _ in
            showChameliaOnboarding = true
        }
        .fullScreenCover(isPresented: $showSignInView) {
            NavigationStack{
                AuthView(showSignInView: $showSignInView)
            }
        }
        .fullScreenCover(isPresented: $showChameliaOnboarding) {
            QuestionnaireOnboardingView(isPresented: $showChameliaOnboarding) { userId in
                restoredChameliaUserId = userId
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
                print("Chamelia state load succeeded for user: \(authUser.uid)")
            } catch ChameliaStateManagerError.notFound {
                do {
                    let preferences = legacyPreferences(for: authUser.uid)
                        ?? ChameliaPreferences(
                            aggressiveness: 0.5,
                            hypoglycemiaFear: 0.5,
                            burdenSensitivity: 0.5,
                            persona: "default"
                        )
                    try await ChameliaEngine.shared.initialize(
                        patientId: authUser.uid,
                        preferences: preferences
                    )
                    restoredChameliaUserId = authUser.uid
                    print("Chamelia first-run initialize succeeded for user: \(authUser.uid)")
                } catch {
                    restoredChameliaUserId = nil
                    print("Chamelia initialize failed for user \(authUser.uid): \(error)")
                }
            } catch {
                restoredChameliaUserId = nil
                print("Chamelia load failed for user \(authUser.uid): \(error)")
            }
        }
    }

    private func updateOnboardingPresentation(for authUser: AuthDataResultModel) {
        guard !showSignInView else {
            showChameliaOnboarding = false
            return
        }
        guard !authUser.isAnonymous else {
            showChameliaOnboarding = false
            return
        }
        showChameliaOnboarding = !ChameliaQuestionnaireStore.isCompleted()
    }

    private func legacyPreferences(for userId: String) -> ChameliaPreferences? {
        nil
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
    }
}

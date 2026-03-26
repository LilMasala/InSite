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
    @State private var isResolvingSession = false
    @State private var sessionHydrationErrorMessage: String?
    
    
    var body: some View {
        ZStack {
            if !showSignInView{
                if isResolvingSession {
                    ProgressView("Loading your account…")
                        .progressViewStyle(.circular)
                } else if let sessionHydrationErrorMessage {
                    VStack(spacing: 12) {
                        Text("We couldn’t load your seeded therapy profile")
                            .font(.headline)
                        Text(sessionHydrationErrorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task { await refreshSessionState() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(24)
                } else {
                    NavigationStack{
    //                    SettingsView(showSignInView: $showSignInView)
                        ProfileView(showSignInView: $showSignInView)
                    }
                }
            }
        }
        .onAppear {
            Task {
                await refreshSessionState()
            }
        }
        .onChange(of: showSignInView) { isShowingSignIn in
            guard !isShowingSignIn else {
                restoredChameliaUserId = nil
                showChameliaOnboarding = false
                isResolvingSession = false
                return
            }

            Task {
                await refreshSessionState()
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

    @MainActor
    private func refreshSessionState() async {
        do {
            let authUser = try AuthManager.shared.getAuthenticatedUser()
            showSignInView = false
            isResolvingSession = !authUser.isAnonymous
            sessionHydrationErrorMessage = nil
            await resolveAuthenticatedSession(authUser)
            _ = try AuthManager.shared.getProvider()
        } catch {
            print("Auth error: \(error)")
            showSignInView = true
            restoredChameliaUserId = nil
            showChameliaOnboarding = false
            isResolvingSession = false
            sessionHydrationErrorMessage = nil
        }
    }

    @MainActor
    private func resolveAuthenticatedSession(_ authUser: AuthDataResultModel) async {
        guard !authUser.isAnonymous else {
            showChameliaOnboarding = false
            isResolvingSession = false
            return
        }

        do {
            let latestSnapshot = try await TherapySettingsLogManager.shared.getLatestValidTherapySnapshot()
            if let latestSnapshot {
                print(
                    "[RootView] remote snapshot found profile_id=\(latestSnapshot.profileId) timestamp=\(ISO8601DateFormatter().string(from: latestSnapshot.timestamp)) hour_ranges=\(latestSnapshot.hourRanges.count)"
                )
                guard !latestSnapshot.hourRanges.isEmpty else {
                    throw TherapySettingsLogManagerError.noValidRemoteSnapshot(
                        "A remote therapy snapshot was found for this account, but it contained no schedule blocks."
                    )
                }
                _ = ProfileDataStore().hydrate(from: latestSnapshot)
                ChameliaQuestionnaireStore.setCompleted(true, userId: authUser.uid)
                showChameliaOnboarding = false
            } else {
                updateOnboardingPresentation(for: authUser)
            }
        } catch {
            sessionHydrationErrorMessage = error.localizedDescription
            showChameliaOnboarding = false
            isResolvingSession = false
            print("[RootView] remote therapy hydration failed error=\(error.localizedDescription)")
            return
        }

        if !showChameliaOnboarding {
            restoreChameliaStateIfNeeded(for: authUser)
        }

        isResolvingSession = false
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
        showChameliaOnboarding = !ChameliaQuestionnaireStore.isCompleted(userId: authUser.uid)
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

//
//  SettingsView.swift
//  InSite
//
//  Created by Anand Parikh on 9/12/24.
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @Binding var showSignInView: Bool
    var body: some View {
        List {
            Section("Chamelia") {
                Button {
                    ChameliaQuestionnaireStore.resetCompletion()
                    NotificationCenter.default.post(name: .requestChameliaQuestionnaireOnboarding, object: nil)
                } label: {
                    HStack {
                        Text("Chamelia Preferences")
                        Spacer()
                        Text(preferencePreview)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Button("Log Out") {
                Task {
                    do {
                        try viewModel.logOut()
                        showSignInView = true
                    } catch {
                        print(error)
                    }
                }
            }
            
            if viewModel.authProviders.contains(.email) {
                Section("Email Functions") {
                    Button("Reset Password") {
                        Task {
                            do {
                                try await viewModel.resetPassword()
                                print("Password reset")
                            } catch {
                                print(error)
                            }
                        }
                    }
                    Button("Update Password") {
                        Task {
                            do {
                                try await viewModel.updatePassword()
                                print("Password updated")
                            } catch {
                                print(error)
                            }
                        }
                    }
                    Button("Update Email") {
                        Task {
                            do {
                                try await viewModel.updatePassword()
                                print("Email updated")
                            } catch {
                                print(error)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadAuthProviders()
        }
        .navigationTitle("Settings")
    }

    private var preferencePreview: String {
        let answers = ChameliaQuestionnaireStore.loadAnswers()
        let draft = ChameliaQuestionnaireStore.loadPreferenceDraft()

        let parts = [
            answers.aggressiveness?.rawValue.replacingOccurrences(of: "_", with: " "),
            draft.hypoglycemiaFear?.rawValue.replacingOccurrences(of: "_", with: " "),
            draft.recommendationCadence?.rawValue.replacingOccurrences(of: "_", with: " ")
        ]
        .compactMap { $0 }

        return parts.isEmpty ? "Not set" : parts.joined(separator: " · ")
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(showSignInView: .constant(false))
    }
}

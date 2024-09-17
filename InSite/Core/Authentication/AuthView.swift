//
//  AuthView.swift
//  InSite
//
//  Created by Anand Parikh on 9/11/24.
//

import SwiftUI
import GoogleSignIn
import GoogleSignInSwift
import AuthenticationServices
import CryptoKit
import Foundation


struct SignInWithAppleButtonViewRepresentable: UIViewRepresentable {
    
    let type: ASAuthorizationAppleIDButton.ButtonType
    let style: ASAuthorizationAppleIDButton.Style
    
    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton{
        return ASAuthorizationAppleIDButton(authorizationButtonType: type, authorizationButtonStyle: style)
        
    }
    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {
        
    }
}


extension UIViewController: ASAuthorizationControllerPresentationContextProviding {
    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return self.view.window!
    }
}


struct SignInWithAppleResult {
    let token: String
    let nonce: String
}

struct AuthView: View {
    
    @StateObject private var viewModel = AuthViewModel()
    @Binding var showSignInView: Bool
    
    
    var body: some View {
        VStack {
            Button(action: {
                Task {
                    do {
                        try await viewModel.signInAnonymous()
                        showSignInView = false
                    } catch {
                        print(error)
                    }
                }
            }) {
                Text("Sign in Anonymously")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(height:55)
                    .frame(maxWidth: .infinity)
                    .background(Color.orange)
                    .cornerRadius(10)
            }

            
            
            NavigationLink {
                SignInEmailView(showSignInView: $showSignInView)
            } label: {
                Text("Sign in with email")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(height:55)
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            
            GoogleSignInButton(viewModel: GoogleSignInButtonViewModel(scheme: .dark,style: .wide,state: .normal))  {
                Task {
                    do {
                        try await viewModel.signInGoogle()
                        showSignInView = false
                    } catch {
                        print(error)
                    }
                }
                
            }
            Button(action: {
                Task {
                    do {
                        try await viewModel.signInApple()
//                        showSignInView = false
                    } catch {
                        print(error)
                    }
                }
                
                
            }, label: {
                SignInWithAppleButtonViewRepresentable(type: .default, style: .black)
                
            })
            .frame(height:55)
            .onChange(of: viewModel.didSignInWithApple) { newValue in
                if newValue {
                    showSignInView = false
                }
            }
            Spacer()
        }
        .padding()
        .navigationTitle("Sign In")
    }
}

struct AuthView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack{
            AuthView(showSignInView:.constant(false))
        }
    }
}

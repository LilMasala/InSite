//
//  RootView.swift
//  InSite
//
//  Created by Anand Parikh on 9/12/24.
//

import SwiftUI

struct RootView: View {
    
    @State private var showSignInView: Bool = false
    
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
                _ = try AuthManager.shared.getProvider()
            } catch {
                print("Auth error: \(error)")
                self.showSignInView = true
            }
        }
        .fullScreenCover(isPresented: $showSignInView) {
            NavigationStack{
                AuthView(showSignInView: $showSignInView)
            }
        }
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
    }
}

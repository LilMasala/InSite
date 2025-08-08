import Foundation
import HealthKit
import HealthKitUI
import SwiftUI

//Home Screen

struct HealthAuthView: View {
    var body: some View {
        HomeScreen(showSignInView: .constant(false))
    }
}

struct ContentPreview: PreviewProvider {
    static var previews: some View {
        HealthAuthView()
    }
}

struct HomeScreen: View {
    let textColor = Color(#colorLiteral(red: 0.9098337293, green: 0.5442788601, blue: 0.3945763707, alpha: 1))
    let backgroundColor = Color(#colorLiteral(red: 0.97650069, green: 0.9073963761, blue: 0.9259181619, alpha: 1))
    let backgroundColor2 = Color(#colorLiteral(red: 0.9999999404, green: 1, blue: 1, alpha: 0.2986688066))
    let pastelBlue = Color(#colorLiteral(red: 0.7313573956, green: 0.8990380168, blue: 0.9520341754, alpha: 1))
    
    @Binding var showSignInView: Bool

    var body: some View {
        GeometryReader { geometry in
            NavigationStack {
                ZStack {
                    Color(UIColor.six).ignoresSafeArea()
                    VStack(spacing: geometry.size.height * 0.03) {
                        Text("InSite")
                            .font(.title)
                            .fontWeight(.light)
                            .padding(geometry.size.height * 0.025)
                            .background(
                                RoundedRectangle(cornerRadius: geometry.size.height * 0.03)
                                    .fill(pastelBlue)
                                    .shadow(color: .gray, radius: geometry.size.height * 0.002, x: 0, y: geometry.size.height * 0.002)
                            )
                            .foregroundColor(Color.white)
                            .frame(width: geometry.size.width * 0.6, height: geometry.size.height * 0.12)

                        Image("BearBlue")
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width * 0.7, height: geometry.size.width * 0.7)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(pastelBlue, lineWidth: geometry.size.width * 0.01)
                                    .shadow(color: Color.brown, radius: geometry.size.width * 0.005, x: 0, y: 0)
                                    .clipShape(Circle())
                            )

                        HStack(spacing: geometry.size.width * 0.015) {
                            Spacer()

                            VStack {
                                NavigationLink(destination: SiteChangeUI()) {
                                    Image(systemName: "arrow.right.circle.fill")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: geometry.size.width * 0.1, height: geometry.size.width * 0.1)
                                        .foregroundColor(.white)
                                        .background(pastelBlue)
                                        .cornerRadius(geometry.size.width * 0.05)
                                        .padding(geometry.size.width * 0.02)
                                        .shadow(color: .gray, radius: geometry.size.width * 0.002, x: 0, y: geometry.size.width * 0.002)
                                }
                                .frame(width: geometry.size.width * 0.18, height: geometry.size.width * 0.18)
                                Text("Change Site").fontWeight(.semibold).foregroundColor(.white)
                            }
                            .padding(.horizontal, geometry.size.width * 0.03)

                            VStack {
                                Button(action: {
                                    DataManager.shared.syncHealthData {
                                        print("Health data synchronized")
                                    }
                                    print("button pressed")
                                }) {
                                    Image(systemName: "arrow.right.circle.fill")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: geometry.size.width * 0.1, height: geometry.size.width * 0.1)
                                        .foregroundColor(.white)
                                        .background(Color.blue)
                                        .cornerRadius(geometry.size.width * 0.05)
                                        .padding(geometry.size.width * 0.02)
                                        .shadow(color: .gray, radius: geometry.size.width * 0.002, x: 0, y: geometry.size.width * 0.002)
                                }
                                .frame(width: geometry.size.width * 0.18, height: geometry.size.width * 0.18)
                                Text("Data").fontWeight(.semibold).foregroundColor(.white)
                            }
                            .cornerRadius(geometry.size.width * 0.03)
                            .padding(geometry.size.width * 0.02)

                            VStack {
                                NavigationLink(destination: SettingsView(showSignInView: $showSignInView)) {
                                    Image(systemName: "arrow.right.circle.fill")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: geometry.size.width * 0.1, height: geometry.size.width * 0.1)
                                        .foregroundColor(.white)
                                        .background(pastelBlue)
                                        .cornerRadius(geometry.size.width * 0.05)
                                        .padding(geometry.size.width * 0.02)
                                        .shadow(color: .gray, radius: geometry.size.width * 0.002, x: 0, y: geometry.size.width * 0.002)
                                }
                                .frame(width: geometry.size.width * 0.18, height: geometry.size.width * 0.18)
                                Text("Account Settings").fontWeight(.semibold).foregroundColor(.white)
                            }
                            .padding(.horizontal, geometry.size.width * 0.03)

                            Spacer()
                        }

                        Spacer()
                        Rectangle()
                            .foregroundColor(backgroundColor2)
                            .edgesIgnoringSafeArea(.bottom)
                            .frame(height: geometry.size.height * 0.05)
                    }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .bottomBar) {
                        NavigationLink(destination: TherapySettings()) {
                            Text("Therapy Settings")
                        }
                        .fontWeight(.semibold)
                        .frame(width: geometry.size.width * 0.4, height: geometry.size.height * 0.07)
                        .padding()
                        .foregroundColor(Color.white)
                        .background(pastelBlue)
                        .cornerRadius(geometry.size.height * 0.04)
                        .padding(.horizontal, geometry.size.width * 0.05)
                        .shadow(color: .gray, radius: geometry.size.width * 0.002, x: 0, y: geometry.size.width * 0.002)
                    }
                }
            }
            .onAppear {
                DataManager.shared.requestAuthorization { success in
                    if success {
                        print("Authorization granted")
                    } else {
                        print("Authorization denied")
                    }
                }
            }
        }
    }
}

struct Template: View {
    var body: some View {
        Text("Hello")
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        HomeScreen(showSignInView: .constant(false))
    }
}

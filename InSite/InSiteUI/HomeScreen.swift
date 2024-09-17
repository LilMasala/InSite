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
        NavigationStack {
            ZStack {
                Color(UIColor.six).ignoresSafeArea()
                VStack(spacing: 20) {
                    Text("InSite")
                        .font(.title)
                        .fontWeight(.light)
                        .padding(20)
                        .background(RoundedRectangle(cornerRadius: 20).fill(pastelBlue).shadow(color: .gray, radius: 0, x: 0, y: 2))
                        .foregroundColor(Color.white)
                        .frame(width: 250, height: 100)
                    
                    Image("BearBlue")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 300, height: 300)
                        .clipShape(Circle())
                        .overlay(
                            Circle().stroke(pastelBlue, lineWidth: 4).shadow(color: Color.brown, radius: 2, x: 0, y: 0).clipShape(Circle())
                        )
                    
                    HStack(spacing: 5) {
                        Spacer()
                        
                        VStack {
                            NavigationLink(destination: SiteChangeUI()) {
                                Image(systemName: "arrow.right.circle.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(.white)
                                    .background(pastelBlue)
                                    .cornerRadius(20)
                                    .padding()
                                    .shadow(color: .gray, radius: 0, x: 0, y: 2)
                            }
                            .frame(width: 70, height: 70)
                            Text("Change Site").fontWeight(.semibold).foregroundColor(.white)
                        }
                        .padding(.horizontal, 10)
                        
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
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(.white)
                                    .background(Color.blue)
                                    .cornerRadius(20)
                                    .padding()
                                    .shadow(color: .gray, radius: 0, x: 0, y: 2)
                            }
                            .frame(width: 70, height: 70)
                            Text("Data").fontWeight(.semibold).foregroundColor(.white)
                        }
                        .cornerRadius(10)
                        .padding()
                        
                        VStack {
                            NavigationLink(destination: SettingsView(showSignInView: $showSignInView)) {
                                Image(systemName: "arrow.right.circle.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(.white)
                                    .background(pastelBlue)
                                    .cornerRadius(20)
                                    .padding()
                                    .shadow(color: .gray, radius: 0, x: 0, y: 2)
                            }
                            .frame(width: 70, height: 70)
                            Text("Account Settings").fontWeight(.semibold).foregroundColor(.white)
                        }
                        .padding(.horizontal, 10)
                        
                        Spacer()
                    }
                    
                    Spacer()
                    Rectangle().foregroundColor(backgroundColor2).edgesIgnoringSafeArea(.bottom).frame(height: 40)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    NavigationLink(destination: TherapySettings()) {
                        Text("Therapy Settings")
                    }
                    .fontWeight(.semibold)
                    .frame(width: 150, height: 50)
                    .padding()
                    .foregroundColor(Color.white)
                    .background(pastelBlue)
                    .cornerRadius(40)
                    .padding(.horizontal, 20)
                    .shadow(color: .gray, radius: 0, x: 0, y: 2)
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

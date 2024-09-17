////
////  File.swift
////  InSite
////
////  Created by Anand Parikh on 6/21/24.
////
//
//import Foundation
////
////  ContentView.swift
////  InSite
////
////  Created by Anand Parikh on 12/13/23.
////
//
import SwiftUI
extension UIColor {
    public class var main: UIColor {
        return #colorLiteral(red: 0.9999808669, green: 0.8820157647, blue: 0.7266988158, alpha: 1)
    }
    public class var main2: UIColor {
        return #colorLiteral(red: 0.9947795272, green: 0.9798920751, blue: 0.9369593263, alpha: 1)
    }
    public class var secondary: UIColor {
        return #colorLiteral(red: 0.8482455611, green: 0.5347130299, blue: 0.351773262, alpha: 1)
    }
    public class var tertiary: UIColor {
        return #colorLiteral(red: 1, green: 0.6300242543, blue: 0.4962518215, alpha: 1)
    }
    public class var quaternary: UIColor {
        return #colorLiteral(red: 0.8808667064, green: 0.9107760191, blue: 0.8714211583, alpha: 1)
    }
    public class var quintary:UIColor {
        return #colorLiteral(red: 0.6030284166, green: 0.7453445196, blue: 0.7043785453, alpha: 1)
    }
    public class var six: UIColor {
        return #colorLiteral(red: 0.9785200953, green: 0.9088581204, blue: 0.9193435311, alpha: 1)

    }
    public class var pastelPink: UIColor {
        return #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
    }
}

//struct CustomHomeButton: View {
//    var title: String
//    var action: () -> Void
//    let customcolor = Color(
//        #colorLiteral(red: 0.8188197613, green: 0.4818899035, blue: 0.3268653452, alpha: 1)
//    )
//    let textColor = Color(
//        #colorLiteral(red: 1, green: 0.9512407184, blue: 0.8039235473, alpha: 1))
//
//
//    var body: some View {
//        GeometryReader { geometry in
//            Button(action: action) {
//                Text(title)
//                    .frame(width: geometry.size.width * 0.7, height: geometry.size.height * 0.5)
//            }
//            .padding()
//            .background(customcolor)
//            .foregroundColor(textColor)
//            .cornerRadius(geometry.size.width * 0.4)
//            .font(.subheadline)
//            .shadow(radius: 4)
//        }
//    }
//}
//
//import SwiftUI
//
//
//struct HomeScreen: View {
//
//    let textColor = Color(
//        #colorLiteral(red: 0.9098337293, green: 0.5442788601, blue: 0.3945763707, alpha: 1)
//    )
//    let backgroundColor = Color(
//        #colorLiteral(red: 0.97650069, green: 0.9073963761, blue: 0.9259181619, alpha: 1)
//    )
//    let backgroundColor2 = Color(
//        #colorLiteral(red: 0.9999999404, green: 1, blue: 1, alpha: 0.2986688066)
//    )
//    let pastelBlue = Color(
//        #colorLiteral(red: 0.7313573956, green: 0.8990380168, blue: 0.9520341754, alpha: 1)
//    )
//
//    var body: some View {
//        NavigationStack {
//            ZStack{
//                Color(UIColor.six)
//                    .ignoresSafeArea()
//                VStack(spacing:20) {
//
//                    Text("InSite")
//                        .font(.title)
//                        .fontWeight(.light)
//                        .padding(20)
//                        .background(RoundedRectangle(cornerRadius: 20).fill(pastelBlue).shadow(color: .gray, radius: 0, x: 0, y:2))
//                        .foregroundColor(Color.white)
//                        .frame(width:250, height: 100)
//
//
//                    Image("BearBlue")
//                        .resizable()
//                        .scaledToFill()
//                        .frame(width: 300, height: 300)
//                        .clipShape(Circle())
//                        .overlay(
//                            Circle()
//                                .stroke(pastelBlue, lineWidth: 4)
//                                .shadow(color: Color.brown
//                                        , radius: 2, x: 0, y: 0)
//                                .clipShape(Circle())
//                        )
//                    HStack(spacing:5) {
//                        Spacer()
//
//
//                        VStack {
//                            NavigationLink(destination: SiteChangeUI()) {
//                                Image(systemName: "arrow.right.circle.fill") // Replace with your image name
//                                    .resizable()
//                                    .aspectRatio(contentMode: .fit)
//                                    .frame(width: 40, height: 40) // Adjust the size as needed
//                                    .foregroundColor(.white)
//                                    .background(pastelBlue)
//                                    .cornerRadius(20) // Adjust for rounded corners
//                                    .padding()
//                                    .shadow(color: .gray, radius: 0, x: 0, y: 2)
//                            }
//                            .frame(width: 70, height: 70) // Adjust the frame size as needed
//
//                            // Text label below the button
//                            Text("Change Site")
//                                .fontWeight(.semibold)
//                                .foregroundColor(.white)
//                        }
//                        .padding(.horizontal, 10)
//
//
//                        VStack {
//                            Button(action: {
//                                // Insert the action you want to perform here.
//                                //IDEA here is to call syncHealthData
//                                // For example, call your sync function:
//                                DataManager.shared.syncHealthData()
//                            }) {
//                                // Using an Image within the Button to keep the visual style you want
//                                Image(systemName: "arrow.right.circle.fill") // Replace with your image name if needed
//                                    .resizable()
//                                    .aspectRatio(contentMode: .fit)
//                                    .frame(width: 40, height: 40) // Adjust the size as needed
//                                    .foregroundColor(.white)
//                                    .background(Color.blue) // Replace 'pastelBlue' with your color variable if you have one
//                                    .cornerRadius(20) // Adjust for rounded corners
//                                    .padding()
//                                    .shadow(color: .gray, radius: 0, x: 0, y: 2)
//                            }
//                            .frame(width: 70, height: 70) // Adjust the frame size as needed
//
//                            // Text label below the button
//                            Text("Data")
//                                .fontWeight(.semibold)
//                                .foregroundColor(.white)
//                        }
//                        .cornerRadius(10) // Optionally round the corners of the entire VStack
//                        .padding()
//
//
//                    VStack {
//                        NavigationLink(destination: SiteChangeUI()) {
//                            Image(systemName: "arrow.right.circle.fill") // Replace with your image name
//                                .resizable()
//                                .aspectRatio(contentMode: .fit)
//                                .frame(width: 40, height: 40) // Adjust the size as needed
//                                .foregroundColor(.white)
//                                .background(pastelBlue)
//                                .cornerRadius(20) // Adjust for rounded corners
//                                .padding()
//                                .shadow(color: .gray, radius: 0, x: 0, y: 2)
//                        }
//                        .frame(width: 70, height: 70) // Adjust the frame size as needed
//
//                        // Text label below the button
//                        Text("Low Foods")
//                            .fontWeight(.semibold)
//                            .foregroundColor(.white)
//                    }
//                    .padding(.horizontal, 10)
//
//                        Spacer()
//                    }
//
//                    Spacer()
//                    Rectangle()
//                        .foregroundColor(backgroundColor2)
//                        .edgesIgnoringSafeArea(.bottom)
//                        .frame(height:40)
//
//                }
//
//            }
//            .toolbar {
//                ToolbarItemGroup(placement: .bottomBar) {
//                    NavigationLink(destination: {
//                        TherapySettings()
//                    }, label: {
//                        Text("Therapy Settings")
//                    })
//                    .fontWeight(.semibold)
//                    .frame(width: 150, height: 50)
//                    .padding()
//                    .foregroundColor(Color.white)
//                    .background(pastelBlue)
//                    .cornerRadius(40)
//                    .padding(.horizontal, 20)
//                    .shadow(color: .gray, radius: 0, x: 0, y: 2)
//
//                }
//            }
//        }
//    }
//}
//
//struct Template: View {
//    var body: some View {
//        Text("Hello")
//    }
//}
//
//
//
//struct ContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        HomeScreen()
//
//    }
//}

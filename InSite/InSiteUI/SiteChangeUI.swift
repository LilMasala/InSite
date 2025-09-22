//
//  SiteChangeUI.swift
//  InSite
//
//  Created by Anand Parikh on 12/14/23.
//

import Foundation
import SwiftUI


struct CustomSwiftButton: View {
    var title: String
    var action: () -> Void
    let customcolor = Color(
        #colorLiteral(red: 0.8188197613, green: 0.4818899035, blue: 0.3268653452, alpha: 1)
    )
    let textColor = Color(
        #colorLiteral(red: 1, green: 0.9512407184, blue: 0.8039235473, alpha: 1))

   
    var body: some View {
        GeometryReader { geometry in
            Button(action: action) {
                Text(title)
                    .frame(width: geometry.size.width * 0.7, height: geometry.size.height * 0.5)
            }
            .padding()
            .background(customcolor)
            .foregroundColor(textColor)
            .cornerRadius(geometry.size.width * 0.4)
            .font(.subheadline)
            .shadow(radius: geometry.size.width * 0.05)
        }
    }
}


struct SiteChangeUI: View {
    
    @ObservedObject var sharedData = SiteChangeData.shared
    @State var title: String = "This is my title"
    @State private var showAlert = false
    @State var siteChangeLocation: String? = nil
    @State var daysSinceSiteChange = 0
    @State private var tempSiteChangeLocation: String? = nil

   
    let customcolor = Color(
        #colorLiteral(red: 0.8188197613, green: 0.4818899035, blue: 0.3268653452, alpha: 1)
    )
    let textColor = Color(
        #colorLiteral(red: 1, green: 0.9512407184, blue: 0.8039235473, alpha: 1))
    
    let backgroundGradient = LinearGradient(
        colors: [Color(
            #colorLiteral(red: 0.586845994, green: 0.8702697158, blue: 0.7958573699, alpha: 0.39)
        ), Color(
        
            #colorLiteral(red: 0.9761297107, green: 0.8942978382, blue: 0.7468113303, alpha: 0.496847181)
        )],
        startPoint: .top, endPoint: .bottom)
    
    
    
    var body: some View {
        GeometryReader { geometry in
            ZStack{
                
                backgroundGradient
                
                
                VStack(spacing: geometry.size.height * 0.05) {
                    
                    Text("Site Change")
                        .font(.largeTitle)
                        .padding(geometry.size.height * 0.02)
                        .background(RoundedRectangle(cornerRadius: geometry.size.height * 0.03).fill(customcolor).shadow(radius: geometry.size.height * 0.03))
                        .foregroundColor(textColor)
                    
                    
                    Image("Bear")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width * 0.8, height: geometry.size.height * 0.35)
                        .clipped()
                        .cornerRadius(geometry.size.width * 0.125)
                        .shadow(radius: geometry.size.width * 0.05)
                    
                    
                    VStack(spacing: geometry.size.height * 0.04) {
                        HStack(spacing: geometry.size.width * 0.025) {
                            
                            CustomSwiftButton(title: "L Butt") {
                                self.tempSiteChangeLocation = "Left Butt"
                                self.showAlert = true
                            }
                            
                            CustomSwiftButton(title: "L Thigh") {
                                self.tempSiteChangeLocation = "Left Thigh"
                                self.showAlert = true
                            }
                            
                            CustomSwiftButton(title: "L Ab") {
                                self.tempSiteChangeLocation = "Left Abdomen"
                                self.showAlert = true
                            }
                            
                            CustomSwiftButton(title: "L Arm") {
                                self.tempSiteChangeLocation = "Left Arm"
                                self.showAlert = true
                            }
                            
                        }
                        HStack(spacing: geometry.size.width * 0.025) {
                            CustomSwiftButton(title: "R Butt") {
                                self.tempSiteChangeLocation = "Right Butt"
                                self.showAlert = true
                            }
                            
                            CustomSwiftButton(title: "R Thigh") {
                                self.tempSiteChangeLocation = "Right Thigh"
                                self.showAlert = true
                            }
                            
                            CustomSwiftButton(title: "R Ab") {
                                self.tempSiteChangeLocation = "Right Abdomen"
                                self.showAlert = true
                            }
                            
                            CustomSwiftButton(title: "R Arm") {
                                self.tempSiteChangeLocation = "Right Arm"
                                self.showAlert = true
                            }
                            
                        }
                    }
                    HStack(spacing: geometry.size.width * 0.02){
                        Text("Current Site Location: \(self.sharedData.siteChangeLocation)")
                            .font(.body)
                            .padding(geometry.size.height * 0.015)
                            .background(RoundedRectangle(cornerRadius: geometry.size.height * 0.02).fill(customcolor).shadow(radius: geometry.size.height * 0.02))
                            .foregroundColor(textColor)
                        Text("Days Until Change: \(max(0, 3 - self.sharedData.daysSinceSiteChange))")
                            .font(.body)
                            .padding(geometry.size.height * 0.02)
                            .background(RoundedRectangle(cornerRadius: geometry.size.height * 0.02).fill(customcolor).shadow(radius: geometry.size.height * 0.02))
                            .foregroundColor(textColor)
                    }
                    
                    Spacer()
                }
                .padding(.top, geometry.size.height * 0.06)
                .padding()
                
            }
        }
        .ignoresSafeArea()
        .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Change Site"),
                    message: Text("Are you sure you want to change site to \(tempSiteChangeLocation ?? "")?"),
                    primaryButton: .default(Text("Yes")) {
                        let loc = self.tempSiteChangeLocation ?? "Not selected"

                        // Update local UI immediately
                        self.sharedData.setSiteChange(location: loc)

                        // Event + seed today + backfill (race-free)
                        HealthDataUploader().recordSiteChange(location: loc, localTz: .current, backfillDays: 14)
                    },
                    secondaryButton: .cancel()

            )
        }
            }
        }


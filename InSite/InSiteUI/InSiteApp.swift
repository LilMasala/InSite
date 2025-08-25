//
//  InSiteApp.swift
//  InSite
//
//  Created by Anand Parikh on 12/13/23.
//
import SwiftUI
import FirebaseCore
import FirebaseAppCheck

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {

    #if DEBUG
    // 1) Set the App Check provider BEFORE configure()
    AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
    // (optional) make logs verbose so you see the token line
    FirebaseConfiguration.shared.setLoggerLevel(.debug)
    #endif

    // 2) Then configure Firebase
    FirebaseApp.configure()

    return true
  }
}

@main
struct YourApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
  var body: some Scene { WindowGroup { RootView() } }
}

//
//  iCloudPhotoManagerApp.swift
//  Shared
//
//  Created by Oleksandr Krasnobaiev on 12/30/20.
//

import SwiftUI

class StateModel: ObservableObject {
  public var app: iCloudPhotoManagerApp?
  @State public var selectedTab = 0
}

class AppState: ObservableObject {
  static let shared = AppState()    // << here !!
  @Published public var selectedTab = 0
  @Published var contentView: ContentView?
  //@Published var tabBarAppearance = UITabBar.appearance()
  // Singe source of truth...
  //@ObservedObject public var appState: StateModel = StateModel()
}

@main
struct iCloudPhotoManagerApp: App {
  @State public var selection = 0
  init() {
    //AppState.shared.appState.contentView = ContentView(selectedTab: AppState.shared.$appState.selectedTab)
    //AppState.shared.appState.app = self
    //AppState.shared.tabBarAppearance.barTintColor = UIColor.red
    //AppState.shared.tabBarAppearance.barTintColor = UIColor.red
    //UITabBarItem.appearance().setTitleTextAttributes([NSAttributedString.Key.font: UIFont.init(name: "Avenir-Heavy", size: 35)! ], for: .normal)
    //AppState.shared.tabBarAppearance.isHidden = true
  }
  
  var body: some Scene {
    let index = Binding<Int>(
                   get: { self.selection },
                   set: {
                       self.selection = $0
                    AppState.shared.selectedTab = $0
                   })
    WindowGroup {
      TabView(selection:index,
              content:  {
                ContentView(selectedTab: index).tabItem { Text("Tab Label 1") }.tag(0)
                //AppState.shared.appState.contentView.tabItem { Text("Tab Label 1") }.tag(0)
                SettingsView(selectedTab: index).tabItem { Text("Tab Label 2") }.tag(1)
              }).id(self.selection)
    }
  }
}

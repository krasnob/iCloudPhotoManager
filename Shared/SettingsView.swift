//
//  ContentView.swift
//  Shared
//
//  Created by Oleksandr Krasnobaiev on 12/30/20.
//

import SwiftUI


struct SettingsView: View {
  @Binding var selectedTab: Int
  var body: some View {
    VStack(alignment: .center) {
      Text("Hello, World!")
        .frame(maxWidth: .infinity, maxHeight: 100)
      Button(action: {
        //self.testText = "Hi"
        print("Here")
         PhotoLibManagement.sharedInstance().refreshMediaAssets()
        
      }) {
        Text("Tap Here")
      }
      Button(action: {
        //self.testText = "Hi"
        print("Here")
         PhotoLibManagement.sharedInstance().downloadMedia()
        
      }) {
        Text("Download")
      }
      Button(action: {
        selectedTab = 0
      }) {
        Text("Switch")
      }
    }
  }
}



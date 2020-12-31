//
//  iCloudPhotoManagerApp.swift
//  Shared
//
//  Created by Oleksandr Krasnobaiev on 12/30/20.
//

import SwiftUI

class AppState: ObservableObject {
    static let shared = AppState()    // << here !!

    // Singe source of truth...
  @Published var contentView: ContentView?
}

@main
struct iCloudPhotoManagerApp: App {
  init() {
    AppState.shared.contentView = ContentView()
  }
  
    var body: some Scene {
        WindowGroup {
          AppState.shared.contentView
        }
    }
}

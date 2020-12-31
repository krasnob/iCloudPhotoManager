//
//  ContentView.swift
//  Shared
//
//  Created by Oleksandr Krasnobaiev on 12/30/20.
//

import SwiftUI

class ViewModel: ObservableObject {
  @Published public var testText = "Hello"
}

struct ContentView: View {
  @ObservedObject public var viewModel: ViewModel = ViewModel()
  var body: some View {
    VStack(alignment: .center) {
      Text("Hello, World!")
        .frame(maxWidth: .infinity, maxHeight: 100)
      Button(action: {
        //self.testText = "Hi"
        print("Here")
         PhotoLibManagement.sharedInstance().getAllMedia(sortBy: .Size)
        
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
         PhotoLibManagement.sharedInstance().deleteMediaWithIndex(0)
        
      }) {
        Text("Delete")
      }
      Text(self.viewModel.testText)
        .frame(maxWidth: .infinity, maxHeight: 100)
      //NSTableView()
    }
  }
}


struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}


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

class ImageLoaderModel: ObservableObject {
  @Published public var uiImage: UIImage?
}

struct SampleRow: View {
  let idx: Int
  let parent: Any
  @ObservedObject public var imageLoaderModel = ImageLoaderModel()
  
  var body: some View {
    if let uiImage = imageLoaderModel.uiImage {
#if os(macOS)
      Image(nsImage: uiImage).resizable()
        .scaledToFit()
#else
      Image(uiImage: uiImage).resizable()
        .scaledToFit()
#endif
    } else {
      Text("Row \(idx)").background(Color.blue)
    }
  }
  
  init(idx: Int, parent: Any) {
    print("Loading row \(idx)")
    self.parent = parent
    self.idx = idx
    PhotoLibManagement.sharedInstance().getThumbnail(forIndex: idx, targetSize: CGSize.zero, withImageLoader: imageLoaderModel)
  }
}

struct ContentView: View {
  @ObservedObject public var viewModel: ViewModel = ViewModel()
  @Binding var selectedTab: Int
  
  let columns = [
    GridItem(.adaptive(minimum: 80))
  ]
  init(selectedTab: Binding<Int>) {
    self._selectedTab = selectedTab
    AppState.shared.contentView = self
  }
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
      Button(action: {
        self.selectedTab = 1
        //AppState.shared.tabBarAppearance.barTintColor = UIColor.green
        //AppState.shared.tabBar.isHidden = false
      }) {
        Text("Switch")
      }
      ScrollView {
        LazyVGrid(columns: columns, spacing: 20) {
          ForEach(0 ..< PhotoLibManagement.sharedInstance().mediaCount(), id: \.self) { idx in
            SampleRow(idx: idx, parent: self)
            
          }
        }
        .padding(.horizontal)
      }
      /*ForEach((1...10).reversed(), id: \.self) {
       Text("\($0)…")
       }*/
      //NSTableView()r
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  @State static var selectedTab = 1
  static var previews: some View {
    ContentView(selectedTab: $selectedTab)
  }
}

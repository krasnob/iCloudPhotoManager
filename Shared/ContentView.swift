//
//  ContentView.swift
//  Shared
//
//  Created by Oleksandr Krasnobaiev on 12/30/20.
//

import SwiftUI
#if !os(macOS)
import UIKit
#endif

class ViewModel: ObservableObject {
  @Published public var testText = "Hello"
  @Published var cellMinimumWidth: CGFloat = 80
  @Published var selectedImages: Array<Bool> = []
  @Published var lastSelectedImageIndex: Int = 0
  @Published var areAllmagesSelected: Bool = false
}

class ImageLoaderModel: ObservableObject {
  @Published public var uiImage: UIImage?
  @Published public var fileSize: String?
  @Published public var fileName: String?
  //@Published public var
}

#if os(macOS)
class DraggableImageView: NSImageView, NSDraggingSource, NSFilePromiseProviderDelegate {
  var idx: Int?
  
  func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
    return PhotoLibManagement.sharedInstance().getFileOrFolderNameFor(index: self.idx ?? -1)
  }
  
  func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, writePromiseTo url: URL, completionHandler: @escaping (Error?) -> Void) {
    PhotoLibManagement.sharedInstance().saveAssetWithIndex(self.idx ?? -1, toUrl: url, withCompletionhandler: completionHandler)
    return
  }
  
  
  func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
    return .copy
  }
  
  override func mouseDown(with event: NSEvent) {
    print("Here1")
  }
  
  override func mouseDragged(with theEvent: NSEvent) {
    guard let image = self.image else { return }
    //1.
    let filePromiseWriter = NSFilePromiseProvider(fileType: kUTTypeData as String, delegate: self)
    
    //2.
    let draggingItem = NSDraggingItem(pasteboardWriter: filePromiseWriter)
    draggingItem.setDraggingFrame(CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height), contents: image)
    
    //3.
    let draggingSession = beginDraggingSession(with: [draggingItem], event: theEvent, source: self)
    draggingSession.draggingFormation = .pile
  }
}


struct CellImageView: NSViewRepresentable {
  var image: NSImage
  var width: CGFloat
  var idx: Int
  
  func makeNSView(context: Context) -> DraggableImageView {
    let imageView = DraggableImageView()
    imageView.idx = self.idx
    resizeImage(imageView)
    return imageView
  }
  
  
  func updateNSView(_ uiView: DraggableImageView, context: Context) {
    resizeImage(uiView)
  }
  
  func resizeImage(_ imageView: DraggableImageView) {
    let aspectRatio = self.image.size.height / self.image.size.width
    self.image.size.width = width
    self.image.size.height = width * aspectRatio
    imageView.image = self.image
  }
  
}
#endif

func markRangeSelected(clickedIndex: Int) {
  guard let viewModel = AppState.shared.contentView?.viewModel else {
    return
  }
  if (clickedIndex < viewModel.selectedImages.count) {
    for i in 0 ..< viewModel.selectedImages.count {
      if viewModel.selectedImages[i] {
        for j in i ... clickedIndex {
          viewModel.selectedImages[j] = true
        }
        break
      }
    }
  }
}

struct CheckView: View {
  @ObservedObject var viewModel: ViewModel
  var idx: Int
  
  func toggle() {
    self.viewModel.lastSelectedImageIndex = idx
    self.viewModel.selectedImages[idx] = !self.viewModel.selectedImages[idx]
  }
  var body: some View {
    
    HStack{
      #if os(macOS)
      Image(systemName: (self.viewModel.selectedImages.count > idx && self.viewModel.selectedImages[idx]) ? "checkmark.square": "square").font(.system(size: 20))
        .gesture(TapGesture().modifiers(.shift).onEnded {
          markRangeSelected(clickedIndex: self.idx)
        }).background(Color.init(.sRGB, red: 255, green: 255, blue: 255, opacity: 0.3))
        .onTapGesture {
          toggle()
        }
        .onLongPressGesture {
          print("Long Press")
          toggle()
        }
      
      #else
      Image(systemName: (self.viewModel.selectedImages.count > idx && self.viewModel.selectedImages[idx]) ? "checkmark.square": "square").font(.system(size: 20))
        .onTapGesture {
          toggle()
        }.onLongPressGesture {
          markRangeSelected(clickedIndex: self.idx)
        }
      #endif
    }
  }
}

struct SampleRow: View {
  let idx: Int
  let parent: Any
  let width: CGFloat
  let viewModel: ViewModel
  @ObservedObject public var imageLoaderModel = ImageLoaderModel()
  
  var body: some View {
    VStack(alignment: .center) {
      if let uiImage = imageLoaderModel.uiImage {
        ZStack(alignment: .topTrailing) {
          #if os(macOS)
          CellImageView(image: uiImage, width: self.width, idx: self.idx)
          #else
          Image(uiImage: uiImage).resizable()
            .scaledToFit()
          #endif
          CheckView(viewModel: viewModel, idx: idx)
        }
        Text((imageLoaderModel.fileName ?? "NA") + " " + (imageLoaderModel.fileSize ?? "NA"))
        //Toggle("x", isOn: $status).onTapGesture {
        //  print("Here \(status)")
        //}
      } else {
        Text("Row \(idx)").background(Color.blue)
      }
    } // .background(Color.red)
  }
  
  init(idx: Int, parent: Any, width: CGFloat, viewModel: ViewModel) {
    //print("Loading row \(idx)")
    self.parent = parent
    self.idx = idx
    self.width = width
    self.viewModel = viewModel
    PhotoLibManagement.sharedInstance().getThumbnail(forIndex: idx, targetSize: CGSize(width: width, height: width), withImageLoader: imageLoaderModel)
  }
}

struct ContentView: View {
  @Binding var selectedTab: Int
  @ObservedObject var viewModel: ViewModel

  init(selectedTab: Binding<Int>, viewModel: ViewModel) {
    self._selectedTab = selectedTab
    self.viewModel = viewModel
    AppState.shared.contentView = self
  }
  var body: some View {
    VStack(alignment: .center) {
      HStack(alignment: .center) {
        Button(action: {
          self.viewModel.cellMinimumWidth -= 10
        }) {
          Text("-")
        }
        
        Button(action: {
          self.viewModel.cellMinimumWidth += 10
        }) {
          Text("+").font(.system(size: 20))
        }
      }
      HStack(alignment: .center) {
        Button(action: {
          //self.testText = "Hi"
          print("Here")
          PhotoLibManagement.sharedInstance().getAllMedia(sortBy: .Size)
          
        }) {
          Text("Tap Here")
        }
        Button(action: {
          self.viewModel.areAllmagesSelected = !self.viewModel.areAllmagesSelected
          for i in 0 ..< (AppState.shared.contentView?.viewModel.selectedImages.count ?? 0) {
            self.viewModel.selectedImages[i] = self.viewModel.areAllmagesSelected
          }
        }) {
          Text("Select All")
        }
      }
      Button(action: {
        //self.testText = "Hi"
        print("Here")
        PhotoLibManagement.sharedInstance().downloadSelectedMediaToUserSelectedFolder()
        
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
        LazyVGrid(columns: [
          GridItem(.adaptive(minimum: viewModel.cellMinimumWidth))
        ], spacing: 20) {
          ForEach(0 ..< PhotoLibManagement.sharedInstance().mediaCount(), id: \.self) { idx in
            SampleRow(idx: idx, parent: self, width: self.viewModel.cellMinimumWidth, viewModel: self.viewModel)
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
  @State static var viewModel = ViewModel()
  static var previews: some View {
    ContentView(selectedTab: $selectedTab, viewModel: viewModel)
  }
}

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
}

class ImageLoaderModel: ObservableObject {
  @Published public var uiImage: UIImage?
  @Published public var fileSize: String?
  @Published public var fileName: String?
  //@Published public var
}

public class MyFilePromiseProvider : NSFilePromiseProvider {
    
}

class DraggableImageView: NSImageView, NSDraggingSource, NSPasteboardItemDataProvider, NSFilePromiseProviderDelegate, NSPasteboardWriting {
  func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
    return  [kUTTypeData as NSPasteboard.PasteboardType]
  }
  
  func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
    [kUTTypeData as NSPasteboard.PasteboardType]
  }
  
  func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
    return "hello.txt"
  }
  
  func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, writePromiseTo url: URL, completionHandler: @escaping (Error?) -> Void) {
    return
  }
  
  
  
  func pasteboard(_ pasteboard: NSPasteboard?, item: NSPasteboardItem, provideDataForType type: NSPasteboard.PasteboardType) {
    return
  }
  
  func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
    return .copy
  }
  
  override func mouseDown(with theEvent: NSEvent) {
    //1.
    let pasteboardItem = NSFilePromiseProvider(fileType: kUTTypeData as String, delegate: self)
    
    //2.
    let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
    draggingItem.setDraggingFrame(self.bounds, contents:self.image)
    
    //3.
    beginDraggingSession(with: [draggingItem], event: theEvent, source: self)
  }
}


struct CellImageView: NSViewRepresentable {
  var image: NSImage
  var width: CGFloat
  
  func makeNSView(context: Context) -> DraggableImageView {
    let imageView = DraggableImageView()
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

struct SampleRow: View {
  let idx: Int
  let parent: Any
  let width: CGFloat
  @ObservedObject public var imageLoaderModel = ImageLoaderModel()
  
  var body: some View {
    VStack(alignment: .center) {
      if let uiImage = imageLoaderModel.uiImage {
        #if os(macOS)
        CellImageView(image: uiImage, width: self.width)//.resizable()
        #else
        Image(uiImage: uiImage).resizable()
          .scaledToFit()
        #endif
        Text((imageLoaderModel.fileName ?? "NA") + " " + (imageLoaderModel.fileSize ?? "NA"))
      } else {
        Text("Row \(idx)").background(Color.blue)
      }
    }
  }
  
  init(idx: Int, parent: Any, width: CGFloat) {
    print("Loading row \(idx)")
    self.parent = parent
    self.idx = idx
    self.width = width
    PhotoLibManagement.sharedInstance().getThumbnail(forIndex: idx, targetSize: CGSize(width: width, height: width), withImageLoader: imageLoaderModel)
  }
}

struct ContentView: View {
  @ObservedObject public var viewModel: ViewModel = ViewModel()
  @Binding var selectedTab: Int
  init(selectedTab: Binding<Int>) {
    self._selectedTab = selectedTab
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
          Text("+")
        }
      }
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
        LazyVGrid(columns: [
          GridItem(.adaptive(minimum: viewModel.cellMinimumWidth))
        ], spacing: 20) {
          ForEach(0 ..< PhotoLibManagement.sharedInstance().mediaCount(), id: \.self) { idx in
            SampleRow(idx: idx, parent: self, width: self.viewModel.cellMinimumWidth)
            
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

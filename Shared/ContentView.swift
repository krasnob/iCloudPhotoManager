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
  @Published var sortOrder: PhotoLibManagement.SortOrder = PhotoLibManagement.SortOrder.Descending
  @Published var sortBy: PhotoLibManagement.Sort = PhotoLibManagement.Sort.Size
  @Published var currentSaveProgress: Double = 0
}

class ImageLoaderModel: ObservableObject {
  @Published public var uiImage: UIImage?
  @Published public var fileSize: String?
  @Published public var fileName: String?
  @Published public var fileDate: String?
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
        let selectedArray = stride(from: i, to: clickedIndex, by: i > clickedIndex ? -1 : 1)
        for j in selectedArray {
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
        .background(Color.init(.sRGB, red: 0, green: 0, blue: 0, opacity: 0.1))
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
  let parent: ContentView
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
            .scaledToFit()//.animation(.easeInOut)
#endif
          CheckView(viewModel: viewModel, idx: idx)
        }
        Text("\(imageLoaderModel.fileName ?? "NA") \(imageLoaderModel.fileDate ?? "NA") \(imageLoaderModel.fileSize ?? "NA")")
        //Toggle("x", isOn: $status).onTapGesture {
        //  print("Here \(status)")
        //}
      } else {
        Text("Row \(idx)").background(Color.blue)
      }
    } // .background(Color.red)
  }
  
  init(idx: Int, parent: ContentView, width: CGFloat, viewModel: ViewModel) {
    //print("Loading row \(idx)")
    self.parent = parent
    self.idx = idx
    self.width = width
    self.viewModel = viewModel
    PhotoLibManagement.sharedInstance().getThumbnail(forIndex: idx, targetSize: CGSize(width: width * self.parent.scale, height: width * self.parent.scale), withImageLoader: imageLoaderModel)
  }
}

struct ContentView: View {
  @Binding var selectedTab: Int
  @ObservedObject var viewModel: ViewModel
  
  @State private var isShowingControls = true
  @State private var isShowingProgressView = true
  @State var scale: CGFloat = 1.0
  @State private var sortByInternal: PhotoLibManagement.Sort
  init(selectedTab: Binding<Int>, viewModel: ViewModel) {
    self._selectedTab = selectedTab
    self.viewModel = viewModel
    self.sortByInternal = viewModel.sortBy
    AppState.shared.contentView = self
  }
  
  var body: some View {
    VStack(alignment: .center) {
      if isShowingControls {
        // Controls
        VStack(alignment: .center) {
          HStack(alignment: .center) {
            Text("Sort By:")
            Picker(selection: $sortByInternal, label: Text("")) {
              Text("Size").tag(PhotoLibManagement.Sort.Size)
              Text("Date").tag(PhotoLibManagement.Sort.Date)
            }
            .pickerStyle(SegmentedPickerStyle()).onChange(of: sortByInternal, perform: {sortByInternal in
              self.viewModel.sortBy = sortByInternal
              PhotoLibManagement.sharedInstance().sortMediaAssets()
            })
            Text("Descending").accentColor(.blue).onTapGesture {
              self.viewModel.sortOrder = self.viewModel.sortOrder == .Descending ? .Ascendig : .Descending
              PhotoLibManagement.sharedInstance().sortMediaAssets()
            }
            Image(systemName: self.viewModel.sortOrder == .Descending ? "checkmark.square": "square").font(.system(size: 20)).onTapGesture {
              self.viewModel.sortOrder = self.viewModel.sortOrder == .Descending ? .Ascendig : .Descending
              PhotoLibManagement.sharedInstance().sortMediaAssets()
            }
            
          }
          if self.viewModel.currentSaveProgress > 0 {
            ProgressView(value: self.viewModel.currentSaveProgress)
          }
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
              PhotoLibManagement.sharedInstance().refreshMediaAssets()
              
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
            Button(action: {
              PhotoLibManagement.sharedInstance().cancelAllImageRequests()
            }) {
              Text("Cancel All")
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
            PhotoLibManagement.sharedInstance().deleteSelectedMedias()
            
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
        }
      }
      
      ScrollView {
        LazyVGrid(columns: [
          GridItem(.adaptive(minimum: viewModel.cellMinimumWidth))
        ], spacing: 20) {
          ForEach(0 ..< PhotoLibManagement.sharedInstance().mediaCount(), id: \.self) { idx in
            SampleRow(idx: idx, parent: self, width: self.viewModel.cellMinimumWidth, viewModel: self.viewModel)
          }
        }
        .padding(.horizontal).scaleEffect(self.scale, anchor: .zero)
        .gesture(MagnificationGesture(minimumScaleDelta: 0.1)
                  .onChanged { value in
          self.scale = value
          print("scale: \(self.scale)")
        }.onEnded {value in
          self.scale = 1.0
          self.viewModel.cellMinimumWidth = self.viewModel.cellMinimumWidth * value.magnitude
        })
      }.simultaneousGesture(
        DragGesture().onChanged({
          let isScrollDown = 0 < $0.translation.height
          if self.isShowingControls != isScrollDown {
            withAnimation {
              self.isShowingControls = isScrollDown
            }
          }
        }))
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

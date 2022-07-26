//
//  PhotoLibManagement.swift
//  iCloudPhotoManager
//
//  Created by Oleksandr Krasnobaiev on 11/3/20.
//

import Foundation
#if !os(iOS)
import Cocoa
typealias UIImage = NSImage
#else
import UIKit
#endif
import Photos
import SwiftUI

typealias AssetTuple = (asset: PHAsset, resources: [PHAssetResource])
typealias ImageCacheTuple = (image: UIImage?, imageRequestId: PHImageRequestID, imageLoader: ImageLoaderModel?, lastDownloadedSize: CGSize)

#if os(iOS)
class DocumentPickerDelegateiOS: NSObject, UIDocumentPickerDelegate {
  let fnDownloadSelectedMediaToUrl: (URL) -> Void
  
  init(fnDownloadSelectedMediaToUrl: @escaping (URL) -> Void) {
    self.fnDownloadSelectedMediaToUrl = fnDownloadSelectedMediaToUrl
  }
  
  // MARK: - UIDocumentPickerDelegate
  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
    self.fnDownloadSelectedMediaToUrl(url)
  }
}
#endif

class PhotoLibManagement {
  enum Sort {
    case Size
    case Date
  }
  enum SortOrder {
    case Ascendig
    case Descending
  }
  private static let instance = PhotoLibManagement()
  
  private var authorizationStatus = PHAuthorizationStatus.notDetermined
  private var assetTuplesArray: Array<AssetTuple> = []
  private var imageCacheTuplesArray: Dictionary<String, ImageCacheTuple> = [:]
  private let dateFormatter = DateFormatter()
#if os(iOS)
  private var documentPickerDelegateiOS: DocumentPickerDelegateiOS?;
  let screenScale = UIScreen.main.scale
#else
  let screenScale = NSScreen.main?.backingScaleFactor ?? 1.0
#endif
  
  // MARK: - Public Methods
  
  public static func sharedInstance() -> PhotoLibManagement {
    return instance
  }
  
  public func refreshMediaAssets() {
    self.requestAuthorization()
  }
  
  public func mediaCount() -> Int {
    return self.assetTuplesArray.count
  }
  
  
  public func getThumbnail(forIndex index: Int, targetSize: CGSize, withImageLoader imageLoader: ImageLoaderModel) {
    if (index >= self.mediaCount()) {
      return
    }
    let adjustedTargetSize = CGSize(width: targetSize.width * screenScale, height: targetSize.height * screenScale)
    let asset = self.assetTuplesArray[index].asset
    self.imageCacheTuplesArray[asset.localIdentifier]?.imageLoader = imageLoader
    if let imageCacheTuple = self.imageCacheTuplesArray[asset.localIdentifier] {
      let resource = self.assetTuplesArray[index].resources[0]
      imageLoader.fileName = resource.originalFilename
      imageLoader.fileSize = "\(resource.value(forKey: "fileSize") as? Int ?? 0)"
      if let creationDate = asset.creationDate {
        imageLoader.fileDate = self.dateStringFrom(creationDate) // self.dateFormatter.string(from: creationDate)
      }
      if let cachedImage = imageCacheTuple.image {
        imageLoader.uiImage = cachedImage.copy() as? UIImage
        let lastdownloadedSize = imageCacheTuple.lastDownloadedSize
        if lastdownloadedSize.width >= adjustedTargetSize.width && lastdownloadedSize.height >= adjustedTargetSize.height {
          if (imageCacheTuple.imageRequestId != PHInvalidImageRequestID) {
            PHImageManager.default().cancelImageRequest(imageCacheTuple.imageRequestId)
          }
          return
        }
      } else if imageCacheTuple.lastDownloadedSize.width >= adjustedTargetSize.width && imageCacheTuple.lastDownloadedSize.height >= adjustedTargetSize.height {
        // Request already running
        return
      }
    }
    if let imageCacheTuple = self.imageCacheTuplesArray[asset.localIdentifier],
       imageCacheTuple.imageRequestId != PHInvalidImageRequestID {
      PHImageManager.default().cancelImageRequest(imageCacheTuple.imageRequestId)
    }
    self.imageCacheTuplesArray[asset.localIdentifier]?.lastDownloadedSize = adjustedTargetSize
    DispatchQueue.global(qos: .userInteractive).async {
      let requestOptions = PHImageRequestOptions()
      requestOptions.isNetworkAccessAllowed = true
      requestOptions.version = PHImageRequestOptionsVersion.original
      requestOptions.deliveryMode = .opportunistic
      requestOptions.version = .current
      print("index: \(index) before requestImage")
      let imageRequestId = PHImageManager.default().requestImage(
        for: asset, targetSize: adjustedTargetSize, contentMode: .default, options: requestOptions, resultHandler:
            { (image: UIImage?, info: [AnyHashable : Any]?) in
              print("index: \(index) background: \(String(describing: image))")
              self.updateImageCacheForAsset(asset: asset, withImage: image)
            }
      )
      DispatchQueue.main.async {
        self.imageCacheTuplesArray[asset.localIdentifier]!.imageRequestId = imageRequestId
      }
    }
  }
  
  public func saveAssetWithIndex(_ index: Int, toUrl url: URL, withProgresshandler progresshandler: @escaping (Double) -> Void, withCompletionhandler completionHandler: @escaping (Error?) -> Void) {
    if (index >= self.mediaCount() || index < 0) {
      completionHandler(NSError(domain:"", code:2, userInfo:[ NSLocalizedDescriptionKey: "No asset with the index \(index) found in the photo library"]))
      return
    }
    
    let asset = self.assetTuplesArray[index].asset
    let resources = self.assetTuplesArray[index].resources
    let saveToFolder = resources.count > 1
    if saveToFolder {
      // Create folder first
      do {
        try FileManager.init().createDirectory(at: url, withIntermediateDirectories: false, attributes: nil)
      } catch {
        print("Error: \(error)")
        completionHandler(error)
        return
      }
    }
    let assetRequestOptions = PHAssetResourceRequestOptions()
    assetRequestOptions.isNetworkAccessAllowed = true
    var filesCountToSave = resources.count
    if filesCountToSave > 0 {
      progresshandler(0.1)
    }
    for resource in resources {
      var fileNameUrl = url
      if saveToFolder {
        let dateTimeString = self.dateStringFrom(asset.creationDate)
        let fileName = "\(url.absoluteString)/\(dateTimeString)_\(resource.originalFilename)"
        if let fileNameUrlSingleFile = URL(string: fileName) {
          fileNameUrl = fileNameUrlSingleFile
        } else {
          let errorString = "Error converting '\(fileName)' to URL"
          print(errorString)
          filesCountToSave -= 1
          if filesCountToSave <= 0 {
            completionHandler(NSError(domain:"", code:3, userInfo:[ NSLocalizedDescriptionKey: errorString]))
          }
          continue
        }
      }
      
      self.saveAssetResource(resource, fileNameUrl: fileNameUrl, progressHandler: progresshandler) { (error) in
        if let error = error {
          print("Error: '\(error)' saving resource to filepath: \(fileNameUrl)")
        } else {
          print("Saved resource '\(resource)' to filepath: \(fileNameUrl)")
        }
        filesCountToSave -= 1
        if filesCountToSave <= 0 {
          completionHandler(nil)
        }
      }
    }
  }
  
  public func getFileOrFolderNameFor(index: Int) -> String {
    if (index >= self.mediaCount() || index < 0) {
      return ""
    }
    
    let asset = self.assetTuplesArray[index].asset
    let dateTimeString = dateStringFrom(asset.creationDate)
    let resources = self.assetTuplesArray[index].resources
    var fileNameOrFolderSuffix = ""
    if resources.count > 0 {
      fileNameOrFolderSuffix = resources[0].originalFilename
      // In case of multiple resources use the first resource name without extension as a folder suffix
      if resources.count > 1 {
        fileNameOrFolderSuffix = (fileNameOrFolderSuffix as NSString).deletingPathExtension
      }
    }
    return "\(dateTimeString)_\(fileNameOrFolderSuffix)"
  }
  
  private func updateImageCacheForAsset(asset: PHAsset, withImage image: UIImage?) {
    DispatchQueue.main.async {
      self.imageCacheTuplesArray[asset.localIdentifier]?.imageRequestId = PHInvalidImageRequestID
      if let requestedImage = image {
        self.imageCacheTuplesArray[asset.localIdentifier]?.image = requestedImage
        self.imageCacheTuplesArray[asset.localIdentifier]?.imageLoader?.uiImage = requestedImage
      }
    }
  }
  
  private func dateStringFrom(_ date: Date?) -> String {
    guard let date = date else {
      return ""
    }
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.dateFormat = "yyyy_MM_dd'T'HH_mm_ss"
    dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
    return dateFormatter.string(from: date)
  }
  
  private func downloadSelectedMediaToUrl(_ url: URL) {
    guard let viewModel = AppState.shared.contentView?.viewModel else {
      return
    }
    guard url.startAccessingSecurityScopedResource() else {
      return
    }
    var savedFilesCount = 0
    for i in 0 ..< viewModel.selectedImages.count {
      if viewModel.selectedImages[i] {
        let fileOrFolderName = getFileOrFolderNameFor(index: i)
        savedFilesCount += 1
        saveAssetWithIndex(
          i,
          toUrl: url.appendingPathComponent(fileOrFolderName),
          withProgresshandler: { (progress: Double) in
            withAnimation { viewModel.currentSaveProgress = progress }
          },
          withCompletionhandler: { (error: Error?) in
            savedFilesCount -= 1
            if savedFilesCount <= 0 {
              url.stopAccessingSecurityScopedResource()
              DispatchQueue.main.async {
                withAnimation { viewModel.currentSaveProgress = 1.0 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                  withAnimation { viewModel.currentSaveProgress = 0 }
                }
              }
            }
          }
        )
      }
    }
  }
  
  public func downloadSelectedMediaToUserSelectedFolder() {
#if !os(iOS)
    let openPanel = NSOpenPanel()
    openPanel.canCreateDirectories = true
    openPanel.level = .modalPanel
    openPanel.nameFieldStringValue  = ""
    openPanel.canChooseDirectories = true
    openPanel.canChooseFiles = false
    openPanel.prompt = "Select Directory"
    openPanel.begin {(result) in
      if result.rawValue == NSApplication.ModalResponse.OK.rawValue{
        self.downloadSelectedMediaToUrl(openPanel.url!)
      }
    }
#else
    // let documentPicker = UIDocumentPickerViewController(forExporting: [URL(fileURLWithPath: "/")], asCopy: true)
    let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
    self.documentPickerDelegateiOS = DocumentPickerDelegateiOS(fnDownloadSelectedMediaToUrl: self.downloadSelectedMediaToUrl)
    documentPicker.delegate = self.documentPickerDelegateiOS
    documentPicker.allowsMultipleSelection = false
    
    // Present the document picker.
    UIApplication.shared.windows.filter {$0.isKeyWindow}.first?.rootViewController?.present(documentPicker, animated: true, completion: nil)
#endif
  }
  
  public func downloadMedia() {
    let assetIndex = 30
    let assetToDownload = self.assetTuplesArray[assetIndex].asset
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yMd_HHmmss"
    var fileNamePrefix = ""
    if let creationDate = assetToDownload.creationDate {
      fileNamePrefix = dateFormatter.string(from: creationDate)
    }
    let directoryname = "file:////Users/sasha/Downloads/ss/"
    let resources = self.assetTuplesArray[assetIndex].resources
    let assetRequestOptions = PHAssetResourceRequestOptions()
    assetRequestOptions.isNetworkAccessAllowed = true
    for resource in resources {
      let fileUrl = "\(directoryname)/\(String(describing: fileNamePrefix))_\(resource.originalFilename)"
      PHAssetResourceManager.default().writeData(for: resource, toFile: URL(string: fileUrl)!, options: assetRequestOptions) { (error) in
        print("Saved resource directly \(resource) to filepath \(String(describing: fileUrl))")
      }
    }
    
  }
  
  public func cancelAllImageRequests() {
    for imageCacheTupleKey in self.imageCacheTuplesArray.keys {
      if let imageRequestId = self.imageCacheTuplesArray[imageCacheTupleKey]?.imageRequestId,
         imageRequestId != PHInvalidImageRequestID {
        PHImageManager.default().cancelImageRequest(imageRequestId)
        self.imageCacheTuplesArray[imageCacheTupleKey]?.imageRequestId = PHInvalidImageRequestID
        self.imageCacheTuplesArray[imageCacheTupleKey]?.imageLoader = nil
      }
    }
  }
  
  public func downloadMediaOld() {
    let assetIndex = 30
    let assetToDownload = self.assetTuplesArray[assetIndex].asset
    let resources = self.assetTuplesArray[assetIndex].resources
    if assetToDownload.mediaType == .image {
      if assetToDownload.mediaSubtypes == .photoLive {
        self.downloadLivePhoto(asset: assetToDownload, resources: resources)
      } else {
        //saveAssetResource(resource: resources[0], inDirectory: NSURL(string: "file:////Users/sasha/Downloads/ss/")!, buffer: nil, maybeError: nil)
        /*let options = PHContentEditingInputRequestOptions()
         options.isNetworkAccessAllowed = true
         assetToDownload.requestContentEditingInput(with: options) { input, _ in
         guard let url = input?.fullSizeImageURL else { return }
         guard let image = CIImage(contentsOf: url) else { return }
         guard let exif = image.properties["{Exif}"] as? [String: Any] else { return }
         
         print(exif["DateTimeOriginal"] ?? "")
         print(exif["SubsecTimeDigitized"] ?? "")
         }*/
        self.downloadImage(asset: assetToDownload, resource: resources[0])
      }
    } else if assetToDownload.mediaType == .video {
      /*let options = PHContentEditingInputRequestOptions()
       options.isNetworkAccessAllowed = true
       assetToDownload.requestContentEditingInput(with: options) { input, _ in
       if let avAsset = input?.audiovisualAsset {
       let metadata = avAsset.commonMetadata
       
       
       // Filter metadata to find the asset's artwork
       let artworkItems = AVMetadataItem.metadataItems(from: metadata,
       filteredByIdentifier: .commonIdentifierCreationDate)
       
       for format in avAsset.availableMetadataFormats {
       let metadata = avAsset.metadata(forFormat: format)
       print("Here")
       }
       }
       guard let url = input?.fullSizeImageURL else { return }
       guard let image = CIImage(contentsOf: url) else { return }
       guard let exif = image.properties["{Exif}"] as? [String: Any] else { return }
       
       print(exif["DateTimeOriginal"] ?? "")
       print(exif["SubsecTimeDigitized"] ?? "")
       }*/
      saveAssetResource(resource: resources[0], inDirectory: NSURL(string: "file:////Users/sasha/Downloads/ss/")!, buffer: nil, maybeError: nil)
      //self.downloadVideo(asset: assetToDownload, resource: resources[0])
    }
  }
  
  public func deleteSelectedMedias() {
    if let viewModel = AppState.shared.contentView?.viewModel {
      for i in 0 ..< viewModel.selectedImages.count {
        if viewModel.selectedImages[i] {
          self.deleteMediaWithIndex(i)
        }
      }
    }
  }
  
  public func deleteMediaWithIndex(_ index: Int) {
    let assetToDelete: PHAsset = self.assetTuplesArray[index].asset
    PHPhotoLibrary.shared().performChanges(
      {
        PHAssetChangeRequest.deleteAssets([assetToDelete] as NSFastEnumeration)
      }, completionHandler: { success, error in
        if !success { print("error deleting asset: \(String(describing: error))") }
      })
  }
  
  // MARK: - Private Methods
  
  private init() {
    self.dateFormatter.dateFormat = "yyyy-MM-dd' 'HH:mm:ss"
  }
  
  // A "Live photo" consist of image (.HEIC) and movie (.MOV) files.
  // At least, when downloading the "Live photo" from iCloud website
  // the downloaded .zip file contains 2 files (.HEIC and .MOV)
  private func downloadLivePhoto(asset: PHAsset, resources: Array<PHAssetResource>) {
    for resource in resources {
      
      // SAVE FROM BUFFER
      //            let buffer = NSMutableData()
      //            PHAssetResourceManager.default().requestData(for: resource, options: nil, dataReceivedHandler: { (chunk) in
      //                buffer.append(chunk)
      //            }, completionHandler: {[weak self] error in
      //                self?.saveAssetResource(resource: resource, inDirectory: photoDir, buffer: buffer, maybeError: error)
      //            })
      
      // SAVE DIRECTLY
      saveAssetResource(resource: resource, inDirectory: NSURL(string: "file:////Users/sasha/Downloads/ss/")!, buffer: nil, maybeError: nil)
    }
    //let requestOptions = PHLivePhotoRequestOptions()
    //requestOptions.version = .original
    //requestOptions.isNetworkAccessAllowed = true
    //let exportPreset = AVAssetExportPresetPassthrough
    /*PHImageManager.default().requestLivePhoto(
     for: asset, targetSize: .zero, contentMode: .default, options: requestOptions, resultHandler:
     {
     (livePhoto: PHLivePhoto?, info: [AnyHashable : Any]?) in
     print("here")
     let videoRequestOptions = PHVideoRequestOptions()
     videoRequestOptions.version = .original
     videoRequestOptions.isNetworkAccessAllowed = true
     let exportPreset = AVAssetExportPresetPassthrough
     PHImageManager.default().requestExportSession(
     forVideo: asset, options: videoRequestOptions, exportPreset: exportPreset,
     resultHandler: { (exportSession: AVAssetExportSession?, info: [AnyHashable : Any]?) in
     exportSession?.outputURL = URL(string: "file:////Users/sasha/Downloads/ss/\(resource.originalFilename)")
     exportSession?.outputFileType = AVFileType.mov
     exportSession?.exportAsynchronously(completionHandler: { () in
     print("Here44")
     })
     print("Here")
     })
     }
     )*/
    /*PHImageManager.default().requestExportSession(forVideo: asset, options: requestOptions, exportPreset: exportPreset, resultHandler: { (exportSession: AVAssetExportSession?, info: [AnyHashable : Any]?) in
     exportSession?.outputURL = URL(string: "file:////Users/sasha/Downloads/ss/\(resources[0].originalFilename)")
     exportSession?.outputFileType = AVFileType.mov
     exportSession?.exportAsynchronously(completionHandler: { () in
     print("Here44")
     })
     print("Here")
     })*/
  }
  
  private func saveAssetResource(
    _ resource: PHAssetResource,
    fileNameUrl: URL,
    progressHandler: @escaping (Double) -> Void,
    completionHandler: @escaping (Error?) -> Void
  ) -> Void {
    let assetRequestOptions = PHAssetResourceRequestOptions()
    assetRequestOptions.progressHandler = progressHandler
    //assetRequestOptions.version =
    assetRequestOptions.isNetworkAccessAllowed = true
    PHAssetResourceManager.default().writeData(for: resource, toFile: fileNameUrl, options: assetRequestOptions) { (error) in
      print("Saved resource directly \(resource) to filepath \(String(describing: fileNameUrl))")
      completionHandler(error)
    }
  }
  
  private func saveAssetResource(
    resource: PHAssetResource,
    inDirectory: NSURL,
    buffer: NSMutableData?, maybeError: Error?
  ) -> Void {
    guard maybeError == nil else {
      print("Could not request data for resource: \(resource), error: \(String(describing: maybeError))")
      return
    }
    
    guard let fileUrl = inDirectory.appendingPathComponent(resource.originalFilename) else {
      print("file url error")
      return
    }
    
    if let buffer = buffer, buffer.write(to: fileUrl, atomically: true) {
      print("Saved resource form buffer \(resource) to filepath \(String(describing: fileUrl))")
    } else {
      let assetRequestOptions = PHAssetResourceRequestOptions()
      //assetRequestOptions.version =
      assetRequestOptions.isNetworkAccessAllowed = true
      let exportPreset = AVAssetExportPresetPassthrough
      PHAssetResourceManager.default().writeData(for: resource, toFile: fileUrl, options: assetRequestOptions) { (error) in
        print("Saved resource directly \(resource) to filepath \(String(describing: fileUrl))")
      }
    }
  }
  
  private func downloadVideo(asset: PHAsset, resource: PHAssetResource) {
    let videoRequestOptions = PHVideoRequestOptions()
    //videoRequestOptions.version = .original
    videoRequestOptions.isNetworkAccessAllowed = true
    let exportPreset = AVAssetExportPresetPassthrough
    PHImageManager.default().requestExportSession(
      forVideo: asset, options: videoRequestOptions, exportPreset: exportPreset,
      resultHandler: { (exportSession: AVAssetExportSession?, info: [AnyHashable : Any]?) in
        exportSession?.outputURL = URL(string: "file:////Users/sasha/Downloads/ss/\(resource.originalFilename)")
        exportSession?.outputFileType = AVFileType.mov
        exportSession?.exportAsynchronously(completionHandler: { () in
          print("Here44")
        })
        print("Here")
      })
  }
  
  private func downloadImage(asset: PHAsset, resource: PHAssetResource) {
    let requestOptions = PHImageRequestOptions()
    requestOptions.isNetworkAccessAllowed = true
    requestOptions.version = PHImageRequestOptionsVersion.original
    requestOptions.deliveryMode = .highQualityFormat
    let targetSize = CGSize(width: resource.value(forKey: "pixelWidth") as! Int, height: resource.value(forKey: "pixelHeight") as! Int)
    /*PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .default, options: requestOptions, resultHandler: { (image: NSImage?, info: [AnyHashable : Any]?) in
     print("here 22e")
     })*/
    PHImageManager.default().requestImageDataAndOrientation(
      for: asset,
         options: requestOptions,
         resultHandler: { (data: Data?, dataUTI: String?, orientation: CGImagePropertyOrientation, info: [AnyHashable : Any]?) in
           print("Here")
           if let imageData = data {
             let ciImage = CIImage(data: imageData);
             do {
               // try FileManager.default.createDirectory(atPath: "/Users/sasha/Downloads/ss", withIntermediateDirectories: true, attributes: nil)
               try imageData.write(to: URL(string: "file:////Users/sasha/Downloads/ss/\(resource.originalFilename)")!, options: Data.WritingOptions.atomic)
             } catch {
               print("Unexpected error: \(error).")
             }
           }
         })
  }
  
  private func fetchMediaAssets() {
    DispatchQueue.main.async {
      self.assetTuplesArray.removeAll()
      self.cancelAllImageRequests()
      self.imageCacheTuplesArray.removeAll()
      AppState.shared.contentView?.viewModel.selectedImages.removeAll()
      let fetchResult: PHFetchResult = PHAsset.fetchAssets(with: self.fetchOptions())
      // var assetTuplesArray: Array<(asset: PHAsset, resources: [PHAssetResource])> = []
      fetchResult.enumerateObjects { (asset: PHAsset, index: Int, stop: UnsafeMutablePointer<ObjCBool>) in
        let assetTuple = (asset: asset, resources: PHAssetResource.assetResources(for: asset))
        self.assetTuplesArray.append(assetTuple)
        self.imageCacheTuplesArray[asset.localIdentifier] = (image: nil, imageRequestId: PHInvalidImageRequestID, imageLoader: nil, lastDownloadedSize : CGSize.zero)
      }
      self.sortMediaAssets()
    }
  }
  
  public func sortMediaAssets() {
    let sortOrder = AppState.shared.contentView?.viewModel.sortOrder ?? SortOrder.Descending
    let sortBy = AppState.shared.contentView?.viewModel.sortBy
    
    //self.cancelAllImageRequests()
    
    if sortBy == Sort.Size {
      self.assetTuplesArray = self.assetTuplesArray.sorted { (assetTuple1: AssetTuple, assetTuple2: AssetTuple) -> Bool in
        let asset1SizeGreaterThanAsset2 = assetTuple(assetTuple1, hasGreaterFileSizeThanExistingAssetTuple: assetTuple2)
        return sortOrder == .Descending ? asset1SizeGreaterThanAsset2 : !asset1SizeGreaterThanAsset2
      }
    } else if sortBy == Sort.Date {
      self.assetTuplesArray = self.assetTuplesArray.sorted { (assetTuple1: AssetTuple, assetTuple2: AssetTuple) -> Bool in
        let asset1DateGreaterThanAsset2 = assetTuple(assetTuple1, hasGreaterDateThanExistingAssetTuple: assetTuple2)
        return sortOrder == .Descending ? asset1DateGreaterThanAsset2 : !asset1DateGreaterThanAsset2
      }
    }
    
    AppState.shared.contentView?.viewModel.selectedImages = Array(repeating: false, count: self.assetTuplesArray.count)
    AppState.shared.contentView?.viewModel.testText = "Done"
  }
  
  private func assetTuple(
    _ assetTuple: (PHAsset, resources: [PHAssetResource]),
    hasGreaterFileSizeThanExistingAssetTuple existingAssetTuple: (PHAsset, resources: [PHAssetResource])) -> Bool {
      let assetTupleFileSize = assetTuple.resources.reduce(0 as CUnsignedLongLong, { (previousFileSize, resource: PHAssetResource) in
        let resourceFileSize = resource.value(forKey: "fileSize") as? CUnsignedLongLong ?? 0
        return previousFileSize > resourceFileSize ? previousFileSize : resourceFileSize
      }
      )
      let existingAssetTupleFileSize = existingAssetTuple.resources.reduce(
        0 as CUnsignedLongLong, {
          (previousFileSize, resource: PHAssetResource) in
          let resourceFileSize = resource.value(forKey: "fileSize") as? CUnsignedLongLong ?? 0
          return previousFileSize > resourceFileSize ? previousFileSize : resourceFileSize
        }
      )
      return assetTupleFileSize > existingAssetTupleFileSize
    }
  
  private func assetTuple(
    _ assetTuple: (asset: PHAsset, resources: [PHAssetResource]),
    hasGreaterDateThanExistingAssetTuple existingAssetTuple: (asset: PHAsset, resources: [PHAssetResource])) -> Bool {
      if let assetDate = assetTuple.asset.creationDate,
         let existingAssetDate = existingAssetTuple.asset.creationDate {
        return assetDate > existingAssetDate
      }
      return true
    }
  
  private func fetchOptions() -> PHFetchOptions {
    // 1
    let fetchOptions = PHFetchOptions()
    // 2
    fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
    return fetchOptions
  }
  
  private func showAuthenticationPrompt() {
    DispatchQueue.main.async {
#if os(iOS)
      let alertController = UIAlertController(title: "Please Enable Access To Photos", message: nil, preferredStyle: .alert)
      alertController.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
      alertController.addAction(UIAlertAction(title: "Settings", style: .default, handler: { action in
        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
      }))
      UIApplication.shared.windows.filter {$0.isKeyWindow}.first?.rootViewController?.present(alertController, animated: true, completion: nil)
#else
      let alert = NSAlert()
      alert.messageText = "Please allow an access to your photos"
      alert.addButton(withTitle: "Dismiss")
      alert.addButton(withTitle: "Open Settings")
      if alert.runModal() == .alertSecondButtonReturn {
        if let privacyPhotoUrl = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Photos") {
          NSWorkspace.shared.open(privacyPhotoUrl);
        }
      }
#endif
    }
  }
  
  private func requestAuthorization() {
    self.authorizationStatus = PHPhotoLibrary.authorizationStatus()
    switch self.authorizationStatus {
    case .authorized:
      self.fetchMediaAssets()
      break
      /*
       let asset: PHAsset = fetchResult.object(at: 3)
       let resource = PHAssetResource.assetResources(for: asset)
       PHPhotoLibrary.shared().performChanges({
       PHAssetChangeRequest.deleteAssets([asset] as NSFastEnumeration)
       }, completionHandler: { success, error in
       if !success { print("error deleting asset: \(error)") }
       })
       print("Here 3")*/
    case .restricted, .denied:
      print("Photo Auth restricted or denied")
      self.showAuthenticationPrompt()
    case .notDetermined:
      PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
        switch status {
        case .authorized:
          self.fetchMediaAssets()
        case .restricted, .denied:
          print("Photo Auth restricted or denied")
          self.showAuthenticationPrompt()
        case .notDetermined: break
        case .limited:
          self.fetchMediaAssets()
        @unknown default:
          print("Error")
        }
      }
    case .limited:
      self.fetchMediaAssets()
    @unknown default:
      print("Error")
    }
  }
}

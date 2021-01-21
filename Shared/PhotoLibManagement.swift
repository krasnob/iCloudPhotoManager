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

class PhotoLibManagement {
  enum Sort {
    case Size
  }
  private static let instance = PhotoLibManagement()
  
  private var authorizationStatus = PHAuthorizationStatus.notDetermined
  private var assetTuplesArray: Array<(asset: PHAsset, resources: [PHAssetResource])> = []
  
  // MARK: - Public Methods
  
  public static func sharedInstance() -> PhotoLibManagement {
    return instance
  }
  
  public func getAllMedia(sortBy: Sort) {
    self.requestAuthorization()
  }
  
  public func mediaCount() -> Int {
    return self.assetTuplesArray.count
  }
  
  public func getThumbnail(forIndex index: Int, targetSize: CGSize, withImageLoader imageLoader: ImageLoaderModel) {
    DispatchQueue.global(qos: .background).async {
      if (index >= self.mediaCount()) {
        return
      }
      let asset = self.assetTuplesArray[index].asset
      let requestOptions = PHImageRequestOptions()
      requestOptions.isNetworkAccessAllowed = true
      requestOptions.version = PHImageRequestOptionsVersion.original
      requestOptions.deliveryMode = .fastFormat
      PHImageManager.default().requestImage(
        for: asset, targetSize: targetSize, contentMode: .default, options: requestOptions, resultHandler:
          { (image: UIImage?, info: [AnyHashable : Any]?) in
            print("index: \(index)")
            imageLoader.uiImage = image
          }
      )
    }
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
  
  private func populateMedia() {
    let fetchResult: PHFetchResult = PHAsset.fetchAssets(with: fetchOptions())
    // var assetTuplesArray: Array<(asset: PHAsset, resources: [PHAssetResource])> = []
    fetchResult.enumerateObjects { (asset: PHAsset, index: Int, stop: UnsafeMutablePointer<ObjCBool>) in
      let assetTuple = (asset: asset, resources: PHAssetResource.assetResources(for: asset))
      print("Asset: \(assetTuple.resources[0].originalFilename) index: \(index)")
      if assetTuple.resources[0].originalFilename == "4f1fd31d858d39c7787d759671933f25.mov" {
        print("hhh")
      }
      if self.assetTuplesArray.count > 0,
         self.assetTuple(assetTuple, hasGreaterFileSizeThanExistingAssetTuple: self.assetTuplesArray.first!) {
        self.assetTuplesArray.insert(assetTuple, at: 0)
        //if resource.count > 0,
        //     let imageSizeByte = resource.first?.value(forKey: "fileSize") as? Float ?? 0)
      } else {
        self.assetTuplesArray.append(assetTuple)
      }
    }
    AppState.shared.contentView?.viewModel.testText = "Done"
  }
  
  private func assetTuple(
    _ assetTuple: (PHAsset, resources: [PHAssetResource]),
    hasGreaterFileSizeThanExistingAssetTuple existingAssetTuple: (PHAsset, resources: [PHAssetResource]))-> Bool {
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
  
  private func fetchOptions() -> PHFetchOptions {
    // 1
    let fetchOptions = PHFetchOptions()
    // 2
    fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
    return fetchOptions
  }
  
  private func requestAuthorization() {
    self.authorizationStatus = PHPhotoLibrary.authorizationStatus()
    switch self.authorizationStatus {
    case .authorized:
      populateMedia()
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
    case .notDetermined:
      PHPhotoLibrary.requestAuthorization { status in
        switch status {
        case .authorized:
          self.populateMedia()
        case .restricted, .denied:
          print("Photo Auth restricted or denied")
        case .notDetermined: break
        @unknown default:
          print("Error")
        }
      }
    @unknown default:
      print("Error")
    }
  }
}

import Foundation
import AVFoundation
import UIKit

struct VideoUtils {
  
  static func bufferToImage(imageBuffer: CMSampleBuffer) -> UIImage? {
    guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(imageBuffer) else {
      return nil
    }
    let ciimage = CIImage(cvPixelBuffer: pixelBuffer)
    let context = CIContext()
    guard let cgImage = context.createCGImage(ciimage, from: ciimage.extent) else {
      return nil
    }
    return UIImage(cgImage: cgImage, scale: 1.0, orientation: self.deviceOrientation())
  }
  
  static func deviceOrientation() -> UIImage.Orientation {
    let curDeviceOrientation = UIDevice.current.orientation
    var exifOrientation: UIImage.Orientation
    switch curDeviceOrientation {
    case UIDeviceOrientation.portraitUpsideDown:
      exifOrientation = .left
    case UIDeviceOrientation.landscapeLeft:
      exifOrientation = .upMirrored
    case UIDeviceOrientation.landscapeRight:
      exifOrientation = .down
    case UIDeviceOrientation.portrait:
      exifOrientation = .up
    default:
      exifOrientation = .up
    }
    return exifOrientation
  }
}

extension UIImage {
  func scale(to size: CGSize) -> UIImage {
    let widthRatio = size.width / self.size.width
    let heightRatio = size.height / self.size.height
    let scaleFactor = min(widthRatio, heightRatio)
    
    let newWidth = self.size.width * scaleFactor
    let newHeight = self.size.height * scaleFactor
    
    let newSize = CGSize(width: newWidth, height: newHeight)

    return UIGraphicsImageRenderer(size: newSize).image { _ in
      draw(in: CGRect(origin: .zero, size: newSize))
    }
  }
}

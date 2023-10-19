import SwiftUI
import AVFoundation
import GuruSwiftSDK

let apiKey = "YOUR-API-KEY"
let schemaId = "SCHEMA-ID"

@main
struct ExampleGuruApp: App {
  var body: some Scene {
    WindowGroup {
      CameraView()
    }
  }
}

struct CameraView: View {
  @State private var isCameraActive = false
  @State private var cameraController: CameraController?

  var body: some View {
    VStack {
      if isCameraActive {
        CameraPreview(cameraController: $cameraController)
      } else {
        Button("Start Camera") {
            cameraController = CameraController()
            cameraController?.startCapture()
            isCameraActive = true
        }
      }
    }
  }
}

struct CameraPreview: View {
  @Binding var cameraController: CameraController?

  var body: some View {
    CameraViewRepresentable(cameraController: Binding.constant(cameraController!))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

struct CameraViewRepresentable: UIViewRepresentable {
  @Binding var cameraController: CameraController

  func makeUIView(context: Context) -> UIView {
    let view = UIImageView()
    view.contentMode = .scaleAspectFit
    view.backgroundColor = UIColor.black
    return view
  }

  func updateUIView(_ uiView: UIView, context: Context) {
    DispatchQueue.main.async {
      cameraController.imageView = uiView as? UIImageView
    }
  }
}

class CameraController: NSObject {
  let session = AVCaptureSession()
  var imageView: UIImageView?
  var guruVideo: GuruVideo?
  var latestInference: GuruAnalysis = GuruAnalysis(result: nil, processResult: [:])

  override init() {
    super.init()
    
    self.configureCamera()
    
    Task { @MainActor in
      self.guruVideo = try? await GuruVideo(
        apiKey: apiKey,
        schemaId: schemaId
      )
    }
  }

  func startCapture() {
    DispatchQueue.global(qos: .userInitiated).async {
      self.session.startRunning()
    }
  }
  
  private func configureCamera() {
    session.beginConfiguration()
    
    session.sessionPreset = .vga640x480
    
    do {
      guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: AVCaptureDevice.Position.front) else {
        fatalError("No camera available")
      }

      session.addInput(try AVCaptureDeviceInput(device: camera))
    } catch {
      fatalError(error.localizedDescription)
    }
    
    let output = AVCaptureVideoDataOutput()
    output.alwaysDiscardsLateVideoFrames = true
    output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable as! String: kCVPixelFormatType_32BGRA]
    output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "frameBuffer"))
    session.addOutput(output)
    
    if let connection = output.connection(with: .video) {
      connection.videoOrientation = .portrait
    } else {
      fatalError("Failed to set video orientation")
    }
    
    session.commitConfiguration()
  }
}

extension CameraController: AVCaptureVideoDataOutputSampleBufferDelegate {

  public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    let image: UIImage? = VideoUtils.bufferToImage(imageBuffer: sampleBuffer)

    if let image = image, let guruVideo = guruVideo {
      DispatchQueue.global(qos: .userInteractive).async {
        Task.detached {
          if let result = self.guruVideo?.newFrame(frame: image) {
            self.latestInference = result
          }
        }
      }

      if let imageView = self.imageView {
        let overlaidImage = guruVideo.renderFrame(frame: image, analysis: self.latestInference)

        DispatchQueue.main.async {
          self.imageView?.image = overlaidImage.scale(to: imageView.bounds.size)
        }
      }
    }
  }
}

import SwiftUI
import AVFoundation

// MARK: - BarcodeScannerView
// Presents a live camera feed and calls onScan when a barcode is detected.
// Requires NSCameraUsageDescription in Info.plist.

struct BarcodeScannerView: UIViewControllerRepresentable {
    let onScan: (String) -> Void
    @Environment(\.dismiss) var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan, dismiss: dismiss) }

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}

    // MARK: - Coordinator

    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let onScan: (String) -> Void
        let dismiss: DismissAction
        var hasScanned = false

        init(onScan: @escaping (String) -> Void, dismiss: DismissAction) {
            self.onScan = onScan
            self.dismiss = dismiss
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput metadataObjects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            guard !hasScanned,
                  let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let value = obj.stringValue else { return }
            hasScanned = true
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            DispatchQueue.main.async {
                self.onScan(value)
                self.dismiss()
            }
        }
    }
}

// MARK: - ScannerViewController

class ScannerViewController: UIViewController {
    var delegate: AVCaptureMetadataOutputObjectsDelegate?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let overlay = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
        setupOverlay()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session.stopRunning()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
        updateOverlay()
    }

    private func setupCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureCaptureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted { DispatchQueue.main.async { self?.configureCaptureSession() } }
            }
        default:
            showPermissionDenied()
        }
    }

    private func configureCaptureSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }

        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(delegate, queue: .main)
        output.metadataObjectTypes = [.ean13, .ean8, .upce, .code128]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.insertSublayer(preview, at: 0)
        self.previewLayer = preview
    }

    private func setupOverlay() {
        overlay.isUserInteractionEnabled = false
        view.addSubview(overlay)
    }

    private func updateOverlay() {
        overlay.frame = view.bounds
        overlay.subviews.forEach { $0.removeFromSuperview() }

        // Semi-transparent surround with a clear scanning window
        let scanW: CGFloat = view.bounds.width * 0.75
        let scanH: CGFloat = 120
        let scanRect = CGRect(
            x: (view.bounds.width - scanW) / 2,
            y: (view.bounds.height - scanH) / 2,
            width: scanW, height: scanH
        )

        let dimLayer = CAShapeLayer()
        let path = UIBezierPath(rect: view.bounds)
        path.append(UIBezierPath(roundedRect: scanRect, cornerRadius: 8).reversing())
        dimLayer.path = path.cgPath
        dimLayer.fillColor = UIColor.black.withAlphaComponent(0.55).cgColor
        overlay.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        overlay.layer.addSublayer(dimLayer)

        // Corner guides
        let guideColor = UIColor.systemGreen
        let guideLen: CGFloat = 20
        let guideWidth: CGFloat = 3
        let corners: [(CGPoint, CGPoint, CGPoint)] = [
            (CGPoint(x: scanRect.minX, y: scanRect.minY + guideLen),
             CGPoint(x: scanRect.minX, y: scanRect.minY),
             CGPoint(x: scanRect.minX + guideLen, y: scanRect.minY)),
            (CGPoint(x: scanRect.maxX - guideLen, y: scanRect.minY),
             CGPoint(x: scanRect.maxX, y: scanRect.minY),
             CGPoint(x: scanRect.maxX, y: scanRect.minY + guideLen)),
            (CGPoint(x: scanRect.minX, y: scanRect.maxY - guideLen),
             CGPoint(x: scanRect.minX, y: scanRect.maxY),
             CGPoint(x: scanRect.minX + guideLen, y: scanRect.maxY)),
            (CGPoint(x: scanRect.maxX - guideLen, y: scanRect.maxY),
             CGPoint(x: scanRect.maxX, y: scanRect.maxY),
             CGPoint(x: scanRect.maxX, y: scanRect.maxY - guideLen)),
        ]
        for (p1, p2, p3) in corners {
            let l = CAShapeLayer()
            let p = UIBezierPath()
            p.move(to: p1); p.addLine(to: p2); p.addLine(to: p3)
            l.path = p.cgPath
            l.strokeColor = guideColor.cgColor
            l.lineWidth = guideWidth
            l.fillColor = UIColor.clear.cgColor
            l.lineCap = .round
            overlay.layer.addSublayer(l)
        }

        // Label
        let label = UILabel()
        label.text = "Point at a book barcode"
        label.textColor = .white
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.sizeToFit()
        label.center = CGPoint(x: view.bounds.midX,
                               y: scanRect.maxY + 24)
        overlay.addSubview(label)
    }

    private func showPermissionDenied() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let label = UILabel()
            label.text = "Camera access denied.\nGo to Settings to enable it."
            label.textColor = .white
            label.numberOfLines = 0
            label.textAlignment = .center
            label.font = .systemFont(ofSize: 16)
            label.frame = self.view.bounds.insetBy(dx: 32, dy: 0)
            label.center = CGPoint(x: self.view.bounds.midX, y: self.view.bounds.midY)
            self.view.addSubview(label)
        }
    }
}

import Flutter
import UIKit
import VisionKit
import UniformTypeIdentifiers
import AVFoundation

/// Native document scanner/import bridge for eSign : Sign Any Docs.
/// Register this channel from AppDelegate before running the Flutter engine.
final class NativeScannerBridge: NSObject, VNDocumentCameraViewControllerDelegate, UIDocumentPickerDelegate {
    private var result: FlutterResult?

    static func register(with registrar: FlutterPluginRegistrar) {
        let bridge = NativeScannerBridge()
        let channel = FlutterMethodChannel(name: "esign_doc_pro/native_scanner", binaryMessenger: registrar.messenger())
        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "scanDocument":
                bridge.presentScanner(result: result)
            case "importDocument":
                bridge.presentImporter(result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private func presentScanner(result: @escaping FlutterResult) {
        guard self.result == nil else {
            result(FlutterError(code: "PRESENTATION_IN_PROGRESS", message: "Another document action is already open", details: nil))
            return
        }
        guard let presenter = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?.rootViewController else {
            result(FlutterError(code: "NO_VIEW_CONTROLLER", message: "Unable to present scanner", details: nil))
            return
        }
        self.result = result
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = self
        presenter.topViewController?.present(scanner, animated: true)
    }

    private func presentImporter(result: @escaping FlutterResult) {
        guard self.result == nil else {
            result(FlutterError(code: "PRESENTATION_IN_PROGRESS", message: "Another document action is already open", details: nil))
            return
        }
        guard let presenter = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?.rootViewController else {
            result(FlutterError(code: "NO_VIEW_CONTROLLER", message: "Unable to present importer", details: nil))
            return
        }
        self.result = result
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.pdf, UTType.image], asCopy: true)
        picker.delegate = self
        presenter.topViewController?.present(picker, animated: true)
    }

    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        controller.dismiss(animated: true)
        guard scan.pageCount > 0 else { result?(nil); result = nil; return }
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("esign_scan_\(UUID().uuidString).pdf")
        do {
            try renderer.writePDF(to: url) { context in
                for index in 0..<scan.pageCount {
                    context.beginPage()
                    scan.imageOfPage(at: index).draw(in: AVMakeRect(aspectRatio: scan.imageOfPage(at: index).size, insideRect: CGRect(x: 24, y: 24, width: 564, height: 744)))
                }
            }
            result?(url.path)
        } catch {
            result?(FlutterError(code: "SCAN_EXPORT_FAILED", message: error.localizedDescription, details: nil))
        }
        result = nil
    }

    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        controller.dismiss(animated: true)
        result?(nil)
        result = nil
    }

    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
        controller.dismiss(animated: true)
        result?(FlutterError(code: "SCAN_FAILED", message: error.localizedDescription, details: nil))
        result = nil
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        controller.dismiss(animated: true)
        result?(urls.first?.path)
        result = nil
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        controller.dismiss(animated: true)
        result?(nil)
        result = nil
    }
}

private extension UIViewController {
    var topViewController: UIViewController? {
        if let presented = presentedViewController { return presented.topViewController }
        if let navigation = self as? UINavigationController { return navigation.visibleViewController?.topViewController }
        if let tab = self as? UITabBarController { return tab.selectedViewController?.topViewController }
        return self
    }
}

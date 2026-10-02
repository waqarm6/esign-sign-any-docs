import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as image_lib;
import 'package:paper_document_scanner/paper_document_scanner.dart';

class NativeDocumentScanner {
  static const _channel = MethodChannel('esign_doc_pro/native_scanner');

  /// Opens the platform document scanner and returns the generated local file path.
  /// Opens the in-app scanner on both Android and iOS.
  Future<String?> scanDocument(BuildContext context) async {
    try {
      final result = await PaperScanner.open(
        context,
        options: const PaperScannerOptions(
          outputPdf: true,
          minPages: 1,
          maxPages: 0,
          enableLiveDetection: true,
          detectionFps: 15,
          autoCapture: true,
          confirmAfterCapture: true,
          autoCaptureConfidence: 0.55,
          autoCaptureStableFrames: 2,
          autoCaptureMotionTolerance: 0.04,
        ),
        style: PaperScannerStyle(
          accentColor: const Color(0xFF0E7490),
          overlayStrokeColor: const Color(0xFF59D18A),
          overlayFillColor: const Color(0x3359D18A),
          overlayStrokeWidth: 3,
          cornerHandleRadius: 14,
          cameraTopChromeBuilder: _scannerTopChrome,
          labels: const PaperScannerLabels(
            cropTitle: 'Adjust document edges',
            keep: 'Keep page',
            done: 'Finish scan',
            autoShutter: 'Auto',
          ),
        ),
      );
      if (result == null || result.imagePaths.isEmpty) return null;
      if (result.pdfPath != null && result.pdfPath!.isNotEmpty) {
        return result.pdfPath;
      }
      final page = result.pages.isEmpty ? null : result.pages.first;
      if (page == null || !_isFullQuad(page.quad))
        return result.imagePaths.first;
      return _cropToGuide(page.originalPath);
    } on PlatformException {
      return null;
    } catch (_) {
      return null;
    }
  }

  bool _isFullQuad(Quad? quad) {
    if (quad == null) return true;
    const epsilon = 0.015;
    return quad.topLeft.x.abs() < epsilon &&
        quad.topLeft.y.abs() < epsilon &&
        (quad.topRight.x - 1).abs() < epsilon &&
        quad.topRight.y.abs() < epsilon &&
        (quad.bottomRight.x - 1).abs() < epsilon &&
        (quad.bottomRight.y - 1).abs() < epsilon &&
        quad.bottomLeft.x.abs() < epsilon &&
        (quad.bottomLeft.y - 1).abs() < epsilon;
  }

  Future<String?> _cropToGuide(String sourcePath) async {
    try {
      final source =
          image_lib.decodeImage(await File(sourcePath).readAsBytes());
      if (source == null) return sourcePath;
      final left = (source.width * 0.03).round();
      final top = (source.height * 0.12).round();
      final width = (source.width * 0.94).round().clamp(1, source.width - left);
      final height =
          (source.height * 0.72).round().clamp(1, source.height - top);
      final cropped = image_lib.copyCrop(source,
          x: left, y: top, width: width, height: height);
      final output = File(
          '${sourcePath.substring(0, sourcePath.lastIndexOf('.'))}_framed.jpg');
      await output.writeAsBytes(image_lib.encodeJpg(cropped, quality: 94),
          flush: true);
      return output.path;
    } catch (_) {
      return sourcePath;
    }
  }

  /// Opens the platform file picker for PDFs and supported image files.
  Future<String?> importDocument() async {
    try {
      return await _channel.invokeMethod<String>('importDocument');
    } on PlatformException {
      return null;
    }
  }
}

Widget _scannerTopChrome(
  BuildContext context,
  PaperScannerController controller,
  PaperScannerStyle style,
  VoidCallback onCancel,
  VoidCallback onDone,
) {
  final topInset = MediaQuery.paddingOf(context).top;
  return Positioned.fill(
    child: Stack(
      children: [
        const Positioned.fill(
          child: IgnorePointer(
              child: CustomPaint(painter: _ScannerGuidePainter())),
        ),
        Positioned(
          top: topInset + 14,
          left: 16,
          child: _ScannerChromeButton(
            icon: Icons.close,
            onTap: onCancel,
            background: Colors.black.withValues(alpha: 0.46),
          ),
        ),
        if (controller.canFinish)
          Positioned(
            top: topInset + 14,
            right: 16,
            child: _ScannerChromeButton(
              icon: Icons.check,
              onTap: onDone,
              background: style.confirmColor,
            ),
          ),
        Positioned(
          top: topInset + 72,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Align the document inside the frame',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _ScannerChromeButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color background;

  const _ScannerChromeButton(
      {required this.icon, required this.onTap, required this.background});

  @override
  Widget build(BuildContext context) => Material(
        color: background,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(10),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
      );
}

class _ScannerGuidePainter extends CustomPainter {
  const _ScannerGuidePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTRB(
      22,
      size.height * 0.12,
      size.width - 22,
      size.height * 0.84,
    );
    final corner = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5;
    const length = 42.0;
    final left = rect.left;
    final right = rect.right;
    final top = rect.top;
    final bottom = rect.bottom;
    canvas
      ..drawLine(Offset(left, top + length), Offset(left, top), corner)
      ..drawLine(Offset(left, top), Offset(left + length, top), corner)
      ..drawLine(Offset(right - length, top), Offset(right, top), corner)
      ..drawLine(Offset(right, top), Offset(right, top + length), corner)
      ..drawLine(Offset(left, bottom - length), Offset(left, bottom), corner)
      ..drawLine(Offset(left, bottom), Offset(left + length, bottom), corner)
      ..drawLine(Offset(right - length, bottom), Offset(right, bottom), corner)
      ..drawLine(Offset(right, bottom - length), Offset(right, bottom), corner);
  }

  @override
  bool shouldRepaint(covariant _ScannerGuidePainter oldDelegate) => false;
}

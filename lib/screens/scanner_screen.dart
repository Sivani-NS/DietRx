import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/scan_service.dart';
import 'result_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    returnImage: false,
  );
  final ScanService _scanService = ScanService();
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Scan Food"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double scanWindowWidth = 300;
          final double scanWindowHeight = 150;
          final Offset center = Offset(
            constraints.maxWidth / 2,
            constraints.maxHeight / 2,
          );
          final Rect scanWindow = Rect.fromCenter(
            center: center,
            width: scanWindowWidth,
            height: scanWindowHeight,
          );

          return Stack(
            children: [
              MobileScanner(
                controller: _controller,
                onDetect: (capture) {
                  if (_isProcessing) return;
                  if (capture.barcodes.isNotEmpty &&
                      capture.barcodes.first.rawValue != null) {
                    _handleScan(capture.barcodes.first.rawValue!);
                  }
                },
              ),
              CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: ScannerOverlay(scanWindow),
              ),
              Positioned(
                top: center.dy + (scanWindowHeight / 2) + 20,
                left: 0,
                right: 0,
                child: const Text(
                  "Place barcode inside the green box",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ),
              if (_isProcessing)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.green),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleScan(String barcode) async {
    setState(() => _isProcessing = true);
    try {
      final result = await _scanService.processBarcode(barcode);
      if (!mounted) return;
      if (result == null) {
        _showErrorDialog("Product not found in database.");
        setState(() => _isProcessing = false);
      } else {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 600),
            reverseTransitionDuration: const Duration(milliseconds: 600),
            pageBuilder: (context, animation, secondaryAnimation) {
              return ResultScreen(result: result);
            },
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  const begin = Offset(0.0, 1.0);
                  const end = Offset.zero;
                  const curve = Curves.easeOutCubic;

                  var tween = Tween(
                    begin: begin,
                    end: end,
                  ).chain(CurveTween(curve: curve));

                  return SlideTransition(
                    position: animation.drive(tween),
                    child: child,
                  );
                },
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog("Error: $e");
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showErrorDialog(String msg) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Error"),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(c);
              _controller.start();
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }
}

// OVERLAY PAINTER
class ScannerOverlay extends CustomPainter {
  final Rect scanWindow;
  ScannerOverlay(this.scanWindow);

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutoutPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(scanWindow, const Radius.circular(12)),
      );

    final path = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );

    final overlayPaint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, overlayPaint);

    final borderPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(scanWindow, const Radius.circular(12)),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

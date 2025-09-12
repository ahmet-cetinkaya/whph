import 'package:flutter/material.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:whph/presentation/ui/shared/components/secondary_app_bar.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/sync/constants/sync_translation_keys.dart';

class QRCodeScannerPage extends StatefulWidget {
  static const String route = '/sync/qr-scanner';

  const QRCodeScannerPage({super.key});

  @override
  State<QRCodeScannerPage> createState() => _QRCodeScannerPageState();
}

class _QRCodeScannerPageState extends State<QRCodeScannerPage> with TickerProviderStateMixin {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QRCodeScannerPage');
  final _translationService = container.resolve<ITranslationService>();
  QRViewController? controller;
  bool _qrCodeDetected = false;
  late AnimationController _pulseAnimationController;

  @override
  void initState() {
    super.initState();
    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _pulseAnimationController.dispose();
    super.dispose();
  }

  void _onQRViewCreated(BuildContext context, QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      // Prevent multiple scan results from triggering the logic
      if (_qrCodeDetected) return;

      setState(() {
        _qrCodeDetected = true;
      });

      _pulseAnimationController.forward().then((_) {
        controller.stopCamera();
        if (context.mounted) Navigator.of(context).pop(scanData.code);
      });
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SecondaryAppBar(
        context: context,
        title: Text(_translationService.translate(SyncTranslationKeys.scannerTitle)),
      ),
      body: _buildQRCamera(context),
    );
  }

  Widget _buildQRCamera(BuildContext context) {
    return Stack(
      children: [
        QRView(
          key: qrKey,
          onQRViewCreated: (controller) => _onQRViewCreated(context, controller),
        ),
        _buildScannerOverlay(context),
      ],
    );
  }

  Widget _buildScannerOverlay(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final scanAreaSize = screenSize.width * 0.7; // 70% of screen width

    return Positioned.fill(
      child: Stack(
        children: [
          // Semi-transparent background with cut-out
          CustomPaint(
            size: screenSize,
            painter: _ScannerOverlayPainter(
              scanAreaSize: scanAreaSize,
              overlayColor: Colors.black.withValues(alpha: 0.6),
            ),
          ),
          // Corner indicators
          _buildCornerIndicators(context, scanAreaSize),
          // Instruction text
          _buildInstructionText(context, scanAreaSize),
          // Detection feedback
          if (_qrCodeDetected) _buildDetectionFeedback(context, scanAreaSize),
        ],
      ),
    );
  }

  Widget _buildCornerIndicators(BuildContext context, double scanAreaSize) {
    const cornerLength = 30.0;
    const cornerWidth = 4.0;
    final cornerColor = _qrCodeDetected ? Colors.green : Theme.of(context).colorScheme.primary;

    return Center(
      child: SizedBox(
        width: scanAreaSize,
        height: scanAreaSize,
        child: Stack(
          children: [
            // Top-left corner
            Positioned(
              top: -cornerWidth / 2,
              left: -cornerWidth / 2,
              child: _buildCorner(cornerColor, cornerLength, cornerWidth, [true, false, false, true]),
            ),
            // Top-right corner
            Positioned(
              top: -cornerWidth / 2,
              right: -cornerWidth / 2,
              child: _buildCorner(cornerColor, cornerLength, cornerWidth, [true, true, false, false]),
            ),
            // Bottom-left corner
            Positioned(
              bottom: -cornerWidth / 2,
              left: -cornerWidth / 2,
              child: _buildCorner(cornerColor, cornerLength, cornerWidth, [false, false, true, true]),
            ),
            // Bottom-right corner
            Positioned(
              bottom: -cornerWidth / 2,
              right: -cornerWidth / 2,
              child: _buildCorner(cornerColor, cornerLength, cornerWidth, [false, true, true, false]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCorner(Color color, double length, double width, List<bool> sides) {
    return Container(
      width: length,
      height: length,
      decoration: BoxDecoration(
        border: Border(
          top: sides[0] ? BorderSide(color: color, width: width) : BorderSide.none,
          right: sides[1] ? BorderSide(color: color, width: width) : BorderSide.none,
          bottom: sides[2] ? BorderSide(color: color, width: width) : BorderSide.none,
          left: sides[3] ? BorderSide(color: color, width: width) : BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildInstructionText(BuildContext context, double scanAreaSize) {
    return Positioned(
      top: MediaQuery.sizeOf(context).height / 2 + scanAreaSize / 2 + 40,
      left: 0,
      right: 0,
      child: Center(
        child: Text(
          _translationService.translate(SyncTranslationKeys.scannerInstruction),
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.7),
                blurRadius: 4,
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildDetectionFeedback(BuildContext context, double scanAreaSize) {
    return AnimatedBuilder(
      animation: _pulseAnimationController,
      builder: (context, child) {
        return Center(
          child: Container(
            width: scanAreaSize,
            height: scanAreaSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.green.withValues(alpha: 1.0 - _pulseAnimationController.value),
                width: 6 * (1.0 + _pulseAnimationController.value),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final double scanAreaSize;
  final Color overlayColor;

  _ScannerOverlayPainter({
    required this.scanAreaSize,
    required this.overlayColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = overlayColor;

    // Calculate the position of the scan area (centered)
    final left = (size.width - scanAreaSize) / 2;
    final top = (size.height - scanAreaSize) / 2;
    final scanRect = Rect.fromLTWH(left, top, scanAreaSize, scanAreaSize);

    // Create path for the overlay with cut-out
    final overlayPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Create rounded rectangle for the scan area
    final scanAreaPath = Path()..addRRect(RRect.fromRectAndRadius(scanRect, const Radius.circular(12)));

    // Subtract scan area from overlay
    final finalPath = Path.combine(PathOperation.difference, overlayPath, scanAreaPath);

    canvas.drawPath(finalPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

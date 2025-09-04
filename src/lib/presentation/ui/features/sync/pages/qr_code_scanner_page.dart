import 'package:flutter/foundation.dart';
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
  final _debugInputController = TextEditingController();
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
    _debugInputController.dispose();
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

  void _showDebugModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Title
              Text(
                'Debug QR Input',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // Debug input field
              TextField(
                controller: _debugInputController,
                decoration: InputDecoration(
                  labelText: '${_translationService.translate(SyncTranslationKeys.scannerTitle)} (Debug Input)',
                  hintText: 'Enter QR code data manually...',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.bug_report),
                ),
                maxLines: 3,
                onSubmitted: (value) => _submitDebugInput(context, value),
              ),
              const SizedBox(height: 20),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _submitDebugInput(context, _debugInputController.text),
                      child: const Text('Submit'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _submitDebugInput(BuildContext context, String value) {
    if (value.trim().isNotEmpty) {
      Navigator.of(context).pop(); // Close modal
      Navigator.of(context).pop(value.trim()); // Return to previous screen with value
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SecondaryAppBar(
        context: context,
        title: Text(_translationService.translate(SyncTranslationKeys.scannerTitle)),
        actions: kDebugMode
            ? [
                IconButton(
                  icon: const Icon(Icons.bug_report),
                  tooltip: 'Debug Input',
                  onPressed: () => _showDebugModal(context),
                ),
              ]
            : null,
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

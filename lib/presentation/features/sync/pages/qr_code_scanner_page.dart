import 'package:flutter/material.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:whph/presentation/shared/components/secondary_app_bar.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';

class QRCodeScannerPage extends StatefulWidget {
  static const String route = '/sync/qr-scanner';

  const QRCodeScannerPage({super.key});

  @override
  State<QRCodeScannerPage> createState() => _QRCodeScannerPageState();
}

class _QRCodeScannerPageState extends State<QRCodeScannerPage> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QRCodeScannerPage');
  QRViewController? controller;

  void _onQRViewCreated(BuildContext context, QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      controller.stopCamera();
      controller.dispose();

      if (context.mounted) Navigator.of(context).pop(scanData.code);
    });
  }

  void _showHelpModal() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: SingleChildScrollView(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'QR Scanner Help',
                      style: AppTheme.headlineSmall,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  '📱 Scan QR codes to connect and sync with other devices.',
                  style: AppTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                const Text(
                  '📸 Scanning Tips',
                  style: AppTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                ...const [
                  '• Hold camera steady',
                  '• Ensure good lighting',
                  '• Center the QR code',
                  '• Keep proper distance',
                  '• Wait for auto-focus',
                  '• Clean camera lens if needed',
                ].map((text) => Padding(
                      padding: const EdgeInsets.only(bottom: 8, left: 8),
                      child: Text(text, style: AppTheme.bodyMedium),
                    )),
                const SizedBox(height: 16),
                const Text(
                  '⚡ Process',
                  style: AppTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                ...const [
                  '1. Point camera at QR code',
                  '2. Wait for automatic scan',
                  '3. Keep devices on same network',
                  '4. Wait for connection confirmation',
                  '5. Start syncing data',
                ].map((text) => Padding(
                      padding: const EdgeInsets.only(bottom: 8, left: 8),
                      child: Text(text, style: AppTheme.bodyMedium),
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SecondaryAppBar(
        context: context,
        title: const Text('Scan QR Code'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelpModal,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(width: 2),
        ],
      ),
      body: QRView(
        key: qrKey,
        onQRViewCreated: (controller) => _onQRViewCreated(context, controller),
      ),
    );
  }
}

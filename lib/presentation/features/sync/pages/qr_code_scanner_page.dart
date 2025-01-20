import 'package:flutter/material.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:whph/presentation/shared/components/secondary_app_bar.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SecondaryAppBar(
        context: context,
        title: const Text('Scan QR Code'),
      ),
      body: QRView(
        key: qrKey,
        onQRViewCreated: (controller) => _onQRViewCreated(context, controller),
      ),
    );
  }
}

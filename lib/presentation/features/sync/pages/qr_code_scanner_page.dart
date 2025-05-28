import 'package:flutter/material.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:whph/presentation/shared/components/secondary_app_bar.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/sync/constants/sync_translation_keys.dart';

class QRCodeScannerPage extends StatefulWidget {
  static const String route = '/sync/qr-scanner';

  const QRCodeScannerPage({super.key});

  @override
  State<QRCodeScannerPage> createState() => _QRCodeScannerPageState();
}

class _QRCodeScannerPageState extends State<QRCodeScannerPage> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QRCodeScannerPage');
  final _translationService = container.resolve<ITranslationService>();
  QRViewController? controller;

  void _onQRViewCreated(BuildContext context, QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      controller.stopCamera();

      if (context.mounted) Navigator.of(context).pop(scanData.code);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SecondaryAppBar(
        context: context,
        title: Text(_translationService.translate(SyncTranslationKeys.scannerTitle)),
      ),
      body: QRView(
        key: qrKey,
        onQRViewCreated: (controller) => _onQRViewCreated(context, controller),
      ),
    );
  }
}

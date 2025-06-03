import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:whph/src/presentation/ui/shared/components/secondary_app_bar.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';
import 'package:whph/src/presentation/ui/features/sync/constants/sync_translation_keys.dart';

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
      body: kDebugMode
          ? Column(
              children: [
                // Debug Input Section
                if (kDebugMode)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: '${_translationService.translate(SyncTranslationKeys.scannerTitle)} (Debug Input)',
                      ),
                      onSubmitted: (value) {
                        if (context.mounted) Navigator.of(context).pop(value);
                      },
                    ),
                  ),
                // QR Scanner Section
                SizedBox(
                  height: MediaQuery.of(context).size.height - 100,
                  child: _buildQRCamera(context),
                ),
              ],
            )
          : _buildQRCamera(context),
    );
  }

  Widget _buildQRCamera(BuildContext context) {
    return QRView(
      key: qrKey,
      onQRViewCreated: (controller) => _onQRViewCreated(context, controller),
    );
  }
}

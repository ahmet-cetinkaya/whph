// S4 spike (T5): runs the whph_sync_core crypto benchmark on a real device.
// S4 spike code — replaced by lib/src/crypto in T11; not for production use.
//
// Run (Linux or Android device/emulator):
//   cd src && fvm flutter test integration_test/sync_crypto_spike_test.dart -d <device>
// Optional sample size: --dart-define=S4_BENCH_N=20000 (projection is linear to 200,000).
// Output: `[S4]`-prefixed numbers only; no key material or plaintext.

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:whph_sync_core/spike.dart';

const int _benchChanges = int.fromEnvironment('S4_BENCH_N', defaultValue: 20000);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('S4 crypto throughput on device', (tester) async {
    final result = await tester.runAsync(() => runCryptoBench(const CryptoBenchConfig(changes: _benchChanges)));
    expect(result, isNotNull);

    debugPrint('[S4] platform=${defaultTargetPlatform.name}');
    debugPrint('[S4] build_mode=${kReleaseMode ? 'release' : kProfileMode ? 'profile' : 'debug'}');
    for (final line in result!.toLines()) {
      debugPrint(line);
    }
    binding.reportData = {'s4_crypto': result.metrics};

    expect(result.metrics['e2e_changes'], _benchChanges);
    expect(result.metrics['projected_seconds'], greaterThan(0));
  }, timeout: const Timeout(Duration(minutes: 30)));
}

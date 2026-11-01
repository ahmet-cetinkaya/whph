/// S4 spike code — replaced by lib/src/crypto in T11; not for production use.
///
/// Exposes the minimal Noise XX / XXpsk3 implementation and the crypto
/// throughput benchmark to package tests and to the Flutter integration test
/// `src/integration_test/sync_crypto_spike_test.dart`. Deliberately NOT
/// exported from `whph_sync_core.dart`.
library;

export 'src/spike/crypto_bench.dart';
export 'src/spike/noise_spike.dart';

import 'package:whph/core/application/features/settings/models/public_setting.dart';
import 'package:whph/core/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/core/application/features/settings/services/abstraction/i_settings_effects.dart';
import 'package:whph/core/application/shared/services/abstraction/i_application_transaction_service.dart';
import 'package:whph/core/application/shared/utils/key_helper.dart';
import 'package:whph/core/domain/features/settings/setting.dart';

final class SettingRevisionConflictException implements Exception {
  const SettingRevisionConflictException(this.key);

  final PublicSettingKey key;
}

final class SettingUpdateResult {
  const SettingUpdateResult(
      {required this.setting, required this.effectApplied});

  final PublicSettingRecord setting;
  final bool effectApplied;
}

final class SettingsActions {
  const SettingsActions({
    required ISettingRepository repository,
    required IApplicationTransactionService transactions,
    required ISettingsEffects effects,
  })  : _repository = repository,
        _transactions = transactions,
        _effects = effects;

  final ISettingRepository _repository;
  final IApplicationTransactionService _transactions;
  final ISettingsEffects _effects;

  Future<List<PublicSettingRecord>> list() async {
    final records = await Future.wait(PublicSettingKey.values.map(read));
    return List<PublicSettingRecord>.unmodifiable(records);
  }

  Future<PublicSettingRecord> read(PublicSettingKey key) async {
    final setting = await _repository.getByKey(key.storageKey);
    return _record(key, setting);
  }

  Future<SettingUpdateResult> update({
    required PublicSettingKey key,
    required Object? value,
    required DateTime? expectedRevision,
    required Future<void> Function() beforeCommit,
  }) async {
    final normalizedValue = key.normalize(value);
    final result = await _transactions.run(() async {
      final current = await _repository.getByKey(key.storageKey);
      if (!_matchesRevision(current, expectedRevision)) {
        throw SettingRevisionConflictException(key);
      }
      await beforeCommit();
      final replacement = Setting(
        id: current?.id ?? KeyHelper.generateStringId(),
        createdDate: current?.createdDate ?? DateTime.now().toUtc(),
        modifiedDate: current?.modifiedDate,
        key: key.storageKey,
        value: key.encode(normalizedValue),
        valueType: key.storageType,
      );
      if (current == null) {
        await _repository.add(replacement);
        return _record(key, await _repository.getByKey(key.storageKey));
      } else {
        final revision =
            await _repository.updateIfRevision(replacement, expectedRevision!);
        if (revision == null) throw SettingRevisionConflictException(key);
        return PublicSettingRecord(
            key: key, value: normalizedValue, revision: revision);
      }
    });
    try {
      await _effects
          .apply(PublicSettingChange(key: key, value: normalizedValue));
      return SettingUpdateResult(setting: result, effectApplied: true);
    } catch (_) {
      return SettingUpdateResult(setting: result, effectApplied: false);
    }
  }

  PublicSettingRecord _record(PublicSettingKey key, Setting? setting) =>
      PublicSettingRecord(
        key: key,
        value: setting == null ? key.defaultValue : key.decode(setting.value),
        revision: setting == null
            ? null
            : setting.modifiedDate ?? setting.createdDate,
      );

  bool _matchesRevision(Setting? setting, DateTime? expected) {
    if (setting == null) return expected == null;
    if (expected == null) return false;
    final current = setting.modifiedDate ?? setting.createdDate;
    return current.toUtc().isAtSameMomentAs(expected.toUtc());
  }
}

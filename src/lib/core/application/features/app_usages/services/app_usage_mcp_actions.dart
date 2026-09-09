import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_events.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_ignore_rule_repository.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_repository.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_service.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_tag_repository.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_tag_rule_repository.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_time_record_repository.dart';
import 'package:whph/core/application/shared/services/abstraction/i_application_transaction_service.dart';
import 'package:whph/core/application/shared/utils/key_helper.dart';
import 'package:whph/core/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/core/domain/features/app_usages/app_usage.dart';
import 'package:whph/core/domain/features/app_usages/app_usage_ignore_rule.dart';
import 'package:whph/core/domain/features/app_usages/app_usage_tag.dart';
import 'package:whph/core/domain/features/app_usages/app_usage_tag_rule.dart';

final class OptionalUpdate<T> {
  const OptionalUpdate.absent()
      : isPresent = false,
        value = null;

  const OptionalUpdate.value(this.value) : isPresent = true;

  final bool isPresent;
  final T? value;
}

final class AppUsageRevisionConflict implements Exception {
  const AppUsageRevisionConflict(this.id);

  final String id;
}

final class AppUsageNotFound implements Exception {
  const AppUsageNotFound(this.id);

  final String id;
}

final class AppUsageMutationResult {
  const AppUsageMutationResult({required this.id, required this.revision});

  final String id;
  final DateTime revision;
}

final class AppUsageDeleteResult {
  const AppUsageDeleteResult({required this.id, required this.deletedAt});

  final String id;
  final DateTime deletedAt;
}

final class AppUsageActions {
  AppUsageActions({
    required IApplicationTransactionService transactionService,
    required IAppUsageRepository appUsageRepository,
    required IAppUsageTagRepository appUsageTagRepository,
    required IAppUsageTimeRecordRepository appUsageTimeRecordRepository,
    required IAppUsageTagRuleRepository tagRuleRepository,
    required IAppUsageIgnoreRuleRepository ignoreRuleRepository,
    required IAppUsageService appUsageService,
    required IAppUsageEvents appUsageEvents,
    required ITagRepository tagRepository,
    required bool isTrackingSupported,
  })  : _transactionService = transactionService,
        _appUsageRepository = appUsageRepository,
        _appUsageTagRepository = appUsageTagRepository,
        _appUsageTimeRecordRepository = appUsageTimeRecordRepository,
        _tagRuleRepository = tagRuleRepository,
        _ignoreRuleRepository = ignoreRuleRepository,
        _appUsageService = appUsageService,
        _appUsageEvents = appUsageEvents,
        _tagRepository = tagRepository,
        _isTrackingSupported = isTrackingSupported;

  final IApplicationTransactionService _transactionService;
  final IAppUsageRepository _appUsageRepository;
  final IAppUsageTagRepository _appUsageTagRepository;
  final IAppUsageTimeRecordRepository _appUsageTimeRecordRepository;
  final IAppUsageTagRuleRepository _tagRuleRepository;
  final IAppUsageIgnoreRuleRepository _ignoreRuleRepository;
  final IAppUsageService _appUsageService;
  final IAppUsageEvents _appUsageEvents;
  final ITagRepository _tagRepository;
  final bool _isTrackingSupported;

  Future<AppUsageMutationResult> update({
    required String id,
    required DateTime expectedRevision,
    OptionalUpdate<String> displayName = const OptionalUpdate.absent(),
    OptionalUpdate<String> color = const OptionalUpdate.absent(),
    List<String>? tagIds,
    List<String>? tagOrder,
    ApplicationMutationGuard? authorizeCommit,
  }) async {
    if (tagOrder != null && tagIds == null) {
      throw ArgumentError('tagOrder requires tagIds');
    }
    if ((tagIds?.length ?? 0) > 200) {
      throw ArgumentError('No more than 200 tags may be supplied');
    }
    final result = await _transactionService.run(() async {
      final existing = await _appUsageRepository.getById(id);
      if (existing == null) throw AppUsageNotFound(id);
      final updated = AppUsage(
        id: existing.id,
        createdDate: existing.createdDate,
        modifiedDate: existing.modifiedDate,
        deletedDate: existing.deletedDate,
        name: existing.name,
        displayName:
            displayName.isPresent ? displayName.value : existing.displayName,
        color: color.isPresent ? color.value : existing.color,
        deviceName: existing.deviceName,
      );
      final revision =
          await _appUsageRepository.updateIfRevision(updated, expectedRevision);
      if (revision == null) {
        throw AppUsageRevisionConflict(id);
      }
      if (tagIds != null) await _replaceTags(id, tagIds, tagOrder);
      await ensureMutationAuthorized(authorizeCommit);
      return AppUsageMutationResult(id: id, revision: revision);
    });
    _appUsageEvents.notifyAppUsageUpdated(id);
    return result;
  }

  Future<AppUsageDeleteResult> delete(
    String id,
    DateTime expectedRevision, {
    ApplicationMutationGuard? authorizeCommit,
  }) async {
    final result = await _transactionService.run(() async {
      final existing = await _appUsageRepository.getById(id);
      if (existing == null) throw AppUsageNotFound(id);
      final deletedAt = await _appUsageRepository.deleteIfRevision(
          existing, expectedRevision);
      if (deletedAt == null) {
        throw AppUsageRevisionConflict(id);
      }
      final tags = await _allTags(id);
      for (final tag in tags) {
        await _appUsageTagRepository.delete(tag);
      }
      final records = await _appUsageTimeRecordRepository.getByAppUsageId(id);
      for (final record in records) {
        await _appUsageTimeRecordRepository.delete(record);
      }
      await ensureMutationAuthorized(authorizeCommit);
      return AppUsageDeleteResult(id: id, deletedAt: deletedAt);
    });
    _appUsageEvents.notifyAppUsageDeleted(id);
    return result;
  }

  Future<AppUsageMutationResult> createTagRule(
    String pattern,
    String tagId,
    String? description, {
    ApplicationMutationGuard? authorizeCommit,
  }) async {
    RegExp(pattern);
    if (await _tagRepository.getById(tagId) == null)
      throw AppUsageNotFound(tagId);
    final rule = AppUsageTagRule(
      id: KeyHelper.generateStringId(),
      createdDate: DateTime.now().toUtc(),
      pattern: pattern,
      tagId: tagId,
      description: description,
    );
    await _transactionService.run(() async {
      await _tagRuleRepository.add(rule);
      await ensureMutationAuthorized(authorizeCommit);
    });
    _appUsageEvents.notifyAppUsageRuleCreated(rule.id);
    return AppUsageMutationResult(
        id: rule.id, revision: _databaseRevision(rule.createdDate));
  }

  Future<AppUsageDeleteResult> deleteTagRule(
    String id,
    DateTime expectedRevision, {
    ApplicationMutationGuard? authorizeCommit,
  }) async {
    final result = await _transactionService.run(() async {
      final rule = await _tagRuleRepository.getById(id);
      if (rule == null) throw AppUsageNotFound(id);
      final deletedAt =
          await _tagRuleRepository.deleteIfRevision(rule, expectedRevision);
      if (deletedAt == null) {
        throw AppUsageRevisionConflict(id);
      }
      await ensureMutationAuthorized(authorizeCommit);
      return AppUsageDeleteResult(id: id, deletedAt: deletedAt);
    });
    _appUsageEvents.notifyAppUsageRuleDeleted(id);
    return result;
  }

  Future<AppUsageMutationResult> createIgnoreRule(
    String pattern,
    String? description, {
    ApplicationMutationGuard? authorizeCommit,
  }) async {
    RegExp(pattern);
    final rule = AppUsageIgnoreRule(
      id: KeyHelper.generateStringId(),
      createdDate: DateTime.now().toUtc(),
      pattern: pattern,
      description: description,
    );
    await _transactionService.run(() async {
      await _ignoreRuleRepository.add(rule);
      await ensureMutationAuthorized(authorizeCommit);
    });
    _appUsageEvents.notifyAppUsageIgnoreRuleUpdated(rule.id);
    return AppUsageMutationResult(
        id: rule.id, revision: _databaseRevision(rule.createdDate));
  }

  Future<AppUsageDeleteResult> deleteIgnoreRule(
    String id,
    DateTime expectedRevision, {
    ApplicationMutationGuard? authorizeCommit,
  }) async {
    final result = await _transactionService.run(() async {
      final rule = await _ignoreRuleRepository.getById(id);
      if (rule == null) throw AppUsageNotFound(id);
      final deletedAt =
          await _ignoreRuleRepository.deleteIfRevision(rule, expectedRevision);
      if (deletedAt == null) {
        throw AppUsageRevisionConflict(id);
      }
      await ensureMutationAuthorized(authorizeCommit);
      return AppUsageDeleteResult(id: id, deletedAt: deletedAt);
    });
    _appUsageEvents.notifyAppUsageIgnoreRuleUpdated(id);
    return result;
  }

  Future<String> startTracking({
    ApplicationMutationGuard? authorizeCommit,
  }) async {
    if (!_isTrackingSupported) return 'unsupported_platform';
    if (!await _appUsageService.checkUsageStatsPermission())
      return 'permission_required';
    await ensureMutationAuthorized(authorizeCommit);
    try {
      await _appUsageService.startTracking(authorizeCommit: authorizeCommit);
    } on AppUsagePermissionRequiredException {
      return 'permission_required';
    }
    return _appUsageService.isTrackingActiveWindowWorking.value
        ? 'tracking'
        : 'stopped';
  }

  Future<String> stopTracking({
    ApplicationMutationGuard? authorizeCommit,
  }) async {
    if (!_isTrackingSupported) return 'unsupported_platform';
    await ensureMutationAuthorized(authorizeCommit);
    await _appUsageService.stopTracking();
    return 'stopped';
  }

  Future<void> _replaceTags(
      String appUsageId, List<String> tagIds, List<String>? tagOrder) async {
    if (tagIds.toSet().length != tagIds.length)
      throw ArgumentError('Duplicate tag id');
    if (tagOrder != null &&
        (tagOrder.length != tagIds.length ||
            !tagOrder.toSet().containsAll(tagIds))) {
      throw ArgumentError('tagOrder must contain each tag id exactly once');
    }
    for (final tagId in tagIds) {
      if (await _tagRepository.getById(tagId) == null)
        throw AppUsageNotFound(tagId);
    }
    final existing = await _allTags(appUsageId);
    final requested = tagIds.toSet();
    for (final relation
        in existing.where((relation) => !requested.contains(relation.tagId))) {
      await _appUsageTagRepository.delete(relation);
    }
    final existingIds = existing.map((relation) => relation.tagId).toSet();
    for (final tagId in tagIds.where((tagId) => !existingIds.contains(tagId))) {
      await _appUsageTagRepository.add(AppUsageTag(
        id: KeyHelper.generateStringId(),
        createdDate: DateTime.now().toUtc(),
        appUsageId: appUsageId,
        tagId: tagId,
      ));
    }
    final order = tagOrder ?? tagIds;
    await _appUsageTagRepository.updateTagOrders(appUsageId, {
      for (var index = 0; index < order.length; index++) order[index]: index,
    });
  }

  Future<List<AppUsageTag>> _allTags(String appUsageId) async {
    final result = <AppUsageTag>[];
    for (var page = 0; result.length < 10000; page++) {
      final response = await _appUsageTagRepository.getListByAppUsageId(
          appUsageId, page, 200);
      result.addAll(response.items);
      if (!response.hasNext) return List<AppUsageTag>.unmodifiable(result);
    }
    throw StateError('Too many usage tag associations.');
  }

  DateTime _databaseRevision(DateTime value) =>
      DateTime.fromMillisecondsSinceEpoch(
        (value.millisecondsSinceEpoch ~/ 1000) * 1000,
        isUtc: true,
      );
}

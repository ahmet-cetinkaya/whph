import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_ignore_rule_repository.dart';
import 'package:acore/acore.dart';
import 'package:domain/features/app_usages/app_usage_ignore_rule.dart';
import 'package:whph/core/application/features/app_usages/constants/app_usage_translation_keys.dart';

class DeleteAppUsageIgnoreRuleCommand implements IRequest<DeleteAppUsageIgnoreRuleCommandResponse> {
  final String id;

  DeleteAppUsageIgnoreRuleCommand({required this.id});
}

class DeleteAppUsageIgnoreRuleCommandResponse {
  final String id;
  final DateTime deletedDate;

  DeleteAppUsageIgnoreRuleCommandResponse({
    required this.id,
    required this.deletedDate,
  });
}

class DeleteAppUsageIgnoreRuleCommandHandler
    implements IRequestHandler<DeleteAppUsageIgnoreRuleCommand, DeleteAppUsageIgnoreRuleCommandResponse> {
  final IAppUsageIgnoreRuleRepository _repository;

  DeleteAppUsageIgnoreRuleCommandHandler({required IAppUsageIgnoreRuleRepository repository})
      : _repository = repository;

  @override
  Future<DeleteAppUsageIgnoreRuleCommandResponse> call(DeleteAppUsageIgnoreRuleCommand request) async {
    AppUsageIgnoreRule? rule = await _repository.getById(request.id);
    if (rule == null) {
      throw BusinessException(
          'App usage ignore rule not found', AppUsageTranslationKeys.appUsageIgnoreRuleNotFoundError);
    }

    await _repository.delete(rule);

    return DeleteAppUsageIgnoreRuleCommandResponse(
      id: rule.id,
      deletedDate: rule.deletedDate!,
    );
  }
}

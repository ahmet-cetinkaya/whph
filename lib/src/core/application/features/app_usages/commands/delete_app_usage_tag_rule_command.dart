import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/features/app_usages/services/abstraction/i_app_usage_tag_rule_repository.dart';
import 'package:whph/corePackages/acore/errors/business_exception.dart';
import 'package:whph/src/core/domain/features/app_usages/app_usage_tag_rule.dart';
import 'package:whph/src/core/application/features/app_usages/constants/app_usage_translation_keys.dart';

class DeleteAppUsageTagRuleCommand implements IRequest<DeleteAppUsageTagRuleCommandResponse> {
  final String id;

  DeleteAppUsageTagRuleCommand({required this.id});
}

class DeleteAppUsageTagRuleCommandResponse {
  final String id;
  final DateTime deletedDate;

  DeleteAppUsageTagRuleCommandResponse({
    required this.id,
    required this.deletedDate,
  });
}

class DeleteAppUsageTagRuleCommandHandler
    implements IRequestHandler<DeleteAppUsageTagRuleCommand, DeleteAppUsageTagRuleCommandResponse> {
  final IAppUsageTagRuleRepository _repository;

  DeleteAppUsageTagRuleCommandHandler({required IAppUsageTagRuleRepository repository}) : _repository = repository;

  @override
  Future<DeleteAppUsageTagRuleCommandResponse> call(DeleteAppUsageTagRuleCommand request) async {
    AppUsageTagRule? rule = await _repository.getById(request.id);
    if (rule == null) {
      throw BusinessException('App usage tag rule not found', AppUsageTranslationKeys.appUsageTagRuleNotFoundError);
    }

    await _repository.delete(rule);

    return DeleteAppUsageTagRuleCommandResponse(
      id: rule.id,
      deletedDate: rule.deletedDate!,
    );
  }
}

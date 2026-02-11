import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/shared/utils/key_helper.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_ignore_rule_repository.dart';
import 'package:domain/features/app_usages/app_usage_ignore_rule.dart';

class AddAppUsageIgnoreRuleCommand implements IRequest<AddAppUsageIgnoreRuleCommandResponse> {
  final String pattern;
  final String? description;

  AddAppUsageIgnoreRuleCommand({
    required this.pattern,
    this.description,
  });
}

class AddAppUsageIgnoreRuleCommandResponse {
  final String id;

  AddAppUsageIgnoreRuleCommandResponse({required this.id});
}

class AddAppUsageIgnoreRuleCommandHandler
    implements IRequestHandler<AddAppUsageIgnoreRuleCommand, AddAppUsageIgnoreRuleCommandResponse> {
  final IAppUsageIgnoreRuleRepository _repository;

  AddAppUsageIgnoreRuleCommandHandler({required IAppUsageIgnoreRuleRepository repository}) : _repository = repository;

  @override
  Future<AddAppUsageIgnoreRuleCommandResponse> call(AddAppUsageIgnoreRuleCommand request) async {
    final rule = AppUsageIgnoreRule(
      id: KeyHelper.generateStringId(),
      createdDate: DateTime.now().toUtc(),
      pattern: request.pattern,
      description: request.description,
    );

    await _repository.add(rule);

    return AddAppUsageIgnoreRuleCommandResponse(id: rule.id);
  }
}

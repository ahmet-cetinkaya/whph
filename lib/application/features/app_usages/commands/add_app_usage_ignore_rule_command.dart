import 'package:mediatr/mediatr.dart';
import 'package:nanoid2/nanoid2.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_ignore_rule_repository.dart';
import 'package:whph/domain/features/app_usages/app_usage_ignore_rule.dart';

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
      id: nanoid(),
      createdDate: DateTime.now(),
      pattern: request.pattern,
      description: request.description,
    );

    await _repository.add(rule);

    return AddAppUsageIgnoreRuleCommandResponse(id: rule.id);
  }
}

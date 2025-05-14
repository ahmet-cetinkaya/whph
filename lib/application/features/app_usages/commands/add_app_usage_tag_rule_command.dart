import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_tag_rule_repository.dart';
import 'package:whph/application/shared/utils/key_helper.dart';
import 'package:whph/domain/features/app_usages/app_usage_tag_rule.dart';

class AddAppUsageTagRuleCommand implements IRequest<AddAppUsageTagRuleCommandResponse> {
  final String pattern;
  final String tagId;
  final String? description;

  AddAppUsageTagRuleCommand({
    required this.pattern,
    required this.tagId,
    this.description,
  });
}

class AddAppUsageTagRuleCommandResponse {
  final String id;

  AddAppUsageTagRuleCommandResponse({required this.id});
}

class AddAppUsageTagRuleCommandHandler
    implements IRequestHandler<AddAppUsageTagRuleCommand, AddAppUsageTagRuleCommandResponse> {
  final IAppUsageTagRuleRepository _repository;

  AddAppUsageTagRuleCommandHandler({required IAppUsageTagRuleRepository repository}) : _repository = repository;

  @override
  Future<AddAppUsageTagRuleCommandResponse> call(AddAppUsageTagRuleCommand request) async {
    final rule = AppUsageTagRule(
      id: KeyHelper.generateStringId(),
      createdDate: DateTime.now(),
      pattern: request.pattern,
      tagId: request.tagId,
      description: request.description,
    );

    await _repository.add(rule);

    return AddAppUsageTagRuleCommandResponse(id: rule.id);
  }
}

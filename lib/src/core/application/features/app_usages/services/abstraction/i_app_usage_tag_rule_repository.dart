import 'package:whph/src/core/domain/features/app_usages/app_usage_tag_rule.dart';
import 'package:whph/src/core/application/shared/services/abstraction/i_repository.dart' as app;

abstract class IAppUsageTagRuleRepository extends app.IRepository<AppUsageTagRule, String> {}

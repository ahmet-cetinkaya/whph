import 'package:whph/src/core/domain/features/app_usages/app_usage_ignore_rule.dart';
import 'package:whph/src/core/application/shared/services/abstraction/i_repository.dart' as app;

abstract class IAppUsageIgnoreRuleRepository extends app.IRepository<AppUsageIgnoreRule, String> {}

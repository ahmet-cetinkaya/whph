import 'package:acore/acore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:whph/core/application/features/tasks/commands/normalize_task_orders_command.dart';

import 'save_task_command_test.mocks.dart';

void main() {
  test('normalization requests the same deterministic total order as the visible task query', () async {
    final repository = MockITaskRepository();
    when(repository.getAll(
      customWhereFilter: anyNamed('customWhereFilter'),
      customOrder: anyNamed('customOrder'),
    )).thenAnswer((_) async => []);

    await NormalizeTaskOrdersCommandHandler(repository)(const NormalizeTaskOrdersCommand());

    final capturedOrders = verify(repository.getAll(
      customWhereFilter: anyNamed('customWhereFilter'),
      customOrder: captureAnyNamed('customOrder'),
    )).captured.single as List<CustomOrder>;
    expect(capturedOrders.map((order) => order.field), ['order', 'created_date', 'id']);
  });
}

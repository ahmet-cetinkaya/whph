import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:application/features/settings/queries/get_setting_query.dart';
import 'package:application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:domain/features/settings/setting.dart';

class MockSettingRepository extends Mock implements ISettingRepository {
  @override
  Future<Setting?> getByKey(String? key) => super.noSuchMethod(
        Invocation.method(#getByKey, [key]),
        returnValue: Future<Setting?>.value(null),
        returnValueForMissingStub: Future<Setting?>.value(null),
      );

  @override
  Future<Setting?> getById(String? id, {bool includeDeleted = false}) => super.noSuchMethod(
        Invocation.method(#getById, [id], {#includeDeleted: includeDeleted}),
        returnValue: Future<Setting?>.value(null),
        returnValueForMissingStub: Future<Setting?>.value(null),
      );
}

void main() {
  late MockSettingRepository mockRepository;
  late GetSettingQueryHandler handler;

  setUp(() {
    mockRepository = MockSettingRepository();
    handler = GetSettingQueryHandler(settingRepository: mockRepository);
  });

  test('should return null when setting is not found by key', () async {
    when(mockRepository.getByKey(any)).thenAnswer((_) async => null);

    final query = GetSettingQuery(key: 'non_existent_key');

    final result = await handler.call(query);
    expect(result, isNull);
  });
}

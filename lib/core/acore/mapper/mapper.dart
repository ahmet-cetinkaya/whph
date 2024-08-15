import 'abstraction/i_mapper.dart';

class CoreMapper implements IMapper {
  // <<TDestination, TSource>, MapperFunction>
  final Map<Map<Type, Type>, Function> _maps = {};

  @override
  void addMap<TDestination, TSource>(TDestination Function(TSource source) mapper) {
    _maps[Map<Type, Type>.from({TDestination: TSource})] = (source) => mapper(source);
  }

  @override
  TDestination map<TDestination, TSource>(TSource sourceObject) {
    final map = _maps[Map<Type, Type>.from({TDestination: TSource})];
    if (map == null) {
      throw Exception('Map not found');
    }

    return map(sourceObject) as TDestination;
  }
}

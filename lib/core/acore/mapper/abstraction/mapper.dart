abstract class IMapper {
  void addMap<TDestination, TSource>(TDestination Function(TSource source) mapper);
  TDestination map<TDestination, TSource>(TSource sourceObject);
}

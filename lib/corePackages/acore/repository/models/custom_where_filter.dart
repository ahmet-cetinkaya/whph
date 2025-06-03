class CustomWhereFilter {
  String query;
  List<Object> variables;

  CustomWhereFilter(this.query, this.variables);

  factory CustomWhereFilter.empty() {
    return CustomWhereFilter('', []);
  }
}

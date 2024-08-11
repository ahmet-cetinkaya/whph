// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'drift_app_context.dart';

// ignore_for_file: type=lint
class $AppUsageTableTable extends AppUsageTable with TableInfo<$AppUsageTableTable, AppUsage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppUsageTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id =
      GeneratedColumn<String>('id', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdDateMeta = const VerificationMeta('createdDate');
  @override
  late final GeneratedColumn<DateTime> createdDate = GeneratedColumn<DateTime>('created_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _modifiedDateMeta = const VerificationMeta('modifiedDate');
  @override
  late final GeneratedColumn<DateTime> modifiedDate = GeneratedColumn<DateTime>('modified_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title =
      GeneratedColumn<String>('title', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _processNameMeta = const VerificationMeta('processName');
  @override
  late final GeneratedColumn<String> processName = GeneratedColumn<String>('process_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _durationMeta = const VerificationMeta('duration');
  @override
  late final GeneratedColumn<int> duration =
      GeneratedColumn<int>('duration', aliasedName, false, type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, createdDate, modifiedDate, title, processName, duration];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_usage_table';
  @override
  VerificationContext validateIntegrity(Insertable<AppUsage> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_date')) {
      context.handle(_createdDateMeta, createdDate.isAcceptableOrUnknown(data['created_date']!, _createdDateMeta));
    } else if (isInserting) {
      context.missing(_createdDateMeta);
    }
    if (data.containsKey('modified_date')) {
      context.handle(_modifiedDateMeta, modifiedDate.isAcceptableOrUnknown(data['modified_date']!, _modifiedDateMeta));
    }
    if (data.containsKey('title')) {
      context.handle(_titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('process_name')) {
      context.handle(_processNameMeta, processName.isAcceptableOrUnknown(data['process_name']!, _processNameMeta));
    }
    if (data.containsKey('duration')) {
      context.handle(_durationMeta, duration.isAcceptableOrUnknown(data['duration']!, _durationMeta));
    } else if (isInserting) {
      context.missing(_durationMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppUsage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppUsage(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      createdDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_date'])!,
      modifiedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}modified_date']),
      title: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      processName: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}process_name']),
      duration: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}duration'])!,
    );
  }

  @override
  $AppUsageTableTable createAlias(String alias) {
    return $AppUsageTableTable(attachedDatabase, alias);
  }
}

class AppUsageTableCompanion extends UpdateCompanion<AppUsage> {
  final Value<String> id;
  final Value<DateTime> createdDate;
  final Value<DateTime?> modifiedDate;
  final Value<String> title;
  final Value<String?> processName;
  final Value<int> duration;
  final Value<int> rowid;
  const AppUsageTableCompanion({
    this.id = const Value.absent(),
    this.createdDate = const Value.absent(),
    this.modifiedDate = const Value.absent(),
    this.title = const Value.absent(),
    this.processName = const Value.absent(),
    this.duration = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppUsageTableCompanion.insert({
    required String id,
    required DateTime createdDate,
    this.modifiedDate = const Value.absent(),
    required String title,
    this.processName = const Value.absent(),
    required int duration,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        createdDate = Value(createdDate),
        title = Value(title),
        duration = Value(duration);
  static Insertable<AppUsage> custom({
    Expression<String>? id,
    Expression<DateTime>? createdDate,
    Expression<DateTime>? modifiedDate,
    Expression<String>? title,
    Expression<String>? processName,
    Expression<int>? duration,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdDate != null) 'created_date': createdDate,
      if (modifiedDate != null) 'modified_date': modifiedDate,
      if (title != null) 'title': title,
      if (processName != null) 'process_name': processName,
      if (duration != null) 'duration': duration,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppUsageTableCompanion copyWith(
      {Value<String>? id,
      Value<DateTime>? createdDate,
      Value<DateTime?>? modifiedDate,
      Value<String>? title,
      Value<String?>? processName,
      Value<int>? duration,
      Value<int>? rowid}) {
    return AppUsageTableCompanion(
      id: id ?? this.id,
      createdDate: createdDate ?? this.createdDate,
      modifiedDate: modifiedDate ?? this.modifiedDate,
      title: title ?? this.title,
      processName: processName ?? this.processName,
      duration: duration ?? this.duration,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdDate.present) {
      map['created_date'] = Variable<DateTime>(createdDate.value);
    }
    if (modifiedDate.present) {
      map['modified_date'] = Variable<DateTime>(modifiedDate.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (processName.present) {
      map['process_name'] = Variable<String>(processName.value);
    }
    if (duration.present) {
      map['duration'] = Variable<int>(duration.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppUsageTableCompanion(')
          ..write('id: $id, ')
          ..write('createdDate: $createdDate, ')
          ..write('modifiedDate: $modifiedDate, ')
          ..write('title: $title, ')
          ..write('processName: $processName, ')
          ..write('duration: $duration, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AppUsageTableTable appUsageTable = $AppUsageTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [appUsageTable];
}

typedef $$AppUsageTableTableCreateCompanionBuilder = AppUsageTableCompanion Function({
  required String id,
  required DateTime createdDate,
  Value<DateTime?> modifiedDate,
  required String title,
  Value<String?> processName,
  required int duration,
  Value<int> rowid,
});
typedef $$AppUsageTableTableUpdateCompanionBuilder = AppUsageTableCompanion Function({
  Value<String> id,
  Value<DateTime> createdDate,
  Value<DateTime?> modifiedDate,
  Value<String> title,
  Value<String?> processName,
  Value<int> duration,
  Value<int> rowid,
});

class $$AppUsageTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AppUsageTableTable,
    AppUsage,
    $$AppUsageTableTableFilterComposer,
    $$AppUsageTableTableOrderingComposer,
    $$AppUsageTableTableCreateCompanionBuilder,
    $$AppUsageTableTableUpdateCompanionBuilder> {
  $$AppUsageTableTableTableManager(_$AppDatabase db, $AppUsageTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer: $$AppUsageTableTableFilterComposer(ComposerState(db, table)),
          orderingComposer: $$AppUsageTableTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<DateTime> createdDate = const Value.absent(),
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> processName = const Value.absent(),
            Value<int> duration = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppUsageTableCompanion(
            id: id,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            title: title,
            processName: processName,
            duration: duration,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required DateTime createdDate,
            Value<DateTime?> modifiedDate = const Value.absent(),
            required String title,
            Value<String?> processName = const Value.absent(),
            required int duration,
            Value<int> rowid = const Value.absent(),
          }) =>
              AppUsageTableCompanion.insert(
            id: id,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            title: title,
            processName: processName,
            duration: duration,
            rowid: rowid,
          ),
        ));
}

class $$AppUsageTableTableFilterComposer extends FilterComposer<_$AppDatabase, $AppUsageTableTable> {
  $$AppUsageTableTableFilterComposer(super.$state);
  ColumnFilters<String> get id => $state.composableBuilder(
      column: $state.table.id, builder: (column, joinBuilders) => ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get createdDate => $state.composableBuilder(
      column: $state.table.createdDate,
      builder: (column, joinBuilders) => ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get modifiedDate => $state.composableBuilder(
      column: $state.table.modifiedDate,
      builder: (column, joinBuilders) => ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get title => $state.composableBuilder(
      column: $state.table.title, builder: (column, joinBuilders) => ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get processName => $state.composableBuilder(
      column: $state.table.processName,
      builder: (column, joinBuilders) => ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get duration => $state.composableBuilder(
      column: $state.table.duration,
      builder: (column, joinBuilders) => ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$AppUsageTableTableOrderingComposer extends OrderingComposer<_$AppDatabase, $AppUsageTableTable> {
  $$AppUsageTableTableOrderingComposer(super.$state);
  ColumnOrderings<String> get id => $state.composableBuilder(
      column: $state.table.id, builder: (column, joinBuilders) => ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get createdDate => $state.composableBuilder(
      column: $state.table.createdDate,
      builder: (column, joinBuilders) => ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get modifiedDate => $state.composableBuilder(
      column: $state.table.modifiedDate,
      builder: (column, joinBuilders) => ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get title => $state.composableBuilder(
      column: $state.table.title,
      builder: (column, joinBuilders) => ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get processName => $state.composableBuilder(
      column: $state.table.processName,
      builder: (column, joinBuilders) => ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get duration => $state.composableBuilder(
      column: $state.table.duration,
      builder: (column, joinBuilders) => ColumnOrderings(column, joinBuilders: joinBuilders));
}

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AppUsageTableTableTableManager get appUsageTable => $$AppUsageTableTableTableManager(_db, _db.appUsageTable);
}

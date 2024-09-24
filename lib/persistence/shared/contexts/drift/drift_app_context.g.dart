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

class $AppUsageTagTableTable extends AppUsageTagTable with TableInfo<$AppUsageTagTableTable, AppUsageTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppUsageTagTableTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _appUsageIdMeta = const VerificationMeta('appUsageId');
  @override
  late final GeneratedColumn<String> appUsageId = GeneratedColumn<String>('app_usage_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<int> tagId =
      GeneratedColumn<int>('tag_id', aliasedName, false, type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, createdDate, modifiedDate, appUsageId, tagId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_usage_tag_table';
  @override
  VerificationContext validateIntegrity(Insertable<AppUsageTag> instance, {bool isInserting = false}) {
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
    if (data.containsKey('app_usage_id')) {
      context.handle(_appUsageIdMeta, appUsageId.isAcceptableOrUnknown(data['app_usage_id']!, _appUsageIdMeta));
    } else if (isInserting) {
      context.missing(_appUsageIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(_tagIdMeta, tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta));
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  AppUsageTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppUsageTag(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      createdDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_date'])!,
      modifiedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}modified_date']),
      appUsageId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}app_usage_id'])!,
      tagId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}tag_id'])!,
    );
  }

  @override
  $AppUsageTagTableTable createAlias(String alias) {
    return $AppUsageTagTableTable(attachedDatabase, alias);
  }
}

class AppUsageTagTableCompanion extends UpdateCompanion<AppUsageTag> {
  final Value<String> id;
  final Value<DateTime> createdDate;
  final Value<DateTime?> modifiedDate;
  final Value<String> appUsageId;
  final Value<int> tagId;
  final Value<int> rowid;
  const AppUsageTagTableCompanion({
    this.id = const Value.absent(),
    this.createdDate = const Value.absent(),
    this.modifiedDate = const Value.absent(),
    this.appUsageId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppUsageTagTableCompanion.insert({
    required String id,
    required DateTime createdDate,
    this.modifiedDate = const Value.absent(),
    required String appUsageId,
    required int tagId,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        createdDate = Value(createdDate),
        appUsageId = Value(appUsageId),
        tagId = Value(tagId);
  static Insertable<AppUsageTag> custom({
    Expression<String>? id,
    Expression<DateTime>? createdDate,
    Expression<DateTime>? modifiedDate,
    Expression<String>? appUsageId,
    Expression<int>? tagId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdDate != null) 'created_date': createdDate,
      if (modifiedDate != null) 'modified_date': modifiedDate,
      if (appUsageId != null) 'app_usage_id': appUsageId,
      if (tagId != null) 'tag_id': tagId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppUsageTagTableCompanion copyWith(
      {Value<String>? id,
      Value<DateTime>? createdDate,
      Value<DateTime?>? modifiedDate,
      Value<String>? appUsageId,
      Value<int>? tagId,
      Value<int>? rowid}) {
    return AppUsageTagTableCompanion(
      id: id ?? this.id,
      createdDate: createdDate ?? this.createdDate,
      modifiedDate: modifiedDate ?? this.modifiedDate,
      appUsageId: appUsageId ?? this.appUsageId,
      tagId: tagId ?? this.tagId,
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
    if (appUsageId.present) {
      map['app_usage_id'] = Variable<String>(appUsageId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<int>(tagId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppUsageTagTableCompanion(')
          ..write('id: $id, ')
          ..write('createdDate: $createdDate, ')
          ..write('modifiedDate: $modifiedDate, ')
          ..write('appUsageId: $appUsageId, ')
          ..write('tagId: $tagId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HabitTableTable extends HabitTable with TableInfo<$HabitTableTable, Habit> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HabitTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>('id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _createdDateMeta = const VerificationMeta('createdDate');
  @override
  late final GeneratedColumn<DateTime> createdDate = GeneratedColumn<DateTime>('created_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _modifiedDateMeta = const VerificationMeta('modifiedDate');
  @override
  late final GeneratedColumn<DateTime> modifiedDate = GeneratedColumn<DateTime>('modified_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name =
      GeneratedColumn<String>('name', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta = const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description =
      GeneratedColumn<String>('description', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, createdDate, modifiedDate, name, description];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'habit_table';
  @override
  VerificationContext validateIntegrity(Insertable<Habit> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_date')) {
      context.handle(_createdDateMeta, createdDate.isAcceptableOrUnknown(data['created_date']!, _createdDateMeta));
    } else if (isInserting) {
      context.missing(_createdDateMeta);
    }
    if (data.containsKey('modified_date')) {
      context.handle(_modifiedDateMeta, modifiedDate.isAcceptableOrUnknown(data['modified_date']!, _modifiedDateMeta));
    }
    if (data.containsKey('name')) {
      context.handle(_nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(_descriptionMeta, description.isAcceptableOrUnknown(data['description']!, _descriptionMeta));
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Habit map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Habit(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      createdDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_date'])!,
      modifiedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}modified_date']),
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      description: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}description'])!,
    );
  }

  @override
  $HabitTableTable createAlias(String alias) {
    return $HabitTableTable(attachedDatabase, alias);
  }
}

class HabitTableCompanion extends UpdateCompanion<Habit> {
  final Value<int> id;
  final Value<DateTime> createdDate;
  final Value<DateTime?> modifiedDate;
  final Value<String> name;
  final Value<String> description;
  const HabitTableCompanion({
    this.id = const Value.absent(),
    this.createdDate = const Value.absent(),
    this.modifiedDate = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
  });
  HabitTableCompanion.insert({
    this.id = const Value.absent(),
    required DateTime createdDate,
    this.modifiedDate = const Value.absent(),
    required String name,
    required String description,
  })  : createdDate = Value(createdDate),
        name = Value(name),
        description = Value(description);
  static Insertable<Habit> custom({
    Expression<int>? id,
    Expression<DateTime>? createdDate,
    Expression<DateTime>? modifiedDate,
    Expression<String>? name,
    Expression<String>? description,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdDate != null) 'created_date': createdDate,
      if (modifiedDate != null) 'modified_date': modifiedDate,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
    });
  }

  HabitTableCompanion copyWith(
      {Value<int>? id,
      Value<DateTime>? createdDate,
      Value<DateTime?>? modifiedDate,
      Value<String>? name,
      Value<String>? description}) {
    return HabitTableCompanion(
      id: id ?? this.id,
      createdDate: createdDate ?? this.createdDate,
      modifiedDate: modifiedDate ?? this.modifiedDate,
      name: name ?? this.name,
      description: description ?? this.description,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (createdDate.present) {
      map['created_date'] = Variable<DateTime>(createdDate.value);
    }
    if (modifiedDate.present) {
      map['modified_date'] = Variable<DateTime>(modifiedDate.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HabitTableCompanion(')
          ..write('id: $id, ')
          ..write('createdDate: $createdDate, ')
          ..write('modifiedDate: $modifiedDate, ')
          ..write('name: $name, ')
          ..write('description: $description')
          ..write(')'))
        .toString();
  }
}

class $HabitRecordTableTable extends HabitRecordTable with TableInfo<$HabitRecordTableTable, HabitRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HabitRecordTableTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _habitIdMeta = const VerificationMeta('habitId');
  @override
  late final GeneratedColumn<int> habitId =
      GeneratedColumn<int>('habit_id', aliasedName, false, type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date =
      GeneratedColumn<DateTime>('date', aliasedName, false, type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, createdDate, modifiedDate, habitId, date];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'habit_record_table';
  @override
  VerificationContext validateIntegrity(Insertable<HabitRecord> instance, {bool isInserting = false}) {
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
    if (data.containsKey('habit_id')) {
      context.handle(_habitIdMeta, habitId.isAcceptableOrUnknown(data['habit_id']!, _habitIdMeta));
    } else if (isInserting) {
      context.missing(_habitIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(_dateMeta, date.isAcceptableOrUnknown(data['date']!, _dateMeta));
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  HabitRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HabitRecord(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      createdDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_date'])!,
      modifiedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}modified_date']),
      habitId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}habit_id'])!,
      date: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}date'])!,
    );
  }

  @override
  $HabitRecordTableTable createAlias(String alias) {
    return $HabitRecordTableTable(attachedDatabase, alias);
  }
}

class HabitRecordTableCompanion extends UpdateCompanion<HabitRecord> {
  final Value<String> id;
  final Value<DateTime> createdDate;
  final Value<DateTime?> modifiedDate;
  final Value<int> habitId;
  final Value<DateTime> date;
  final Value<int> rowid;
  const HabitRecordTableCompanion({
    this.id = const Value.absent(),
    this.createdDate = const Value.absent(),
    this.modifiedDate = const Value.absent(),
    this.habitId = const Value.absent(),
    this.date = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HabitRecordTableCompanion.insert({
    required String id,
    required DateTime createdDate,
    this.modifiedDate = const Value.absent(),
    required int habitId,
    required DateTime date,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        createdDate = Value(createdDate),
        habitId = Value(habitId),
        date = Value(date);
  static Insertable<HabitRecord> custom({
    Expression<String>? id,
    Expression<DateTime>? createdDate,
    Expression<DateTime>? modifiedDate,
    Expression<int>? habitId,
    Expression<DateTime>? date,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdDate != null) 'created_date': createdDate,
      if (modifiedDate != null) 'modified_date': modifiedDate,
      if (habitId != null) 'habit_id': habitId,
      if (date != null) 'date': date,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HabitRecordTableCompanion copyWith(
      {Value<String>? id,
      Value<DateTime>? createdDate,
      Value<DateTime?>? modifiedDate,
      Value<int>? habitId,
      Value<DateTime>? date,
      Value<int>? rowid}) {
    return HabitRecordTableCompanion(
      id: id ?? this.id,
      createdDate: createdDate ?? this.createdDate,
      modifiedDate: modifiedDate ?? this.modifiedDate,
      habitId: habitId ?? this.habitId,
      date: date ?? this.date,
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
    if (habitId.present) {
      map['habit_id'] = Variable<int>(habitId.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HabitRecordTableCompanion(')
          ..write('id: $id, ')
          ..write('createdDate: $createdDate, ')
          ..write('modifiedDate: $modifiedDate, ')
          ..write('habitId: $habitId, ')
          ..write('date: $date, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TaskTableTable extends TaskTable with TableInfo<$TaskTableTable, Task> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaskTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>('id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
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
  static const VerificationMeta _descriptionMeta = const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description =
      GeneratedColumn<String>('description', aliasedName, true, type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _priorityMeta = const VerificationMeta('priority');
  @override
  late final GeneratedColumnWithTypeConverter<EisenhowerPriority?, int> priority =
      GeneratedColumn<int>('priority', aliasedName, true, type: DriftSqlType.int, requiredDuringInsert: false)
          .withConverter<EisenhowerPriority?>($TaskTableTable.$converterpriorityn);
  static const VerificationMeta _plannedDateMeta = const VerificationMeta('plannedDate');
  @override
  late final GeneratedColumn<DateTime> plannedDate = GeneratedColumn<DateTime>('planned_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deadlineDateMeta = const VerificationMeta('deadlineDate');
  @override
  late final GeneratedColumn<DateTime> deadlineDate = GeneratedColumn<DateTime>('deadline_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _estimatedTimeMeta = const VerificationMeta('estimatedTime');
  @override
  late final GeneratedColumn<int> estimatedTime =
      GeneratedColumn<int>('estimated_time', aliasedName, true, type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _elapsedTimeMeta = const VerificationMeta('elapsedTime');
  @override
  late final GeneratedColumn<int> elapsedTime =
      GeneratedColumn<int>('elapsed_time', aliasedName, true, type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _isCompletedMeta = const VerificationMeta('isCompleted');
  @override
  late final GeneratedColumn<bool> isCompleted = GeneratedColumn<bool>('is_completed', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("is_completed" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        createdDate,
        modifiedDate,
        title,
        description,
        priority,
        plannedDate,
        deadlineDate,
        estimatedTime,
        elapsedTime,
        isCompleted
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'task_table';
  @override
  VerificationContext validateIntegrity(Insertable<Task> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
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
    if (data.containsKey('description')) {
      context.handle(_descriptionMeta, description.isAcceptableOrUnknown(data['description']!, _descriptionMeta));
    }
    context.handle(_priorityMeta, const VerificationResult.success());
    if (data.containsKey('planned_date')) {
      context.handle(_plannedDateMeta, plannedDate.isAcceptableOrUnknown(data['planned_date']!, _plannedDateMeta));
    }
    if (data.containsKey('deadline_date')) {
      context.handle(_deadlineDateMeta, deadlineDate.isAcceptableOrUnknown(data['deadline_date']!, _deadlineDateMeta));
    }
    if (data.containsKey('estimated_time')) {
      context.handle(
          _estimatedTimeMeta, estimatedTime.isAcceptableOrUnknown(data['estimated_time']!, _estimatedTimeMeta));
    }
    if (data.containsKey('elapsed_time')) {
      context.handle(_elapsedTimeMeta, elapsedTime.isAcceptableOrUnknown(data['elapsed_time']!, _elapsedTimeMeta));
    }
    if (data.containsKey('is_completed')) {
      context.handle(_isCompletedMeta, isCompleted.isAcceptableOrUnknown(data['is_completed']!, _isCompletedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Task map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Task(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      createdDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_date'])!,
      modifiedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}modified_date']),
      title: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      description: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}description']),
      plannedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}planned_date']),
      deadlineDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}deadline_date']),
      priority: $TaskTableTable.$converterpriorityn
          .fromSql(attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}priority'])),
      estimatedTime: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}estimated_time']),
      elapsedTime: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}elapsed_time']),
      isCompleted: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}is_completed'])!,
    );
  }

  @override
  $TaskTableTable createAlias(String alias) {
    return $TaskTableTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<EisenhowerPriority, int, int> $converterpriority =
      const EnumIndexConverter<EisenhowerPriority>(EisenhowerPriority.values);
  static JsonTypeConverter2<EisenhowerPriority?, int?, int?> $converterpriorityn =
      JsonTypeConverter2.asNullable($converterpriority);
}

class TaskTableCompanion extends UpdateCompanion<Task> {
  final Value<int> id;
  final Value<DateTime> createdDate;
  final Value<DateTime?> modifiedDate;
  final Value<String> title;
  final Value<String?> description;
  final Value<EisenhowerPriority?> priority;
  final Value<DateTime?> plannedDate;
  final Value<DateTime?> deadlineDate;
  final Value<int?> estimatedTime;
  final Value<int?> elapsedTime;
  final Value<bool> isCompleted;
  const TaskTableCompanion({
    this.id = const Value.absent(),
    this.createdDate = const Value.absent(),
    this.modifiedDate = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.priority = const Value.absent(),
    this.plannedDate = const Value.absent(),
    this.deadlineDate = const Value.absent(),
    this.estimatedTime = const Value.absent(),
    this.elapsedTime = const Value.absent(),
    this.isCompleted = const Value.absent(),
  });
  TaskTableCompanion.insert({
    this.id = const Value.absent(),
    required DateTime createdDate,
    this.modifiedDate = const Value.absent(),
    required String title,
    this.description = const Value.absent(),
    this.priority = const Value.absent(),
    this.plannedDate = const Value.absent(),
    this.deadlineDate = const Value.absent(),
    this.estimatedTime = const Value.absent(),
    this.elapsedTime = const Value.absent(),
    this.isCompleted = const Value.absent(),
  })  : createdDate = Value(createdDate),
        title = Value(title);
  static Insertable<Task> custom({
    Expression<int>? id,
    Expression<DateTime>? createdDate,
    Expression<DateTime>? modifiedDate,
    Expression<String>? title,
    Expression<String>? description,
    Expression<int>? priority,
    Expression<DateTime>? plannedDate,
    Expression<DateTime>? deadlineDate,
    Expression<int>? estimatedTime,
    Expression<int>? elapsedTime,
    Expression<bool>? isCompleted,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdDate != null) 'created_date': createdDate,
      if (modifiedDate != null) 'modified_date': modifiedDate,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (priority != null) 'priority': priority,
      if (plannedDate != null) 'planned_date': plannedDate,
      if (deadlineDate != null) 'deadline_date': deadlineDate,
      if (estimatedTime != null) 'estimated_time': estimatedTime,
      if (elapsedTime != null) 'elapsed_time': elapsedTime,
      if (isCompleted != null) 'is_completed': isCompleted,
    });
  }

  TaskTableCompanion copyWith(
      {Value<int>? id,
      Value<DateTime>? createdDate,
      Value<DateTime?>? modifiedDate,
      Value<String>? title,
      Value<String?>? description,
      Value<EisenhowerPriority?>? priority,
      Value<DateTime?>? plannedDate,
      Value<DateTime?>? deadlineDate,
      Value<int?>? estimatedTime,
      Value<int?>? elapsedTime,
      Value<bool>? isCompleted}) {
    return TaskTableCompanion(
      id: id ?? this.id,
      createdDate: createdDate ?? this.createdDate,
      modifiedDate: modifiedDate ?? this.modifiedDate,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      plannedDate: plannedDate ?? this.plannedDate,
      deadlineDate: deadlineDate ?? this.deadlineDate,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      elapsedTime: elapsedTime ?? this.elapsedTime,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
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
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>($TaskTableTable.$converterpriorityn.toSql(priority.value));
    }
    if (plannedDate.present) {
      map['planned_date'] = Variable<DateTime>(plannedDate.value);
    }
    if (deadlineDate.present) {
      map['deadline_date'] = Variable<DateTime>(deadlineDate.value);
    }
    if (estimatedTime.present) {
      map['estimated_time'] = Variable<int>(estimatedTime.value);
    }
    if (elapsedTime.present) {
      map['elapsed_time'] = Variable<int>(elapsedTime.value);
    }
    if (isCompleted.present) {
      map['is_completed'] = Variable<bool>(isCompleted.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaskTableCompanion(')
          ..write('id: $id, ')
          ..write('createdDate: $createdDate, ')
          ..write('modifiedDate: $modifiedDate, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('priority: $priority, ')
          ..write('plannedDate: $plannedDate, ')
          ..write('deadlineDate: $deadlineDate, ')
          ..write('estimatedTime: $estimatedTime, ')
          ..write('elapsedTime: $elapsedTime, ')
          ..write('isCompleted: $isCompleted')
          ..write(')'))
        .toString();
  }
}

class $TaskTagTableTable extends TaskTagTable with TableInfo<$TaskTagTableTable, TaskTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaskTagTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>('id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _createdDateMeta = const VerificationMeta('createdDate');
  @override
  late final GeneratedColumn<DateTime> createdDate = GeneratedColumn<DateTime>('created_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _modifiedDateMeta = const VerificationMeta('modifiedDate');
  @override
  late final GeneratedColumn<DateTime> modifiedDate = GeneratedColumn<DateTime>('modified_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<int> taskId =
      GeneratedColumn<int>('task_id', aliasedName, false, type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<int> tagId =
      GeneratedColumn<int>('tag_id', aliasedName, false, type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, createdDate, modifiedDate, taskId, tagId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'task_tag_table';
  @override
  VerificationContext validateIntegrity(Insertable<TaskTag> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_date')) {
      context.handle(_createdDateMeta, createdDate.isAcceptableOrUnknown(data['created_date']!, _createdDateMeta));
    } else if (isInserting) {
      context.missing(_createdDateMeta);
    }
    if (data.containsKey('modified_date')) {
      context.handle(_modifiedDateMeta, modifiedDate.isAcceptableOrUnknown(data['modified_date']!, _modifiedDateMeta));
    }
    if (data.containsKey('task_id')) {
      context.handle(_taskIdMeta, taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta));
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(_tagIdMeta, tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta));
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TaskTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskTag(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      createdDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_date'])!,
      modifiedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}modified_date']),
      taskId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}task_id'])!,
      tagId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}tag_id'])!,
    );
  }

  @override
  $TaskTagTableTable createAlias(String alias) {
    return $TaskTagTableTable(attachedDatabase, alias);
  }
}

class TaskTagTableCompanion extends UpdateCompanion<TaskTag> {
  final Value<int> id;
  final Value<DateTime> createdDate;
  final Value<DateTime?> modifiedDate;
  final Value<int> taskId;
  final Value<int> tagId;
  const TaskTagTableCompanion({
    this.id = const Value.absent(),
    this.createdDate = const Value.absent(),
    this.modifiedDate = const Value.absent(),
    this.taskId = const Value.absent(),
    this.tagId = const Value.absent(),
  });
  TaskTagTableCompanion.insert({
    this.id = const Value.absent(),
    required DateTime createdDate,
    this.modifiedDate = const Value.absent(),
    required int taskId,
    required int tagId,
  })  : createdDate = Value(createdDate),
        taskId = Value(taskId),
        tagId = Value(tagId);
  static Insertable<TaskTag> custom({
    Expression<int>? id,
    Expression<DateTime>? createdDate,
    Expression<DateTime>? modifiedDate,
    Expression<int>? taskId,
    Expression<int>? tagId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdDate != null) 'created_date': createdDate,
      if (modifiedDate != null) 'modified_date': modifiedDate,
      if (taskId != null) 'task_id': taskId,
      if (tagId != null) 'tag_id': tagId,
    });
  }

  TaskTagTableCompanion copyWith(
      {Value<int>? id,
      Value<DateTime>? createdDate,
      Value<DateTime?>? modifiedDate,
      Value<int>? taskId,
      Value<int>? tagId}) {
    return TaskTagTableCompanion(
      id: id ?? this.id,
      createdDate: createdDate ?? this.createdDate,
      modifiedDate: modifiedDate ?? this.modifiedDate,
      taskId: taskId ?? this.taskId,
      tagId: tagId ?? this.tagId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (createdDate.present) {
      map['created_date'] = Variable<DateTime>(createdDate.value);
    }
    if (modifiedDate.present) {
      map['modified_date'] = Variable<DateTime>(modifiedDate.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<int>(taskId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<int>(tagId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaskTagTableCompanion(')
          ..write('id: $id, ')
          ..write('createdDate: $createdDate, ')
          ..write('modifiedDate: $modifiedDate, ')
          ..write('taskId: $taskId, ')
          ..write('tagId: $tagId')
          ..write(')'))
        .toString();
  }
}

class $TagTableTable extends TagTable with TableInfo<$TagTableTable, Tag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>('id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _createdDateMeta = const VerificationMeta('createdDate');
  @override
  late final GeneratedColumn<DateTime> createdDate = GeneratedColumn<DateTime>('created_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _modifiedDateMeta = const VerificationMeta('modifiedDate');
  @override
  late final GeneratedColumn<DateTime> modifiedDate = GeneratedColumn<DateTime>('modified_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name =
      GeneratedColumn<String>('name', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, createdDate, modifiedDate, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tag_table';
  @override
  VerificationContext validateIntegrity(Insertable<Tag> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_date')) {
      context.handle(_createdDateMeta, createdDate.isAcceptableOrUnknown(data['created_date']!, _createdDateMeta));
    } else if (isInserting) {
      context.missing(_createdDateMeta);
    }
    if (data.containsKey('modified_date')) {
      context.handle(_modifiedDateMeta, modifiedDate.isAcceptableOrUnknown(data['modified_date']!, _modifiedDateMeta));
    }
    if (data.containsKey('name')) {
      context.handle(_nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Tag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Tag(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      createdDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_date'])!,
      modifiedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}modified_date']),
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!,
    );
  }

  @override
  $TagTableTable createAlias(String alias) {
    return $TagTableTable(attachedDatabase, alias);
  }
}

class TagTableCompanion extends UpdateCompanion<Tag> {
  final Value<int> id;
  final Value<DateTime> createdDate;
  final Value<DateTime?> modifiedDate;
  final Value<String> name;
  const TagTableCompanion({
    this.id = const Value.absent(),
    this.createdDate = const Value.absent(),
    this.modifiedDate = const Value.absent(),
    this.name = const Value.absent(),
  });
  TagTableCompanion.insert({
    this.id = const Value.absent(),
    required DateTime createdDate,
    this.modifiedDate = const Value.absent(),
    required String name,
  })  : createdDate = Value(createdDate),
        name = Value(name);
  static Insertable<Tag> custom({
    Expression<int>? id,
    Expression<DateTime>? createdDate,
    Expression<DateTime>? modifiedDate,
    Expression<String>? name,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdDate != null) 'created_date': createdDate,
      if (modifiedDate != null) 'modified_date': modifiedDate,
      if (name != null) 'name': name,
    });
  }

  TagTableCompanion copyWith(
      {Value<int>? id, Value<DateTime>? createdDate, Value<DateTime?>? modifiedDate, Value<String>? name}) {
    return TagTableCompanion(
      id: id ?? this.id,
      createdDate: createdDate ?? this.createdDate,
      modifiedDate: modifiedDate ?? this.modifiedDate,
      name: name ?? this.name,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (createdDate.present) {
      map['created_date'] = Variable<DateTime>(createdDate.value);
    }
    if (modifiedDate.present) {
      map['modified_date'] = Variable<DateTime>(modifiedDate.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagTableCompanion(')
          ..write('id: $id, ')
          ..write('createdDate: $createdDate, ')
          ..write('modifiedDate: $modifiedDate, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }
}

class $TagTagTableTable extends TagTagTable with TableInfo<$TagTagTableTable, TagTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagTagTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>('id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _createdDateMeta = const VerificationMeta('createdDate');
  @override
  late final GeneratedColumn<DateTime> createdDate = GeneratedColumn<DateTime>('created_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _modifiedDateMeta = const VerificationMeta('modifiedDate');
  @override
  late final GeneratedColumn<DateTime> modifiedDate = GeneratedColumn<DateTime>('modified_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _primaryTagIdMeta = const VerificationMeta('primaryTagId');
  @override
  late final GeneratedColumn<int> primaryTagId =
      GeneratedColumn<int>('primary_tag_id', aliasedName, false, type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _secondaryTagIdMeta = const VerificationMeta('secondaryTagId');
  @override
  late final GeneratedColumn<int> secondaryTagId =
      GeneratedColumn<int>('secondary_tag_id', aliasedName, false, type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, createdDate, modifiedDate, primaryTagId, secondaryTagId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tag_tag_table';
  @override
  VerificationContext validateIntegrity(Insertable<TagTag> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_date')) {
      context.handle(_createdDateMeta, createdDate.isAcceptableOrUnknown(data['created_date']!, _createdDateMeta));
    } else if (isInserting) {
      context.missing(_createdDateMeta);
    }
    if (data.containsKey('modified_date')) {
      context.handle(_modifiedDateMeta, modifiedDate.isAcceptableOrUnknown(data['modified_date']!, _modifiedDateMeta));
    }
    if (data.containsKey('primary_tag_id')) {
      context.handle(_primaryTagIdMeta, primaryTagId.isAcceptableOrUnknown(data['primary_tag_id']!, _primaryTagIdMeta));
    } else if (isInserting) {
      context.missing(_primaryTagIdMeta);
    }
    if (data.containsKey('secondary_tag_id')) {
      context.handle(
          _secondaryTagIdMeta, secondaryTagId.isAcceptableOrUnknown(data['secondary_tag_id']!, _secondaryTagIdMeta));
    } else if (isInserting) {
      context.missing(_secondaryTagIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TagTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TagTag(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      createdDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_date'])!,
      modifiedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}modified_date']),
      primaryTagId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}primary_tag_id'])!,
      secondaryTagId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}secondary_tag_id'])!,
    );
  }

  @override
  $TagTagTableTable createAlias(String alias) {
    return $TagTagTableTable(attachedDatabase, alias);
  }
}

class TagTagTableCompanion extends UpdateCompanion<TagTag> {
  final Value<int> id;
  final Value<DateTime> createdDate;
  final Value<DateTime?> modifiedDate;
  final Value<int> primaryTagId;
  final Value<int> secondaryTagId;
  const TagTagTableCompanion({
    this.id = const Value.absent(),
    this.createdDate = const Value.absent(),
    this.modifiedDate = const Value.absent(),
    this.primaryTagId = const Value.absent(),
    this.secondaryTagId = const Value.absent(),
  });
  TagTagTableCompanion.insert({
    this.id = const Value.absent(),
    required DateTime createdDate,
    this.modifiedDate = const Value.absent(),
    required int primaryTagId,
    required int secondaryTagId,
  })  : createdDate = Value(createdDate),
        primaryTagId = Value(primaryTagId),
        secondaryTagId = Value(secondaryTagId);
  static Insertable<TagTag> custom({
    Expression<int>? id,
    Expression<DateTime>? createdDate,
    Expression<DateTime>? modifiedDate,
    Expression<int>? primaryTagId,
    Expression<int>? secondaryTagId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdDate != null) 'created_date': createdDate,
      if (modifiedDate != null) 'modified_date': modifiedDate,
      if (primaryTagId != null) 'primary_tag_id': primaryTagId,
      if (secondaryTagId != null) 'secondary_tag_id': secondaryTagId,
    });
  }

  TagTagTableCompanion copyWith(
      {Value<int>? id,
      Value<DateTime>? createdDate,
      Value<DateTime?>? modifiedDate,
      Value<int>? primaryTagId,
      Value<int>? secondaryTagId}) {
    return TagTagTableCompanion(
      id: id ?? this.id,
      createdDate: createdDate ?? this.createdDate,
      modifiedDate: modifiedDate ?? this.modifiedDate,
      primaryTagId: primaryTagId ?? this.primaryTagId,
      secondaryTagId: secondaryTagId ?? this.secondaryTagId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (createdDate.present) {
      map['created_date'] = Variable<DateTime>(createdDate.value);
    }
    if (modifiedDate.present) {
      map['modified_date'] = Variable<DateTime>(modifiedDate.value);
    }
    if (primaryTagId.present) {
      map['primary_tag_id'] = Variable<int>(primaryTagId.value);
    }
    if (secondaryTagId.present) {
      map['secondary_tag_id'] = Variable<int>(secondaryTagId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagTagTableCompanion(')
          ..write('id: $id, ')
          ..write('createdDate: $createdDate, ')
          ..write('modifiedDate: $modifiedDate, ')
          ..write('primaryTagId: $primaryTagId, ')
          ..write('secondaryTagId: $secondaryTagId')
          ..write(')'))
        .toString();
  }
}

class $SettingTableTable extends SettingTable with TableInfo<$SettingTableTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>('id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _createdDateMeta = const VerificationMeta('createdDate');
  @override
  late final GeneratedColumn<DateTime> createdDate = GeneratedColumn<DateTime>('created_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _modifiedDateMeta = const VerificationMeta('modifiedDate');
  @override
  late final GeneratedColumn<DateTime> modifiedDate = GeneratedColumn<DateTime>('modified_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key =
      GeneratedColumn<String>('key', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value =
      GeneratedColumn<String>('value', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueTypeMeta = const VerificationMeta('valueType');
  @override
  late final GeneratedColumnWithTypeConverter<SettingValueType, int> valueType =
      GeneratedColumn<int>('value_type', aliasedName, false, type: DriftSqlType.int, requiredDuringInsert: true)
          .withConverter<SettingValueType>($SettingTableTable.$convertervalueType);
  @override
  List<GeneratedColumn> get $columns => [id, createdDate, modifiedDate, key, value, valueType];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'setting_table';
  @override
  VerificationContext validateIntegrity(Insertable<Setting> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_date')) {
      context.handle(_createdDateMeta, createdDate.isAcceptableOrUnknown(data['created_date']!, _createdDateMeta));
    } else if (isInserting) {
      context.missing(_createdDateMeta);
    }
    if (data.containsKey('modified_date')) {
      context.handle(_modifiedDateMeta, modifiedDate.isAcceptableOrUnknown(data['modified_date']!, _modifiedDateMeta));
    }
    if (data.containsKey('key')) {
      context.handle(_keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(_valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    context.handle(_valueTypeMeta, const VerificationResult.success());
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      createdDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_date'])!,
      modifiedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}modified_date']),
      key: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}value'])!,
      valueType: $SettingTableTable.$convertervalueType
          .fromSql(attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}value_type'])!),
    );
  }

  @override
  $SettingTableTable createAlias(String alias) {
    return $SettingTableTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<SettingValueType, int, int> $convertervalueType =
      const EnumIndexConverter<SettingValueType>(SettingValueType.values);
}

class SettingTableCompanion extends UpdateCompanion<Setting> {
  final Value<int> id;
  final Value<DateTime> createdDate;
  final Value<DateTime?> modifiedDate;
  final Value<String> key;
  final Value<String> value;
  final Value<SettingValueType> valueType;
  const SettingTableCompanion({
    this.id = const Value.absent(),
    this.createdDate = const Value.absent(),
    this.modifiedDate = const Value.absent(),
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.valueType = const Value.absent(),
  });
  SettingTableCompanion.insert({
    this.id = const Value.absent(),
    required DateTime createdDate,
    this.modifiedDate = const Value.absent(),
    required String key,
    required String value,
    required SettingValueType valueType,
  })  : createdDate = Value(createdDate),
        key = Value(key),
        value = Value(value),
        valueType = Value(valueType);
  static Insertable<Setting> custom({
    Expression<int>? id,
    Expression<DateTime>? createdDate,
    Expression<DateTime>? modifiedDate,
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? valueType,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdDate != null) 'created_date': createdDate,
      if (modifiedDate != null) 'modified_date': modifiedDate,
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (valueType != null) 'value_type': valueType,
    });
  }

  SettingTableCompanion copyWith(
      {Value<int>? id,
      Value<DateTime>? createdDate,
      Value<DateTime?>? modifiedDate,
      Value<String>? key,
      Value<String>? value,
      Value<SettingValueType>? valueType}) {
    return SettingTableCompanion(
      id: id ?? this.id,
      createdDate: createdDate ?? this.createdDate,
      modifiedDate: modifiedDate ?? this.modifiedDate,
      key: key ?? this.key,
      value: value ?? this.value,
      valueType: valueType ?? this.valueType,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (createdDate.present) {
      map['created_date'] = Variable<DateTime>(createdDate.value);
    }
    if (modifiedDate.present) {
      map['modified_date'] = Variable<DateTime>(modifiedDate.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (valueType.present) {
      map['value_type'] = Variable<int>($SettingTableTable.$convertervalueType.toSql(valueType.value));
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingTableCompanion(')
          ..write('id: $id, ')
          ..write('createdDate: $createdDate, ')
          ..write('modifiedDate: $modifiedDate, ')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('valueType: $valueType')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AppUsageTableTable appUsageTable = $AppUsageTableTable(this);
  late final $AppUsageTagTableTable appUsageTagTable = $AppUsageTagTableTable(this);
  late final $HabitTableTable habitTable = $HabitTableTable(this);
  late final $HabitRecordTableTable habitRecordTable = $HabitRecordTableTable(this);
  late final $TaskTableTable taskTable = $TaskTableTable(this);
  late final $TaskTagTableTable taskTagTable = $TaskTagTableTable(this);
  late final $TagTableTable tagTable = $TagTableTable(this);
  late final $TagTagTableTable tagTagTable = $TagTagTableTable(this);
  late final $SettingTableTable settingTable = $SettingTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        appUsageTable,
        appUsageTagTable,
        habitTable,
        habitRecordTable,
        taskTable,
        taskTagTable,
        tagTable,
        tagTagTable,
        settingTable
      ];
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

class $$AppUsageTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AppUsageTableTable,
    AppUsage,
    $$AppUsageTableTableFilterComposer,
    $$AppUsageTableTableOrderingComposer,
    $$AppUsageTableTableCreateCompanionBuilder,
    $$AppUsageTableTableUpdateCompanionBuilder,
    (AppUsage, BaseReferences<_$AppDatabase, $AppUsageTableTable, AppUsage>),
    AppUsage,
    PrefetchHooks Function()> {
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
          withReferenceMapper: (p0) => p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AppUsageTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AppUsageTableTable,
    AppUsage,
    $$AppUsageTableTableFilterComposer,
    $$AppUsageTableTableOrderingComposer,
    $$AppUsageTableTableCreateCompanionBuilder,
    $$AppUsageTableTableUpdateCompanionBuilder,
    (AppUsage, BaseReferences<_$AppDatabase, $AppUsageTableTable, AppUsage>),
    AppUsage,
    PrefetchHooks Function()>;
typedef $$AppUsageTagTableTableCreateCompanionBuilder = AppUsageTagTableCompanion Function({
  required String id,
  required DateTime createdDate,
  Value<DateTime?> modifiedDate,
  required String appUsageId,
  required int tagId,
  Value<int> rowid,
});
typedef $$AppUsageTagTableTableUpdateCompanionBuilder = AppUsageTagTableCompanion Function({
  Value<String> id,
  Value<DateTime> createdDate,
  Value<DateTime?> modifiedDate,
  Value<String> appUsageId,
  Value<int> tagId,
  Value<int> rowid,
});

class $$AppUsageTagTableTableFilterComposer extends FilterComposer<_$AppDatabase, $AppUsageTagTableTable> {
  $$AppUsageTagTableTableFilterComposer(super.$state);
  ColumnFilters<String> get id => $state.composableBuilder(
      column: $state.table.id, builder: (column, joinBuilders) => ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get createdDate => $state.composableBuilder(
      column: $state.table.createdDate,
      builder: (column, joinBuilders) => ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get modifiedDate => $state.composableBuilder(
      column: $state.table.modifiedDate,
      builder: (column, joinBuilders) => ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get appUsageId => $state.composableBuilder(
      column: $state.table.appUsageId,
      builder: (column, joinBuilders) => ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get tagId => $state.composableBuilder(
      column: $state.table.tagId, builder: (column, joinBuilders) => ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$AppUsageTagTableTableOrderingComposer extends OrderingComposer<_$AppDatabase, $AppUsageTagTableTable> {
  $$AppUsageTagTableTableOrderingComposer(super.$state);
  ColumnOrderings<String> get id => $state.composableBuilder(
      column: $state.table.id, builder: (column, joinBuilders) => ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get createdDate => $state.composableBuilder(
      column: $state.table.createdDate,
      builder: (column, joinBuilders) => ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get modifiedDate => $state.composableBuilder(
      column: $state.table.modifiedDate,
      builder: (column, joinBuilders) => ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get appUsageId => $state.composableBuilder(
      column: $state.table.appUsageId,
      builder: (column, joinBuilders) => ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get tagId => $state.composableBuilder(
      column: $state.table.tagId,
      builder: (column, joinBuilders) => ColumnOrderings(column, joinBuilders: joinBuilders));
}

class $$AppUsageTagTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AppUsageTagTableTable,
    AppUsageTag,
    $$AppUsageTagTableTableFilterComposer,
    $$AppUsageTagTableTableOrderingComposer,
    $$AppUsageTagTableTableCreateCompanionBuilder,
    $$AppUsageTagTableTableUpdateCompanionBuilder,
    (AppUsageTag, BaseReferences<_$AppDatabase, $AppUsageTagTableTable, AppUsageTag>),
    AppUsageTag,
    PrefetchHooks Function()> {
  $$AppUsageTagTableTableTableManager(_$AppDatabase db, $AppUsageTagTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer: $$AppUsageTagTableTableFilterComposer(ComposerState(db, table)),
          orderingComposer: $$AppUsageTagTableTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<DateTime> createdDate = const Value.absent(),
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<String> appUsageId = const Value.absent(),
            Value<int> tagId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppUsageTagTableCompanion(
            id: id,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            appUsageId: appUsageId,
            tagId: tagId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required DateTime createdDate,
            Value<DateTime?> modifiedDate = const Value.absent(),
            required String appUsageId,
            required int tagId,
            Value<int> rowid = const Value.absent(),
          }) =>
              AppUsageTagTableCompanion.insert(
            id: id,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            appUsageId: appUsageId,
            tagId: tagId,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AppUsageTagTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AppUsageTagTableTable,
    AppUsageTag,
    $$AppUsageTagTableTableFilterComposer,
    $$AppUsageTagTableTableOrderingComposer,
    $$AppUsageTagTableTableCreateCompanionBuilder,
    $$AppUsageTagTableTableUpdateCompanionBuilder,
    (AppUsageTag, BaseReferences<_$AppDatabase, $AppUsageTagTableTable, AppUsageTag>),
    AppUsageTag,
    PrefetchHooks Function()>;
typedef $$HabitTableTableCreateCompanionBuilder = HabitTableCompanion Function({
  Value<int> id,
  required DateTime createdDate,
  Value<DateTime?> modifiedDate,
  required String name,
  required String description,
});
typedef $$HabitTableTableUpdateCompanionBuilder = HabitTableCompanion Function({
  Value<int> id,
  Value<DateTime> createdDate,
  Value<DateTime?> modifiedDate,
  Value<String> name,
  Value<String> description,
});

class $$HabitTableTableFilterComposer extends FilterComposer<_$AppDatabase, $HabitTableTable> {
  $$HabitTableTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id, builder: (column, joinBuilders) => ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get createdDate => $state.composableBuilder(
      column: $state.table.createdDate,
      builder: (column, joinBuilders) => ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get modifiedDate => $state.composableBuilder(
      column: $state.table.modifiedDate,
      builder: (column, joinBuilders) => ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get name => $state.composableBuilder(
      column: $state.table.name, builder: (column, joinBuilders) => ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get description => $state.composableBuilder(
      column: $state.table.description,
      builder: (column, joinBuilders) => ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$HabitTableTableOrderingComposer extends OrderingComposer<_$AppDatabase, $HabitTableTable> {
  $$HabitTableTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id, builder: (column, joinBuilders) => ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get createdDate => $state.composableBuilder(
      column: $state.table.createdDate,
      builder: (column, joinBuilders) => ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get modifiedDate => $state.composableBuilder(
      column: $state.table.modifiedDate,
      builder: (column, joinBuilders) => ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) => ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get description => $state.composableBuilder(
      column: $state.table.description,
      builder: (column, joinBuilders) => ColumnOrderings(column, joinBuilders: joinBuilders));
}

class $$HabitTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $HabitTableTable,
    Habit,
    $$HabitTableTableFilterComposer,
    $$HabitTableTableOrderingComposer,
    $$HabitTableTableCreateCompanionBuilder,
    $$HabitTableTableUpdateCompanionBuilder,
    (Habit, BaseReferences<_$AppDatabase, $HabitTableTable, Habit>),
    Habit,
    PrefetchHooks Function()> {
  $$HabitTableTableTableManager(_$AppDatabase db, $HabitTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer: $$HabitTableTableFilterComposer(ComposerState(db, table)),
          orderingComposer: $$HabitTableTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<DateTime> createdDate = const Value.absent(),
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> description = const Value.absent(),
          }) =>
              HabitTableCompanion(
            id: id,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            name: name,
            description: description,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required DateTime createdDate,
            Value<DateTime?> modifiedDate = const Value.absent(),
            required String name,
            required String description,
          }) =>
              HabitTableCompanion.insert(
            id: id,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            name: name,
            description: description,
          ),
          withReferenceMapper: (p0) => p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$HabitTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $HabitTableTable,
    Habit,
    $$HabitTableTableFilterComposer,
    $$HabitTableTableOrderingComposer,
    $$HabitTableTableCreateCompanionBuilder,
    $$HabitTableTableUpdateCompanionBuilder,
    (Habit, BaseReferences<_$AppDatabase, $HabitTableTable, Habit>),
    Habit,
    PrefetchHooks Function()>;
typedef $$HabitRecordTableTableCreateCompanionBuilder = HabitRecordTableCompanion Function({
  required String id,
  required DateTime createdDate,
  Value<DateTime?> modifiedDate,
  required int habitId,
  required DateTime date,
  Value<int> rowid,
});
typedef $$HabitRecordTableTableUpdateCompanionBuilder = HabitRecordTableCompanion Function({
  Value<String> id,
  Value<DateTime> createdDate,
  Value<DateTime?> modifiedDate,
  Value<int> habitId,
  Value<DateTime> date,
  Value<int> rowid,
});

class $$HabitRecordTableTableFilterComposer extends FilterComposer<_$AppDatabase, $HabitRecordTableTable> {
  $$HabitRecordTableTableFilterComposer(super.$state);
  ColumnFilters<String> get id => $state.composableBuilder(
      column: $state.table.id, builder: (column, joinBuilders) => ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get createdDate => $state.composableBuilder(
      column: $state.table.createdDate,
      builder: (column, joinBuilders) => ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get modifiedDate => $state.composableBuilder(
      column: $state.table.modifiedDate,
      builder: (column, joinBuilders) => ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get habitId => $state.composableBuilder(
      column: $state.table.habitId,
      builder: (column, joinBuilders) => ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get date => $state.composableBuilder(
      column: $state.table.date, builder: (column, joinBuilders) => ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$HabitRecordTableTableOrderingComposer extends OrderingComposer<_$AppDatabase, $HabitRecordTableTable> {
  $$HabitRecordTableTableOrderingComposer(super.$state);
  ColumnOrderings<String> get id => $state.composableBuilder(
      column: $state.table.id, builder: (column, joinBuilders) => ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get createdDate => $state.composableBuilder(
      column: $state.table.createdDate,
      builder: (column, joinBuilders) => ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get modifiedDate => $state.composableBuilder(
      column: $state.table.modifiedDate,
      builder: (column, joinBuilders) => ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get habitId => $state.composableBuilder(
      column: $state.table.habitId,
      builder: (column, joinBuilders) => ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get date => $state.composableBuilder(
      column: $state.table.date,
      builder: (column, joinBuilders) => ColumnOrderings(column, joinBuilders: joinBuilders));
}

class $$HabitRecordTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $HabitRecordTableTable,
    HabitRecord,
    $$HabitRecordTableTableFilterComposer,
    $$HabitRecordTableTableOrderingComposer,
    $$HabitRecordTableTableCreateCompanionBuilder,
    $$HabitRecordTableTableUpdateCompanionBuilder,
    (HabitRecord, BaseReferences<_$AppDatabase, $HabitRecordTableTable, HabitRecord>),
    HabitRecord,
    PrefetchHooks Function()> {
  $$HabitRecordTableTableTableManager(_$AppDatabase db, $HabitRecordTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer: $$HabitRecordTableTableFilterComposer(ComposerState(db, table)),
          orderingComposer: $$HabitRecordTableTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<DateTime> createdDate = const Value.absent(),
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<int> habitId = const Value.absent(),
            Value<DateTime> date = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              HabitRecordTableCompanion(
            id: id,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            habitId: habitId,
            date: date,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required DateTime createdDate,
            Value<DateTime?> modifiedDate = const Value.absent(),
            required int habitId,
            required DateTime date,
            Value<int> rowid = const Value.absent(),
          }) =>
              HabitRecordTableCompanion.insert(
            id: id,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            habitId: habitId,
            date: date,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$HabitRecordTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $HabitRecordTableTable,
    HabitRecord,
    $$HabitRecordTableTableFilterComposer,
    $$HabitRecordTableTableOrderingComposer,
    $$HabitRecordTableTableCreateCompanionBuilder,
    $$HabitRecordTableTableUpdateCompanionBuilder,
    (HabitRecord, BaseReferences<_$AppDatabase, $HabitRecordTableTable, HabitRecord>),
    HabitRecord,
    PrefetchHooks Function()>;
typedef $$TaskTableTableCreateCompanionBuilder = TaskTableCompanion Function({
  Value<int> id,
  required DateTime createdDate,
  Value<DateTime?> modifiedDate,
  required String title,
  Value<String?> description,
  Value<EisenhowerPriority?> priority,
  Value<DateTime?> plannedDate,
  Value<DateTime?> deadlineDate,
  Value<int?> estimatedTime,
  Value<int?> elapsedTime,
  Value<bool> isCompleted,
});
typedef $$TaskTableTableUpdateCompanionBuilder = TaskTableCompanion Function({
  Value<int> id,
  Value<DateTime> createdDate,
  Value<DateTime?> modifiedDate,
  Value<String> title,
  Value<String?> description,
  Value<EisenhowerPriority?> priority,
  Value<DateTime?> plannedDate,
  Value<DateTime?> deadlineDate,
  Value<int?> estimatedTime,
  Value<int?> elapsedTime,
  Value<bool> isCompleted,
});

class $$TaskTableTableFilterComposer extends FilterComposer<_$AppDatabase, $TaskTableTable> {
  $$TaskTableTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id, builder: (column, joinBuilders) => ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get createdDate => $state.composableBuilder(
      column: $state.table.createdDate,
      builder: (column, joinBuilders) => ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get modifiedDate => $state.composableBuilder(
      column: $state.table.modifiedDate,
      builder: (column, joinBuilders) => ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get title => $state.composableBuilder(
      column: $state.table.title, builder: (column, joinBuilders) => ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get description => $state.composableBuilder(
      column: $state.table.description,
      builder: (column, joinBuilders) => ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnWithTypeConverterFilters<EisenhowerPriority?, EisenhowerPriority, int> get priority => $state.composableBuilder(
      column: $state.table.priority,
      builder: (column, joinBuilders) => ColumnWithTypeConverterFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get plannedDate => $state.composableBuilder(
      column: $state.table.plannedDate,
      builder: (column, joinBuilders) => ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get deadlineDate => $state.composableBuilder(
      column: $state.table.deadlineDate,
      builder: (column, joinBuilders) => ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get estimatedTime => $state.composableBuilder(
      column: $state.table.estimatedTime,
      builder: (column, joinBuilders) => ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get elapsedTime => $state.composableBuilder(
      column: $state.table.elapsedTime,
      builder: (column, joinBuilders) => ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get isCompleted => $state.composableBuilder(
      column: $state.table.isCompleted,
      builder: (column, joinBuilders) => ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$TaskTableTableOrderingComposer extends OrderingComposer<_$AppDatabase, $TaskTableTable> {
  $$TaskTableTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
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

  ColumnOrderings<String> get description => $state.composableBuilder(
      column: $state.table.description,
      builder: (column, joinBuilders) => ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get priority => $state.composableBuilder(
      column: $state.table.priority,
      builder: (column, joinBuilders) => ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get plannedDate => $state.composableBuilder(
      column: $state.table.plannedDate,
      builder: (column, joinBuilders) => ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get deadlineDate => $state.composableBuilder(
      column: $state.table.deadlineDate,
      builder: (column, joinBuilders) => ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get estimatedTime => $state.composableBuilder(
      column: $state.table.estimatedTime,
      builder: (column, joinBuilders) => ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get elapsedTime => $state.composableBuilder(
      column: $state.table.elapsedTime,
      builder: (column, joinBuilders) => ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get isCompleted => $state.composableBuilder(
      column: $state.table.isCompleted,
      builder: (column, joinBuilders) => ColumnOrderings(column, joinBuilders: joinBuilders));
}

class $$TaskTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TaskTableTable,
    Task,
    $$TaskTableTableFilterComposer,
    $$TaskTableTableOrderingComposer,
    $$TaskTableTableCreateCompanionBuilder,
    $$TaskTableTableUpdateCompanionBuilder,
    (Task, BaseReferences<_$AppDatabase, $TaskTableTable, Task>),
    Task,
    PrefetchHooks Function()> {
  $$TaskTableTableTableManager(_$AppDatabase db, $TaskTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer: $$TaskTableTableFilterComposer(ComposerState(db, table)),
          orderingComposer: $$TaskTableTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<DateTime> createdDate = const Value.absent(),
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<EisenhowerPriority?> priority = const Value.absent(),
            Value<DateTime?> plannedDate = const Value.absent(),
            Value<DateTime?> deadlineDate = const Value.absent(),
            Value<int?> estimatedTime = const Value.absent(),
            Value<int?> elapsedTime = const Value.absent(),
            Value<bool> isCompleted = const Value.absent(),
          }) =>
              TaskTableCompanion(
            id: id,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            title: title,
            description: description,
            priority: priority,
            plannedDate: plannedDate,
            deadlineDate: deadlineDate,
            estimatedTime: estimatedTime,
            elapsedTime: elapsedTime,
            isCompleted: isCompleted,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required DateTime createdDate,
            Value<DateTime?> modifiedDate = const Value.absent(),
            required String title,
            Value<String?> description = const Value.absent(),
            Value<EisenhowerPriority?> priority = const Value.absent(),
            Value<DateTime?> plannedDate = const Value.absent(),
            Value<DateTime?> deadlineDate = const Value.absent(),
            Value<int?> estimatedTime = const Value.absent(),
            Value<int?> elapsedTime = const Value.absent(),
            Value<bool> isCompleted = const Value.absent(),
          }) =>
              TaskTableCompanion.insert(
            id: id,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            title: title,
            description: description,
            priority: priority,
            plannedDate: plannedDate,
            deadlineDate: deadlineDate,
            estimatedTime: estimatedTime,
            elapsedTime: elapsedTime,
            isCompleted: isCompleted,
          ),
          withReferenceMapper: (p0) => p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TaskTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TaskTableTable,
    Task,
    $$TaskTableTableFilterComposer,
    $$TaskTableTableOrderingComposer,
    $$TaskTableTableCreateCompanionBuilder,
    $$TaskTableTableUpdateCompanionBuilder,
    (Task, BaseReferences<_$AppDatabase, $TaskTableTable, Task>),
    Task,
    PrefetchHooks Function()>;
typedef $$TaskTagTableTableCreateCompanionBuilder = TaskTagTableCompanion Function({
  Value<int> id,
  required DateTime createdDate,
  Value<DateTime?> modifiedDate,
  required int taskId,
  required int tagId,
});
typedef $$TaskTagTableTableUpdateCompanionBuilder = TaskTagTableCompanion Function({
  Value<int> id,
  Value<DateTime> createdDate,
  Value<DateTime?> modifiedDate,
  Value<int> taskId,
  Value<int> tagId,
});

class $$TaskTagTableTableFilterComposer extends FilterComposer<_$AppDatabase, $TaskTagTableTable> {
  $$TaskTagTableTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id, builder: (column, joinBuilders) => ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get createdDate => $state.composableBuilder(
      column: $state.table.createdDate,
      builder: (column, joinBuilders) => ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get modifiedDate => $state.composableBuilder(
      column: $state.table.modifiedDate,
      builder: (column, joinBuilders) => ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get taskId => $state.composableBuilder(
      column: $state.table.taskId,
      builder: (column, joinBuilders) => ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get tagId => $state.composableBuilder(
      column: $state.table.tagId, builder: (column, joinBuilders) => ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$TaskTagTableTableOrderingComposer extends OrderingComposer<_$AppDatabase, $TaskTagTableTable> {
  $$TaskTagTableTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id, builder: (column, joinBuilders) => ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get createdDate => $state.composableBuilder(
      column: $state.table.createdDate,
      builder: (column, joinBuilders) => ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get modifiedDate => $state.composableBuilder(
      column: $state.table.modifiedDate,
      builder: (column, joinBuilders) => ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get taskId => $state.composableBuilder(
      column: $state.table.taskId,
      builder: (column, joinBuilders) => ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get tagId => $state.composableBuilder(
      column: $state.table.tagId,
      builder: (column, joinBuilders) => ColumnOrderings(column, joinBuilders: joinBuilders));
}

class $$TaskTagTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TaskTagTableTable,
    TaskTag,
    $$TaskTagTableTableFilterComposer,
    $$TaskTagTableTableOrderingComposer,
    $$TaskTagTableTableCreateCompanionBuilder,
    $$TaskTagTableTableUpdateCompanionBuilder,
    (TaskTag, BaseReferences<_$AppDatabase, $TaskTagTableTable, TaskTag>),
    TaskTag,
    PrefetchHooks Function()> {
  $$TaskTagTableTableTableManager(_$AppDatabase db, $TaskTagTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer: $$TaskTagTableTableFilterComposer(ComposerState(db, table)),
          orderingComposer: $$TaskTagTableTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<DateTime> createdDate = const Value.absent(),
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<int> taskId = const Value.absent(),
            Value<int> tagId = const Value.absent(),
          }) =>
              TaskTagTableCompanion(
            id: id,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            taskId: taskId,
            tagId: tagId,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required DateTime createdDate,
            Value<DateTime?> modifiedDate = const Value.absent(),
            required int taskId,
            required int tagId,
          }) =>
              TaskTagTableCompanion.insert(
            id: id,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            taskId: taskId,
            tagId: tagId,
          ),
          withReferenceMapper: (p0) => p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TaskTagTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TaskTagTableTable,
    TaskTag,
    $$TaskTagTableTableFilterComposer,
    $$TaskTagTableTableOrderingComposer,
    $$TaskTagTableTableCreateCompanionBuilder,
    $$TaskTagTableTableUpdateCompanionBuilder,
    (TaskTag, BaseReferences<_$AppDatabase, $TaskTagTableTable, TaskTag>),
    TaskTag,
    PrefetchHooks Function()>;
typedef $$TagTableTableCreateCompanionBuilder = TagTableCompanion Function({
  Value<int> id,
  required DateTime createdDate,
  Value<DateTime?> modifiedDate,
  required String name,
});
typedef $$TagTableTableUpdateCompanionBuilder = TagTableCompanion Function({
  Value<int> id,
  Value<DateTime> createdDate,
  Value<DateTime?> modifiedDate,
  Value<String> name,
});

class $$TagTableTableFilterComposer extends FilterComposer<_$AppDatabase, $TagTableTable> {
  $$TagTableTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id, builder: (column, joinBuilders) => ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get createdDate => $state.composableBuilder(
      column: $state.table.createdDate,
      builder: (column, joinBuilders) => ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get modifiedDate => $state.composableBuilder(
      column: $state.table.modifiedDate,
      builder: (column, joinBuilders) => ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get name => $state.composableBuilder(
      column: $state.table.name, builder: (column, joinBuilders) => ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$TagTableTableOrderingComposer extends OrderingComposer<_$AppDatabase, $TagTableTable> {
  $$TagTableTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id, builder: (column, joinBuilders) => ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get createdDate => $state.composableBuilder(
      column: $state.table.createdDate,
      builder: (column, joinBuilders) => ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get modifiedDate => $state.composableBuilder(
      column: $state.table.modifiedDate,
      builder: (column, joinBuilders) => ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) => ColumnOrderings(column, joinBuilders: joinBuilders));
}

class $$TagTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TagTableTable,
    Tag,
    $$TagTableTableFilterComposer,
    $$TagTableTableOrderingComposer,
    $$TagTableTableCreateCompanionBuilder,
    $$TagTableTableUpdateCompanionBuilder,
    (Tag, BaseReferences<_$AppDatabase, $TagTableTable, Tag>),
    Tag,
    PrefetchHooks Function()> {
  $$TagTableTableTableManager(_$AppDatabase db, $TagTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer: $$TagTableTableFilterComposer(ComposerState(db, table)),
          orderingComposer: $$TagTableTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<DateTime> createdDate = const Value.absent(),
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<String> name = const Value.absent(),
          }) =>
              TagTableCompanion(
            id: id,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            name: name,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required DateTime createdDate,
            Value<DateTime?> modifiedDate = const Value.absent(),
            required String name,
          }) =>
              TagTableCompanion.insert(
            id: id,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            name: name,
          ),
          withReferenceMapper: (p0) => p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TagTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TagTableTable,
    Tag,
    $$TagTableTableFilterComposer,
    $$TagTableTableOrderingComposer,
    $$TagTableTableCreateCompanionBuilder,
    $$TagTableTableUpdateCompanionBuilder,
    (Tag, BaseReferences<_$AppDatabase, $TagTableTable, Tag>),
    Tag,
    PrefetchHooks Function()>;
typedef $$TagTagTableTableCreateCompanionBuilder = TagTagTableCompanion Function({
  Value<int> id,
  required DateTime createdDate,
  Value<DateTime?> modifiedDate,
  required int primaryTagId,
  required int secondaryTagId,
});
typedef $$TagTagTableTableUpdateCompanionBuilder = TagTagTableCompanion Function({
  Value<int> id,
  Value<DateTime> createdDate,
  Value<DateTime?> modifiedDate,
  Value<int> primaryTagId,
  Value<int> secondaryTagId,
});

class $$TagTagTableTableFilterComposer extends FilterComposer<_$AppDatabase, $TagTagTableTable> {
  $$TagTagTableTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id, builder: (column, joinBuilders) => ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get createdDate => $state.composableBuilder(
      column: $state.table.createdDate,
      builder: (column, joinBuilders) => ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get modifiedDate => $state.composableBuilder(
      column: $state.table.modifiedDate,
      builder: (column, joinBuilders) => ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get primaryTagId => $state.composableBuilder(
      column: $state.table.primaryTagId,
      builder: (column, joinBuilders) => ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get secondaryTagId => $state.composableBuilder(
      column: $state.table.secondaryTagId,
      builder: (column, joinBuilders) => ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$TagTagTableTableOrderingComposer extends OrderingComposer<_$AppDatabase, $TagTagTableTable> {
  $$TagTagTableTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id, builder: (column, joinBuilders) => ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get createdDate => $state.composableBuilder(
      column: $state.table.createdDate,
      builder: (column, joinBuilders) => ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get modifiedDate => $state.composableBuilder(
      column: $state.table.modifiedDate,
      builder: (column, joinBuilders) => ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get primaryTagId => $state.composableBuilder(
      column: $state.table.primaryTagId,
      builder: (column, joinBuilders) => ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get secondaryTagId => $state.composableBuilder(
      column: $state.table.secondaryTagId,
      builder: (column, joinBuilders) => ColumnOrderings(column, joinBuilders: joinBuilders));
}

class $$TagTagTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TagTagTableTable,
    TagTag,
    $$TagTagTableTableFilterComposer,
    $$TagTagTableTableOrderingComposer,
    $$TagTagTableTableCreateCompanionBuilder,
    $$TagTagTableTableUpdateCompanionBuilder,
    (TagTag, BaseReferences<_$AppDatabase, $TagTagTableTable, TagTag>),
    TagTag,
    PrefetchHooks Function()> {
  $$TagTagTableTableTableManager(_$AppDatabase db, $TagTagTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer: $$TagTagTableTableFilterComposer(ComposerState(db, table)),
          orderingComposer: $$TagTagTableTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<DateTime> createdDate = const Value.absent(),
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<int> primaryTagId = const Value.absent(),
            Value<int> secondaryTagId = const Value.absent(),
          }) =>
              TagTagTableCompanion(
            id: id,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            primaryTagId: primaryTagId,
            secondaryTagId: secondaryTagId,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required DateTime createdDate,
            Value<DateTime?> modifiedDate = const Value.absent(),
            required int primaryTagId,
            required int secondaryTagId,
          }) =>
              TagTagTableCompanion.insert(
            id: id,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            primaryTagId: primaryTagId,
            secondaryTagId: secondaryTagId,
          ),
          withReferenceMapper: (p0) => p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TagTagTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TagTagTableTable,
    TagTag,
    $$TagTagTableTableFilterComposer,
    $$TagTagTableTableOrderingComposer,
    $$TagTagTableTableCreateCompanionBuilder,
    $$TagTagTableTableUpdateCompanionBuilder,
    (TagTag, BaseReferences<_$AppDatabase, $TagTagTableTable, TagTag>),
    TagTag,
    PrefetchHooks Function()>;
typedef $$SettingTableTableCreateCompanionBuilder = SettingTableCompanion Function({
  Value<int> id,
  required DateTime createdDate,
  Value<DateTime?> modifiedDate,
  required String key,
  required String value,
  required SettingValueType valueType,
});
typedef $$SettingTableTableUpdateCompanionBuilder = SettingTableCompanion Function({
  Value<int> id,
  Value<DateTime> createdDate,
  Value<DateTime?> modifiedDate,
  Value<String> key,
  Value<String> value,
  Value<SettingValueType> valueType,
});

class $$SettingTableTableFilterComposer extends FilterComposer<_$AppDatabase, $SettingTableTable> {
  $$SettingTableTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id, builder: (column, joinBuilders) => ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get createdDate => $state.composableBuilder(
      column: $state.table.createdDate,
      builder: (column, joinBuilders) => ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get modifiedDate => $state.composableBuilder(
      column: $state.table.modifiedDate,
      builder: (column, joinBuilders) => ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get key => $state.composableBuilder(
      column: $state.table.key, builder: (column, joinBuilders) => ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get value => $state.composableBuilder(
      column: $state.table.value, builder: (column, joinBuilders) => ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnWithTypeConverterFilters<SettingValueType, SettingValueType, int> get valueType => $state.composableBuilder(
      column: $state.table.valueType,
      builder: (column, joinBuilders) => ColumnWithTypeConverterFilters(column, joinBuilders: joinBuilders));
}

class $$SettingTableTableOrderingComposer extends OrderingComposer<_$AppDatabase, $SettingTableTable> {
  $$SettingTableTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id, builder: (column, joinBuilders) => ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get createdDate => $state.composableBuilder(
      column: $state.table.createdDate,
      builder: (column, joinBuilders) => ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get modifiedDate => $state.composableBuilder(
      column: $state.table.modifiedDate,
      builder: (column, joinBuilders) => ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get key => $state.composableBuilder(
      column: $state.table.key, builder: (column, joinBuilders) => ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get value => $state.composableBuilder(
      column: $state.table.value,
      builder: (column, joinBuilders) => ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get valueType => $state.composableBuilder(
      column: $state.table.valueType,
      builder: (column, joinBuilders) => ColumnOrderings(column, joinBuilders: joinBuilders));
}

class $$SettingTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SettingTableTable,
    Setting,
    $$SettingTableTableFilterComposer,
    $$SettingTableTableOrderingComposer,
    $$SettingTableTableCreateCompanionBuilder,
    $$SettingTableTableUpdateCompanionBuilder,
    (Setting, BaseReferences<_$AppDatabase, $SettingTableTable, Setting>),
    Setting,
    PrefetchHooks Function()> {
  $$SettingTableTableTableManager(_$AppDatabase db, $SettingTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer: $$SettingTableTableFilterComposer(ComposerState(db, table)),
          orderingComposer: $$SettingTableTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<DateTime> createdDate = const Value.absent(),
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<SettingValueType> valueType = const Value.absent(),
          }) =>
              SettingTableCompanion(
            id: id,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            key: key,
            value: value,
            valueType: valueType,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required DateTime createdDate,
            Value<DateTime?> modifiedDate = const Value.absent(),
            required String key,
            required String value,
            required SettingValueType valueType,
          }) =>
              SettingTableCompanion.insert(
            id: id,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            key: key,
            value: value,
            valueType: valueType,
          ),
          withReferenceMapper: (p0) => p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SettingTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SettingTableTable,
    Setting,
    $$SettingTableTableFilterComposer,
    $$SettingTableTableOrderingComposer,
    $$SettingTableTableCreateCompanionBuilder,
    $$SettingTableTableUpdateCompanionBuilder,
    (Setting, BaseReferences<_$AppDatabase, $SettingTableTable, Setting>),
    Setting,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AppUsageTableTableTableManager get appUsageTable => $$AppUsageTableTableTableManager(_db, _db.appUsageTable);
  $$AppUsageTagTableTableTableManager get appUsageTagTable =>
      $$AppUsageTagTableTableTableManager(_db, _db.appUsageTagTable);
  $$HabitTableTableTableManager get habitTable => $$HabitTableTableTableManager(_db, _db.habitTable);
  $$HabitRecordTableTableTableManager get habitRecordTable =>
      $$HabitRecordTableTableTableManager(_db, _db.habitRecordTable);
  $$TaskTableTableTableManager get taskTable => $$TaskTableTableTableManager(_db, _db.taskTable);
  $$TaskTagTableTableTableManager get taskTagTable => $$TaskTagTableTableTableManager(_db, _db.taskTagTable);
  $$TagTableTableTableManager get tagTable => $$TagTableTableTableManager(_db, _db.tagTable);
  $$TagTagTableTableTableManager get tagTagTable => $$TagTagTableTableTableManager(_db, _db.tagTagTable);
  $$SettingTableTableTableManager get settingTable => $$SettingTableTableTableManager(_db, _db.settingTable);
}

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
  static const VerificationMeta _deletedDateMeta = const VerificationMeta('deletedDate');
  @override
  late final GeneratedColumn<DateTime> deletedDate = GeneratedColumn<DateTime>('deleted_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name =
      GeneratedColumn<String>('name', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _displayNameMeta = const VerificationMeta('displayName');
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>('display_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color =
      GeneratedColumn<String>('color', aliasedName, true, type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _durationMeta = const VerificationMeta('duration');
  @override
  late final GeneratedColumn<int> duration =
      GeneratedColumn<int>('duration', aliasedName, false, type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, createdDate, modifiedDate, deletedDate, name, displayName, color, duration];
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
    if (data.containsKey('deleted_date')) {
      context.handle(_deletedDateMeta, deletedDate.isAcceptableOrUnknown(data['deleted_date']!, _deletedDateMeta));
    }
    if (data.containsKey('name')) {
      context.handle(_nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(_displayNameMeta, displayName.isAcceptableOrUnknown(data['display_name']!, _displayNameMeta));
    }
    if (data.containsKey('color')) {
      context.handle(_colorMeta, color.isAcceptableOrUnknown(data['color']!, _colorMeta));
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
      deletedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_date']),
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      displayName: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}display_name']),
      duration: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}duration'])!,
      color: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}color']),
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
  final Value<DateTime?> deletedDate;
  final Value<String> name;
  final Value<String?> displayName;
  final Value<String?> color;
  final Value<int> duration;
  final Value<int> rowid;
  const AppUsageTableCompanion({
    this.id = const Value.absent(),
    this.createdDate = const Value.absent(),
    this.modifiedDate = const Value.absent(),
    this.deletedDate = const Value.absent(),
    this.name = const Value.absent(),
    this.displayName = const Value.absent(),
    this.color = const Value.absent(),
    this.duration = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppUsageTableCompanion.insert({
    required String id,
    required DateTime createdDate,
    this.modifiedDate = const Value.absent(),
    this.deletedDate = const Value.absent(),
    required String name,
    this.displayName = const Value.absent(),
    this.color = const Value.absent(),
    required int duration,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        createdDate = Value(createdDate),
        name = Value(name),
        duration = Value(duration);
  static Insertable<AppUsage> custom({
    Expression<String>? id,
    Expression<DateTime>? createdDate,
    Expression<DateTime>? modifiedDate,
    Expression<DateTime>? deletedDate,
    Expression<String>? name,
    Expression<String>? displayName,
    Expression<String>? color,
    Expression<int>? duration,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdDate != null) 'created_date': createdDate,
      if (modifiedDate != null) 'modified_date': modifiedDate,
      if (deletedDate != null) 'deleted_date': deletedDate,
      if (name != null) 'name': name,
      if (displayName != null) 'display_name': displayName,
      if (color != null) 'color': color,
      if (duration != null) 'duration': duration,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppUsageTableCompanion copyWith(
      {Value<String>? id,
      Value<DateTime>? createdDate,
      Value<DateTime?>? modifiedDate,
      Value<DateTime?>? deletedDate,
      Value<String>? name,
      Value<String?>? displayName,
      Value<String?>? color,
      Value<int>? duration,
      Value<int>? rowid}) {
    return AppUsageTableCompanion(
      id: id ?? this.id,
      createdDate: createdDate ?? this.createdDate,
      modifiedDate: modifiedDate ?? this.modifiedDate,
      deletedDate: deletedDate ?? this.deletedDate,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      color: color ?? this.color,
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
    if (deletedDate.present) {
      map['deleted_date'] = Variable<DateTime>(deletedDate.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
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
          ..write('deletedDate: $deletedDate, ')
          ..write('name: $name, ')
          ..write('displayName: $displayName, ')
          ..write('color: $color, ')
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
  static const VerificationMeta _deletedDateMeta = const VerificationMeta('deletedDate');
  @override
  late final GeneratedColumn<DateTime> deletedDate = GeneratedColumn<DateTime>('deleted_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _appUsageIdMeta = const VerificationMeta('appUsageId');
  @override
  late final GeneratedColumn<String> appUsageId = GeneratedColumn<String>('app_usage_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<String> tagId =
      GeneratedColumn<String>('tag_id', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, createdDate, modifiedDate, deletedDate, appUsageId, tagId];
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
    if (data.containsKey('deleted_date')) {
      context.handle(_deletedDateMeta, deletedDate.isAcceptableOrUnknown(data['deleted_date']!, _deletedDateMeta));
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
      deletedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_date']),
      appUsageId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}app_usage_id'])!,
      tagId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}tag_id'])!,
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
  final Value<DateTime?> deletedDate;
  final Value<String> appUsageId;
  final Value<String> tagId;
  final Value<int> rowid;
  const AppUsageTagTableCompanion({
    this.id = const Value.absent(),
    this.createdDate = const Value.absent(),
    this.modifiedDate = const Value.absent(),
    this.deletedDate = const Value.absent(),
    this.appUsageId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppUsageTagTableCompanion.insert({
    required String id,
    required DateTime createdDate,
    this.modifiedDate = const Value.absent(),
    this.deletedDate = const Value.absent(),
    required String appUsageId,
    required String tagId,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        createdDate = Value(createdDate),
        appUsageId = Value(appUsageId),
        tagId = Value(tagId);
  static Insertable<AppUsageTag> custom({
    Expression<String>? id,
    Expression<DateTime>? createdDate,
    Expression<DateTime>? modifiedDate,
    Expression<DateTime>? deletedDate,
    Expression<String>? appUsageId,
    Expression<String>? tagId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdDate != null) 'created_date': createdDate,
      if (modifiedDate != null) 'modified_date': modifiedDate,
      if (deletedDate != null) 'deleted_date': deletedDate,
      if (appUsageId != null) 'app_usage_id': appUsageId,
      if (tagId != null) 'tag_id': tagId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppUsageTagTableCompanion copyWith(
      {Value<String>? id,
      Value<DateTime>? createdDate,
      Value<DateTime?>? modifiedDate,
      Value<DateTime?>? deletedDate,
      Value<String>? appUsageId,
      Value<String>? tagId,
      Value<int>? rowid}) {
    return AppUsageTagTableCompanion(
      id: id ?? this.id,
      createdDate: createdDate ?? this.createdDate,
      modifiedDate: modifiedDate ?? this.modifiedDate,
      deletedDate: deletedDate ?? this.deletedDate,
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
    if (deletedDate.present) {
      map['deleted_date'] = Variable<DateTime>(deletedDate.value);
    }
    if (appUsageId.present) {
      map['app_usage_id'] = Variable<String>(appUsageId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<String>(tagId.value);
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
          ..write('deletedDate: $deletedDate, ')
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
  static const VerificationMeta _deletedDateMeta = const VerificationMeta('deletedDate');
  @override
  late final GeneratedColumn<DateTime> deletedDate = GeneratedColumn<DateTime>('deleted_date', aliasedName, true,
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
  List<GeneratedColumn> get $columns => [id, createdDate, modifiedDate, deletedDate, name, description];
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
    if (data.containsKey('deleted_date')) {
      context.handle(_deletedDateMeta, deletedDate.isAcceptableOrUnknown(data['deleted_date']!, _deletedDateMeta));
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
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  Habit map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Habit(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      createdDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_date'])!,
      modifiedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}modified_date']),
      deletedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_date']),
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
  final Value<String> id;
  final Value<DateTime> createdDate;
  final Value<DateTime?> modifiedDate;
  final Value<DateTime?> deletedDate;
  final Value<String> name;
  final Value<String> description;
  final Value<int> rowid;
  const HabitTableCompanion({
    this.id = const Value.absent(),
    this.createdDate = const Value.absent(),
    this.modifiedDate = const Value.absent(),
    this.deletedDate = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HabitTableCompanion.insert({
    required String id,
    required DateTime createdDate,
    this.modifiedDate = const Value.absent(),
    this.deletedDate = const Value.absent(),
    required String name,
    required String description,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        createdDate = Value(createdDate),
        name = Value(name),
        description = Value(description);
  static Insertable<Habit> custom({
    Expression<String>? id,
    Expression<DateTime>? createdDate,
    Expression<DateTime>? modifiedDate,
    Expression<DateTime>? deletedDate,
    Expression<String>? name,
    Expression<String>? description,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdDate != null) 'created_date': createdDate,
      if (modifiedDate != null) 'modified_date': modifiedDate,
      if (deletedDate != null) 'deleted_date': deletedDate,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HabitTableCompanion copyWith(
      {Value<String>? id,
      Value<DateTime>? createdDate,
      Value<DateTime?>? modifiedDate,
      Value<DateTime?>? deletedDate,
      Value<String>? name,
      Value<String>? description,
      Value<int>? rowid}) {
    return HabitTableCompanion(
      id: id ?? this.id,
      createdDate: createdDate ?? this.createdDate,
      modifiedDate: modifiedDate ?? this.modifiedDate,
      deletedDate: deletedDate ?? this.deletedDate,
      name: name ?? this.name,
      description: description ?? this.description,
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
    if (deletedDate.present) {
      map['deleted_date'] = Variable<DateTime>(deletedDate.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HabitTableCompanion(')
          ..write('id: $id, ')
          ..write('createdDate: $createdDate, ')
          ..write('modifiedDate: $modifiedDate, ')
          ..write('deletedDate: $deletedDate, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HabitTagTableTable extends HabitTagTable with TableInfo<$HabitTagTableTable, HabitTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HabitTagTableTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _deletedDateMeta = const VerificationMeta('deletedDate');
  @override
  late final GeneratedColumn<DateTime> deletedDate = GeneratedColumn<DateTime>('deleted_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _habitIdMeta = const VerificationMeta('habitId');
  @override
  late final GeneratedColumn<String> habitId =
      GeneratedColumn<String>('habit_id', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<String> tagId =
      GeneratedColumn<String>('tag_id', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, createdDate, modifiedDate, deletedDate, habitId, tagId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'habit_tag_table';
  @override
  VerificationContext validateIntegrity(Insertable<HabitTag> instance, {bool isInserting = false}) {
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
    if (data.containsKey('deleted_date')) {
      context.handle(_deletedDateMeta, deletedDate.isAcceptableOrUnknown(data['deleted_date']!, _deletedDateMeta));
    }
    if (data.containsKey('habit_id')) {
      context.handle(_habitIdMeta, habitId.isAcceptableOrUnknown(data['habit_id']!, _habitIdMeta));
    } else if (isInserting) {
      context.missing(_habitIdMeta);
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
  HabitTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HabitTag(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      createdDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_date'])!,
      modifiedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}modified_date']),
      deletedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_date']),
      habitId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}habit_id'])!,
      tagId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}tag_id'])!,
    );
  }

  @override
  $HabitTagTableTable createAlias(String alias) {
    return $HabitTagTableTable(attachedDatabase, alias);
  }
}

class HabitTagTableCompanion extends UpdateCompanion<HabitTag> {
  final Value<String> id;
  final Value<DateTime> createdDate;
  final Value<DateTime?> modifiedDate;
  final Value<DateTime?> deletedDate;
  final Value<String> habitId;
  final Value<String> tagId;
  final Value<int> rowid;
  const HabitTagTableCompanion({
    this.id = const Value.absent(),
    this.createdDate = const Value.absent(),
    this.modifiedDate = const Value.absent(),
    this.deletedDate = const Value.absent(),
    this.habitId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HabitTagTableCompanion.insert({
    required String id,
    required DateTime createdDate,
    this.modifiedDate = const Value.absent(),
    this.deletedDate = const Value.absent(),
    required String habitId,
    required String tagId,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        createdDate = Value(createdDate),
        habitId = Value(habitId),
        tagId = Value(tagId);
  static Insertable<HabitTag> custom({
    Expression<String>? id,
    Expression<DateTime>? createdDate,
    Expression<DateTime>? modifiedDate,
    Expression<DateTime>? deletedDate,
    Expression<String>? habitId,
    Expression<String>? tagId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdDate != null) 'created_date': createdDate,
      if (modifiedDate != null) 'modified_date': modifiedDate,
      if (deletedDate != null) 'deleted_date': deletedDate,
      if (habitId != null) 'habit_id': habitId,
      if (tagId != null) 'tag_id': tagId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HabitTagTableCompanion copyWith(
      {Value<String>? id,
      Value<DateTime>? createdDate,
      Value<DateTime?>? modifiedDate,
      Value<DateTime?>? deletedDate,
      Value<String>? habitId,
      Value<String>? tagId,
      Value<int>? rowid}) {
    return HabitTagTableCompanion(
      id: id ?? this.id,
      createdDate: createdDate ?? this.createdDate,
      modifiedDate: modifiedDate ?? this.modifiedDate,
      deletedDate: deletedDate ?? this.deletedDate,
      habitId: habitId ?? this.habitId,
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
    if (deletedDate.present) {
      map['deleted_date'] = Variable<DateTime>(deletedDate.value);
    }
    if (habitId.present) {
      map['habit_id'] = Variable<String>(habitId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<String>(tagId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HabitTagTableCompanion(')
          ..write('id: $id, ')
          ..write('createdDate: $createdDate, ')
          ..write('modifiedDate: $modifiedDate, ')
          ..write('deletedDate: $deletedDate, ')
          ..write('habitId: $habitId, ')
          ..write('tagId: $tagId, ')
          ..write('rowid: $rowid')
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
  static const VerificationMeta _deletedDateMeta = const VerificationMeta('deletedDate');
  @override
  late final GeneratedColumn<DateTime> deletedDate = GeneratedColumn<DateTime>('deleted_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _habitIdMeta = const VerificationMeta('habitId');
  @override
  late final GeneratedColumn<String> habitId =
      GeneratedColumn<String>('habit_id', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date =
      GeneratedColumn<DateTime>('date', aliasedName, false, type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, createdDate, modifiedDate, deletedDate, habitId, date];
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
    if (data.containsKey('deleted_date')) {
      context.handle(_deletedDateMeta, deletedDate.isAcceptableOrUnknown(data['deleted_date']!, _deletedDateMeta));
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
      deletedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_date']),
      habitId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}habit_id'])!,
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
  final Value<DateTime?> deletedDate;
  final Value<String> habitId;
  final Value<DateTime> date;
  final Value<int> rowid;
  const HabitRecordTableCompanion({
    this.id = const Value.absent(),
    this.createdDate = const Value.absent(),
    this.modifiedDate = const Value.absent(),
    this.deletedDate = const Value.absent(),
    this.habitId = const Value.absent(),
    this.date = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HabitRecordTableCompanion.insert({
    required String id,
    required DateTime createdDate,
    this.modifiedDate = const Value.absent(),
    this.deletedDate = const Value.absent(),
    required String habitId,
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
    Expression<DateTime>? deletedDate,
    Expression<String>? habitId,
    Expression<DateTime>? date,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdDate != null) 'created_date': createdDate,
      if (modifiedDate != null) 'modified_date': modifiedDate,
      if (deletedDate != null) 'deleted_date': deletedDate,
      if (habitId != null) 'habit_id': habitId,
      if (date != null) 'date': date,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HabitRecordTableCompanion copyWith(
      {Value<String>? id,
      Value<DateTime>? createdDate,
      Value<DateTime?>? modifiedDate,
      Value<DateTime?>? deletedDate,
      Value<String>? habitId,
      Value<DateTime>? date,
      Value<int>? rowid}) {
    return HabitRecordTableCompanion(
      id: id ?? this.id,
      createdDate: createdDate ?? this.createdDate,
      modifiedDate: modifiedDate ?? this.modifiedDate,
      deletedDate: deletedDate ?? this.deletedDate,
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
    if (deletedDate.present) {
      map['deleted_date'] = Variable<DateTime>(deletedDate.value);
    }
    if (habitId.present) {
      map['habit_id'] = Variable<String>(habitId.value);
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
          ..write('deletedDate: $deletedDate, ')
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
  static const VerificationMeta _deletedDateMeta = const VerificationMeta('deletedDate');
  @override
  late final GeneratedColumn<DateTime> deletedDate = GeneratedColumn<DateTime>('deleted_date', aliasedName, true,
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
        deletedDate,
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
    if (data.containsKey('deleted_date')) {
      context.handle(_deletedDateMeta, deletedDate.isAcceptableOrUnknown(data['deleted_date']!, _deletedDateMeta));
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
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  Task map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Task(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      createdDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_date'])!,
      modifiedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}modified_date']),
      deletedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_date']),
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
  final Value<String> id;
  final Value<DateTime> createdDate;
  final Value<DateTime?> modifiedDate;
  final Value<DateTime?> deletedDate;
  final Value<String> title;
  final Value<String?> description;
  final Value<EisenhowerPriority?> priority;
  final Value<DateTime?> plannedDate;
  final Value<DateTime?> deadlineDate;
  final Value<int?> estimatedTime;
  final Value<int?> elapsedTime;
  final Value<bool> isCompleted;
  final Value<int> rowid;
  const TaskTableCompanion({
    this.id = const Value.absent(),
    this.createdDate = const Value.absent(),
    this.modifiedDate = const Value.absent(),
    this.deletedDate = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.priority = const Value.absent(),
    this.plannedDate = const Value.absent(),
    this.deadlineDate = const Value.absent(),
    this.estimatedTime = const Value.absent(),
    this.elapsedTime = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TaskTableCompanion.insert({
    required String id,
    required DateTime createdDate,
    this.modifiedDate = const Value.absent(),
    this.deletedDate = const Value.absent(),
    required String title,
    this.description = const Value.absent(),
    this.priority = const Value.absent(),
    this.plannedDate = const Value.absent(),
    this.deadlineDate = const Value.absent(),
    this.estimatedTime = const Value.absent(),
    this.elapsedTime = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        createdDate = Value(createdDate),
        title = Value(title);
  static Insertable<Task> custom({
    Expression<String>? id,
    Expression<DateTime>? createdDate,
    Expression<DateTime>? modifiedDate,
    Expression<DateTime>? deletedDate,
    Expression<String>? title,
    Expression<String>? description,
    Expression<int>? priority,
    Expression<DateTime>? plannedDate,
    Expression<DateTime>? deadlineDate,
    Expression<int>? estimatedTime,
    Expression<int>? elapsedTime,
    Expression<bool>? isCompleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdDate != null) 'created_date': createdDate,
      if (modifiedDate != null) 'modified_date': modifiedDate,
      if (deletedDate != null) 'deleted_date': deletedDate,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (priority != null) 'priority': priority,
      if (plannedDate != null) 'planned_date': plannedDate,
      if (deadlineDate != null) 'deadline_date': deadlineDate,
      if (estimatedTime != null) 'estimated_time': estimatedTime,
      if (elapsedTime != null) 'elapsed_time': elapsedTime,
      if (isCompleted != null) 'is_completed': isCompleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TaskTableCompanion copyWith(
      {Value<String>? id,
      Value<DateTime>? createdDate,
      Value<DateTime?>? modifiedDate,
      Value<DateTime?>? deletedDate,
      Value<String>? title,
      Value<String?>? description,
      Value<EisenhowerPriority?>? priority,
      Value<DateTime?>? plannedDate,
      Value<DateTime?>? deadlineDate,
      Value<int?>? estimatedTime,
      Value<int?>? elapsedTime,
      Value<bool>? isCompleted,
      Value<int>? rowid}) {
    return TaskTableCompanion(
      id: id ?? this.id,
      createdDate: createdDate ?? this.createdDate,
      modifiedDate: modifiedDate ?? this.modifiedDate,
      deletedDate: deletedDate ?? this.deletedDate,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      plannedDate: plannedDate ?? this.plannedDate,
      deadlineDate: deadlineDate ?? this.deadlineDate,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      elapsedTime: elapsedTime ?? this.elapsedTime,
      isCompleted: isCompleted ?? this.isCompleted,
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
    if (deletedDate.present) {
      map['deleted_date'] = Variable<DateTime>(deletedDate.value);
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
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaskTableCompanion(')
          ..write('id: $id, ')
          ..write('createdDate: $createdDate, ')
          ..write('modifiedDate: $modifiedDate, ')
          ..write('deletedDate: $deletedDate, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('priority: $priority, ')
          ..write('plannedDate: $plannedDate, ')
          ..write('deadlineDate: $deadlineDate, ')
          ..write('estimatedTime: $estimatedTime, ')
          ..write('elapsedTime: $elapsedTime, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('rowid: $rowid')
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
  static const VerificationMeta _deletedDateMeta = const VerificationMeta('deletedDate');
  @override
  late final GeneratedColumn<DateTime> deletedDate = GeneratedColumn<DateTime>('deleted_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId =
      GeneratedColumn<String>('task_id', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<String> tagId =
      GeneratedColumn<String>('tag_id', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, createdDate, modifiedDate, deletedDate, taskId, tagId];
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
    if (data.containsKey('deleted_date')) {
      context.handle(_deletedDateMeta, deletedDate.isAcceptableOrUnknown(data['deleted_date']!, _deletedDateMeta));
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
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  TaskTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskTag(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      createdDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_date'])!,
      modifiedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}modified_date']),
      deletedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_date']),
      taskId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}task_id'])!,
      tagId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}tag_id'])!,
    );
  }

  @override
  $TaskTagTableTable createAlias(String alias) {
    return $TaskTagTableTable(attachedDatabase, alias);
  }
}

class TaskTagTableCompanion extends UpdateCompanion<TaskTag> {
  final Value<String> id;
  final Value<DateTime> createdDate;
  final Value<DateTime?> modifiedDate;
  final Value<DateTime?> deletedDate;
  final Value<String> taskId;
  final Value<String> tagId;
  final Value<int> rowid;
  const TaskTagTableCompanion({
    this.id = const Value.absent(),
    this.createdDate = const Value.absent(),
    this.modifiedDate = const Value.absent(),
    this.deletedDate = const Value.absent(),
    this.taskId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TaskTagTableCompanion.insert({
    required String id,
    required DateTime createdDate,
    this.modifiedDate = const Value.absent(),
    this.deletedDate = const Value.absent(),
    required String taskId,
    required String tagId,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        createdDate = Value(createdDate),
        taskId = Value(taskId),
        tagId = Value(tagId);
  static Insertable<TaskTag> custom({
    Expression<String>? id,
    Expression<DateTime>? createdDate,
    Expression<DateTime>? modifiedDate,
    Expression<DateTime>? deletedDate,
    Expression<String>? taskId,
    Expression<String>? tagId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdDate != null) 'created_date': createdDate,
      if (modifiedDate != null) 'modified_date': modifiedDate,
      if (deletedDate != null) 'deleted_date': deletedDate,
      if (taskId != null) 'task_id': taskId,
      if (tagId != null) 'tag_id': tagId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TaskTagTableCompanion copyWith(
      {Value<String>? id,
      Value<DateTime>? createdDate,
      Value<DateTime?>? modifiedDate,
      Value<DateTime?>? deletedDate,
      Value<String>? taskId,
      Value<String>? tagId,
      Value<int>? rowid}) {
    return TaskTagTableCompanion(
      id: id ?? this.id,
      createdDate: createdDate ?? this.createdDate,
      modifiedDate: modifiedDate ?? this.modifiedDate,
      deletedDate: deletedDate ?? this.deletedDate,
      taskId: taskId ?? this.taskId,
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
    if (deletedDate.present) {
      map['deleted_date'] = Variable<DateTime>(deletedDate.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<String>(tagId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaskTagTableCompanion(')
          ..write('id: $id, ')
          ..write('createdDate: $createdDate, ')
          ..write('modifiedDate: $modifiedDate, ')
          ..write('deletedDate: $deletedDate, ')
          ..write('taskId: $taskId, ')
          ..write('tagId: $tagId, ')
          ..write('rowid: $rowid')
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
  static const VerificationMeta _deletedDateMeta = const VerificationMeta('deletedDate');
  @override
  late final GeneratedColumn<DateTime> deletedDate = GeneratedColumn<DateTime>('deleted_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name =
      GeneratedColumn<String>('name', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, createdDate, modifiedDate, deletedDate, name];
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
    if (data.containsKey('deleted_date')) {
      context.handle(_deletedDateMeta, deletedDate.isAcceptableOrUnknown(data['deleted_date']!, _deletedDateMeta));
    }
    if (data.containsKey('name')) {
      context.handle(_nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  Tag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Tag(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      createdDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_date'])!,
      modifiedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}modified_date']),
      deletedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_date']),
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!,
    );
  }

  @override
  $TagTableTable createAlias(String alias) {
    return $TagTableTable(attachedDatabase, alias);
  }
}

class TagTableCompanion extends UpdateCompanion<Tag> {
  final Value<String> id;
  final Value<DateTime> createdDate;
  final Value<DateTime?> modifiedDate;
  final Value<DateTime?> deletedDate;
  final Value<String> name;
  final Value<int> rowid;
  const TagTableCompanion({
    this.id = const Value.absent(),
    this.createdDate = const Value.absent(),
    this.modifiedDate = const Value.absent(),
    this.deletedDate = const Value.absent(),
    this.name = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TagTableCompanion.insert({
    required String id,
    required DateTime createdDate,
    this.modifiedDate = const Value.absent(),
    this.deletedDate = const Value.absent(),
    required String name,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        createdDate = Value(createdDate),
        name = Value(name);
  static Insertable<Tag> custom({
    Expression<String>? id,
    Expression<DateTime>? createdDate,
    Expression<DateTime>? modifiedDate,
    Expression<DateTime>? deletedDate,
    Expression<String>? name,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdDate != null) 'created_date': createdDate,
      if (modifiedDate != null) 'modified_date': modifiedDate,
      if (deletedDate != null) 'deleted_date': deletedDate,
      if (name != null) 'name': name,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TagTableCompanion copyWith(
      {Value<String>? id,
      Value<DateTime>? createdDate,
      Value<DateTime?>? modifiedDate,
      Value<DateTime?>? deletedDate,
      Value<String>? name,
      Value<int>? rowid}) {
    return TagTableCompanion(
      id: id ?? this.id,
      createdDate: createdDate ?? this.createdDate,
      modifiedDate: modifiedDate ?? this.modifiedDate,
      deletedDate: deletedDate ?? this.deletedDate,
      name: name ?? this.name,
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
    if (deletedDate.present) {
      map['deleted_date'] = Variable<DateTime>(deletedDate.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagTableCompanion(')
          ..write('id: $id, ')
          ..write('createdDate: $createdDate, ')
          ..write('modifiedDate: $modifiedDate, ')
          ..write('deletedDate: $deletedDate, ')
          ..write('name: $name, ')
          ..write('rowid: $rowid')
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
  static const VerificationMeta _deletedDateMeta = const VerificationMeta('deletedDate');
  @override
  late final GeneratedColumn<DateTime> deletedDate = GeneratedColumn<DateTime>('deleted_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _primaryTagIdMeta = const VerificationMeta('primaryTagId');
  @override
  late final GeneratedColumn<String> primaryTagId = GeneratedColumn<String>('primary_tag_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _secondaryTagIdMeta = const VerificationMeta('secondaryTagId');
  @override
  late final GeneratedColumn<String> secondaryTagId = GeneratedColumn<String>('secondary_tag_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, createdDate, modifiedDate, deletedDate, primaryTagId, secondaryTagId];
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
    if (data.containsKey('deleted_date')) {
      context.handle(_deletedDateMeta, deletedDate.isAcceptableOrUnknown(data['deleted_date']!, _deletedDateMeta));
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
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  TagTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TagTag(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      createdDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_date'])!,
      modifiedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}modified_date']),
      deletedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_date']),
      primaryTagId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}primary_tag_id'])!,
      secondaryTagId:
          attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}secondary_tag_id'])!,
    );
  }

  @override
  $TagTagTableTable createAlias(String alias) {
    return $TagTagTableTable(attachedDatabase, alias);
  }
}

class TagTagTableCompanion extends UpdateCompanion<TagTag> {
  final Value<String> id;
  final Value<DateTime> createdDate;
  final Value<DateTime?> modifiedDate;
  final Value<DateTime?> deletedDate;
  final Value<String> primaryTagId;
  final Value<String> secondaryTagId;
  final Value<int> rowid;
  const TagTagTableCompanion({
    this.id = const Value.absent(),
    this.createdDate = const Value.absent(),
    this.modifiedDate = const Value.absent(),
    this.deletedDate = const Value.absent(),
    this.primaryTagId = const Value.absent(),
    this.secondaryTagId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TagTagTableCompanion.insert({
    required String id,
    required DateTime createdDate,
    this.modifiedDate = const Value.absent(),
    this.deletedDate = const Value.absent(),
    required String primaryTagId,
    required String secondaryTagId,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        createdDate = Value(createdDate),
        primaryTagId = Value(primaryTagId),
        secondaryTagId = Value(secondaryTagId);
  static Insertable<TagTag> custom({
    Expression<String>? id,
    Expression<DateTime>? createdDate,
    Expression<DateTime>? modifiedDate,
    Expression<DateTime>? deletedDate,
    Expression<String>? primaryTagId,
    Expression<String>? secondaryTagId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdDate != null) 'created_date': createdDate,
      if (modifiedDate != null) 'modified_date': modifiedDate,
      if (deletedDate != null) 'deleted_date': deletedDate,
      if (primaryTagId != null) 'primary_tag_id': primaryTagId,
      if (secondaryTagId != null) 'secondary_tag_id': secondaryTagId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TagTagTableCompanion copyWith(
      {Value<String>? id,
      Value<DateTime>? createdDate,
      Value<DateTime?>? modifiedDate,
      Value<DateTime?>? deletedDate,
      Value<String>? primaryTagId,
      Value<String>? secondaryTagId,
      Value<int>? rowid}) {
    return TagTagTableCompanion(
      id: id ?? this.id,
      createdDate: createdDate ?? this.createdDate,
      modifiedDate: modifiedDate ?? this.modifiedDate,
      deletedDate: deletedDate ?? this.deletedDate,
      primaryTagId: primaryTagId ?? this.primaryTagId,
      secondaryTagId: secondaryTagId ?? this.secondaryTagId,
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
    if (deletedDate.present) {
      map['deleted_date'] = Variable<DateTime>(deletedDate.value);
    }
    if (primaryTagId.present) {
      map['primary_tag_id'] = Variable<String>(primaryTagId.value);
    }
    if (secondaryTagId.present) {
      map['secondary_tag_id'] = Variable<String>(secondaryTagId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagTagTableCompanion(')
          ..write('id: $id, ')
          ..write('createdDate: $createdDate, ')
          ..write('modifiedDate: $modifiedDate, ')
          ..write('deletedDate: $deletedDate, ')
          ..write('primaryTagId: $primaryTagId, ')
          ..write('secondaryTagId: $secondaryTagId, ')
          ..write('rowid: $rowid')
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
  static const VerificationMeta _deletedDateMeta = const VerificationMeta('deletedDate');
  @override
  late final GeneratedColumn<DateTime> deletedDate = GeneratedColumn<DateTime>('deleted_date', aliasedName, true,
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
  List<GeneratedColumn> get $columns => [id, createdDate, modifiedDate, deletedDate, key, value, valueType];
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
    if (data.containsKey('deleted_date')) {
      context.handle(_deletedDateMeta, deletedDate.isAcceptableOrUnknown(data['deleted_date']!, _deletedDateMeta));
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
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      createdDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_date'])!,
      modifiedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}modified_date']),
      deletedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_date']),
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
  final Value<String> id;
  final Value<DateTime> createdDate;
  final Value<DateTime?> modifiedDate;
  final Value<DateTime?> deletedDate;
  final Value<String> key;
  final Value<String> value;
  final Value<SettingValueType> valueType;
  final Value<int> rowid;
  const SettingTableCompanion({
    this.id = const Value.absent(),
    this.createdDate = const Value.absent(),
    this.modifiedDate = const Value.absent(),
    this.deletedDate = const Value.absent(),
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.valueType = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingTableCompanion.insert({
    required String id,
    required DateTime createdDate,
    this.modifiedDate = const Value.absent(),
    this.deletedDate = const Value.absent(),
    required String key,
    required String value,
    required SettingValueType valueType,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        createdDate = Value(createdDate),
        key = Value(key),
        value = Value(value),
        valueType = Value(valueType);
  static Insertable<Setting> custom({
    Expression<String>? id,
    Expression<DateTime>? createdDate,
    Expression<DateTime>? modifiedDate,
    Expression<DateTime>? deletedDate,
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? valueType,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdDate != null) 'created_date': createdDate,
      if (modifiedDate != null) 'modified_date': modifiedDate,
      if (deletedDate != null) 'deleted_date': deletedDate,
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (valueType != null) 'value_type': valueType,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingTableCompanion copyWith(
      {Value<String>? id,
      Value<DateTime>? createdDate,
      Value<DateTime?>? modifiedDate,
      Value<DateTime?>? deletedDate,
      Value<String>? key,
      Value<String>? value,
      Value<SettingValueType>? valueType,
      Value<int>? rowid}) {
    return SettingTableCompanion(
      id: id ?? this.id,
      createdDate: createdDate ?? this.createdDate,
      modifiedDate: modifiedDate ?? this.modifiedDate,
      deletedDate: deletedDate ?? this.deletedDate,
      key: key ?? this.key,
      value: value ?? this.value,
      valueType: valueType ?? this.valueType,
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
    if (deletedDate.present) {
      map['deleted_date'] = Variable<DateTime>(deletedDate.value);
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
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingTableCompanion(')
          ..write('id: $id, ')
          ..write('createdDate: $createdDate, ')
          ..write('modifiedDate: $modifiedDate, ')
          ..write('deletedDate: $deletedDate, ')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('valueType: $valueType, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncDeviceTableTable extends SyncDeviceTable with TableInfo<$SyncDeviceTableTable, SyncDevice> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncDeviceTableTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _deletedDateMeta = const VerificationMeta('deletedDate');
  @override
  late final GeneratedColumn<DateTime> deletedDate = GeneratedColumn<DateTime>('deleted_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _fromIpMeta = const VerificationMeta('fromIp');
  @override
  late final GeneratedColumn<String> fromIp =
      GeneratedColumn<String>('from_ip', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _toIpMeta = const VerificationMeta('toIp');
  @override
  late final GeneratedColumn<String> toIp =
      GeneratedColumn<String>('to_ip', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name =
      GeneratedColumn<String>('name', aliasedName, true, type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lastSyncDateMeta = const VerificationMeta('lastSyncDate');
  @override
  late final GeneratedColumn<DateTime> lastSyncDate = GeneratedColumn<DateTime>('last_sync_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [id, createdDate, modifiedDate, deletedDate, fromIp, toIp, name, lastSyncDate];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_device_table';
  @override
  VerificationContext validateIntegrity(Insertable<SyncDevice> instance, {bool isInserting = false}) {
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
    if (data.containsKey('deleted_date')) {
      context.handle(_deletedDateMeta, deletedDate.isAcceptableOrUnknown(data['deleted_date']!, _deletedDateMeta));
    }
    if (data.containsKey('from_ip')) {
      context.handle(_fromIpMeta, fromIp.isAcceptableOrUnknown(data['from_ip']!, _fromIpMeta));
    } else if (isInserting) {
      context.missing(_fromIpMeta);
    }
    if (data.containsKey('to_ip')) {
      context.handle(_toIpMeta, toIp.isAcceptableOrUnknown(data['to_ip']!, _toIpMeta));
    } else if (isInserting) {
      context.missing(_toIpMeta);
    }
    if (data.containsKey('name')) {
      context.handle(_nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    }
    if (data.containsKey('last_sync_date')) {
      context.handle(_lastSyncDateMeta, lastSyncDate.isAcceptableOrUnknown(data['last_sync_date']!, _lastSyncDateMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  SyncDevice map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncDevice(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      createdDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_date'])!,
      fromIp: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}from_ip'])!,
      toIp: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}to_ip'])!,
      modifiedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}modified_date']),
      deletedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_date']),
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name']),
      lastSyncDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}last_sync_date']),
    );
  }

  @override
  $SyncDeviceTableTable createAlias(String alias) {
    return $SyncDeviceTableTable(attachedDatabase, alias);
  }
}

class SyncDeviceTableCompanion extends UpdateCompanion<SyncDevice> {
  final Value<String> id;
  final Value<DateTime> createdDate;
  final Value<DateTime?> modifiedDate;
  final Value<DateTime?> deletedDate;
  final Value<String> fromIp;
  final Value<String> toIp;
  final Value<String?> name;
  final Value<DateTime?> lastSyncDate;
  final Value<int> rowid;
  const SyncDeviceTableCompanion({
    this.id = const Value.absent(),
    this.createdDate = const Value.absent(),
    this.modifiedDate = const Value.absent(),
    this.deletedDate = const Value.absent(),
    this.fromIp = const Value.absent(),
    this.toIp = const Value.absent(),
    this.name = const Value.absent(),
    this.lastSyncDate = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncDeviceTableCompanion.insert({
    required String id,
    required DateTime createdDate,
    this.modifiedDate = const Value.absent(),
    this.deletedDate = const Value.absent(),
    required String fromIp,
    required String toIp,
    this.name = const Value.absent(),
    this.lastSyncDate = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        createdDate = Value(createdDate),
        fromIp = Value(fromIp),
        toIp = Value(toIp);
  static Insertable<SyncDevice> custom({
    Expression<String>? id,
    Expression<DateTime>? createdDate,
    Expression<DateTime>? modifiedDate,
    Expression<DateTime>? deletedDate,
    Expression<String>? fromIp,
    Expression<String>? toIp,
    Expression<String>? name,
    Expression<DateTime>? lastSyncDate,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdDate != null) 'created_date': createdDate,
      if (modifiedDate != null) 'modified_date': modifiedDate,
      if (deletedDate != null) 'deleted_date': deletedDate,
      if (fromIp != null) 'from_ip': fromIp,
      if (toIp != null) 'to_ip': toIp,
      if (name != null) 'name': name,
      if (lastSyncDate != null) 'last_sync_date': lastSyncDate,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncDeviceTableCompanion copyWith(
      {Value<String>? id,
      Value<DateTime>? createdDate,
      Value<DateTime?>? modifiedDate,
      Value<DateTime?>? deletedDate,
      Value<String>? fromIp,
      Value<String>? toIp,
      Value<String?>? name,
      Value<DateTime?>? lastSyncDate,
      Value<int>? rowid}) {
    return SyncDeviceTableCompanion(
      id: id ?? this.id,
      createdDate: createdDate ?? this.createdDate,
      modifiedDate: modifiedDate ?? this.modifiedDate,
      deletedDate: deletedDate ?? this.deletedDate,
      fromIp: fromIp ?? this.fromIp,
      toIp: toIp ?? this.toIp,
      name: name ?? this.name,
      lastSyncDate: lastSyncDate ?? this.lastSyncDate,
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
    if (deletedDate.present) {
      map['deleted_date'] = Variable<DateTime>(deletedDate.value);
    }
    if (fromIp.present) {
      map['from_ip'] = Variable<String>(fromIp.value);
    }
    if (toIp.present) {
      map['to_ip'] = Variable<String>(toIp.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (lastSyncDate.present) {
      map['last_sync_date'] = Variable<DateTime>(lastSyncDate.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncDeviceTableCompanion(')
          ..write('id: $id, ')
          ..write('createdDate: $createdDate, ')
          ..write('modifiedDate: $modifiedDate, ')
          ..write('deletedDate: $deletedDate, ')
          ..write('fromIp: $fromIp, ')
          ..write('toIp: $toIp, ')
          ..write('name: $name, ')
          ..write('lastSyncDate: $lastSyncDate, ')
          ..write('rowid: $rowid')
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
  late final $HabitTagTableTable habitTagTable = $HabitTagTableTable(this);
  late final $HabitRecordTableTable habitRecordTable = $HabitRecordTableTable(this);
  late final $TaskTableTable taskTable = $TaskTableTable(this);
  late final $TaskTagTableTable taskTagTable = $TaskTagTableTable(this);
  late final $TagTableTable tagTable = $TagTableTable(this);
  late final $TagTagTableTable tagTagTable = $TagTagTableTable(this);
  late final $SettingTableTable settingTable = $SettingTableTable(this);
  late final $SyncDeviceTableTable syncDeviceTable = $SyncDeviceTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        appUsageTable,
        appUsageTagTable,
        habitTable,
        habitTagTable,
        habitRecordTable,
        taskTable,
        taskTagTable,
        tagTable,
        tagTagTable,
        settingTable,
        syncDeviceTable
      ];
}

typedef $$AppUsageTableTableCreateCompanionBuilder = AppUsageTableCompanion Function({
  required String id,
  required DateTime createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  required String name,
  Value<String?> displayName,
  Value<String?> color,
  required int duration,
  Value<int> rowid,
});
typedef $$AppUsageTableTableUpdateCompanionBuilder = AppUsageTableCompanion Function({
  Value<String> id,
  Value<DateTime> createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  Value<String> name,
  Value<String?> displayName,
  Value<String?> color,
  Value<int> duration,
  Value<int> rowid,
});

class $$AppUsageTableTableFilterComposer extends Composer<_$AppDatabase, $AppUsageTableTable> {
  $$AppUsageTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdDate =>
      $composableBuilder(column: $table.createdDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get modifiedDate =>
      $composableBuilder(column: $table.modifiedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedDate =>
      $composableBuilder(column: $table.deletedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get displayName =>
      $composableBuilder(column: $table.displayName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get duration =>
      $composableBuilder(column: $table.duration, builder: (column) => ColumnFilters(column));
}

class $$AppUsageTableTableOrderingComposer extends Composer<_$AppDatabase, $AppUsageTableTable> {
  $$AppUsageTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdDate =>
      $composableBuilder(column: $table.createdDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get modifiedDate =>
      $composableBuilder(column: $table.modifiedDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedDate =>
      $composableBuilder(column: $table.deletedDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get displayName =>
      $composableBuilder(column: $table.displayName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get duration =>
      $composableBuilder(column: $table.duration, builder: (column) => ColumnOrderings(column));
}

class $$AppUsageTableTableAnnotationComposer extends Composer<_$AppDatabase, $AppUsageTableTable> {
  $$AppUsageTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdDate =>
      $composableBuilder(column: $table.createdDate, builder: (column) => column);

  GeneratedColumn<DateTime> get modifiedDate =>
      $composableBuilder(column: $table.modifiedDate, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedDate =>
      $composableBuilder(column: $table.deletedDate, builder: (column) => column);

  GeneratedColumn<String> get name => $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get displayName =>
      $composableBuilder(column: $table.displayName, builder: (column) => column);

  GeneratedColumn<String> get color => $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<int> get duration => $composableBuilder(column: $table.duration, builder: (column) => column);
}

class $$AppUsageTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AppUsageTableTable,
    AppUsage,
    $$AppUsageTableTableFilterComposer,
    $$AppUsageTableTableOrderingComposer,
    $$AppUsageTableTableAnnotationComposer,
    $$AppUsageTableTableCreateCompanionBuilder,
    $$AppUsageTableTableUpdateCompanionBuilder,
    (AppUsage, BaseReferences<_$AppDatabase, $AppUsageTableTable, AppUsage>),
    AppUsage,
    PrefetchHooks Function()> {
  $$AppUsageTableTableTableManager(_$AppDatabase db, $AppUsageTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$AppUsageTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$AppUsageTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$AppUsageTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<DateTime> createdDate = const Value.absent(),
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<DateTime?> deletedDate = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> displayName = const Value.absent(),
            Value<String?> color = const Value.absent(),
            Value<int> duration = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppUsageTableCompanion(
            id: id,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            deletedDate: deletedDate,
            name: name,
            displayName: displayName,
            color: color,
            duration: duration,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required DateTime createdDate,
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<DateTime?> deletedDate = const Value.absent(),
            required String name,
            Value<String?> displayName = const Value.absent(),
            Value<String?> color = const Value.absent(),
            required int duration,
            Value<int> rowid = const Value.absent(),
          }) =>
              AppUsageTableCompanion.insert(
            id: id,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            deletedDate: deletedDate,
            name: name,
            displayName: displayName,
            color: color,
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
    $$AppUsageTableTableAnnotationComposer,
    $$AppUsageTableTableCreateCompanionBuilder,
    $$AppUsageTableTableUpdateCompanionBuilder,
    (AppUsage, BaseReferences<_$AppDatabase, $AppUsageTableTable, AppUsage>),
    AppUsage,
    PrefetchHooks Function()>;
typedef $$AppUsageTagTableTableCreateCompanionBuilder = AppUsageTagTableCompanion Function({
  required String id,
  required DateTime createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  required String appUsageId,
  required String tagId,
  Value<int> rowid,
});
typedef $$AppUsageTagTableTableUpdateCompanionBuilder = AppUsageTagTableCompanion Function({
  Value<String> id,
  Value<DateTime> createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  Value<String> appUsageId,
  Value<String> tagId,
  Value<int> rowid,
});

class $$AppUsageTagTableTableFilterComposer extends Composer<_$AppDatabase, $AppUsageTagTableTable> {
  $$AppUsageTagTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdDate =>
      $composableBuilder(column: $table.createdDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get modifiedDate =>
      $composableBuilder(column: $table.modifiedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedDate =>
      $composableBuilder(column: $table.deletedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get appUsageId =>
      $composableBuilder(column: $table.appUsageId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tagId =>
      $composableBuilder(column: $table.tagId, builder: (column) => ColumnFilters(column));
}

class $$AppUsageTagTableTableOrderingComposer extends Composer<_$AppDatabase, $AppUsageTagTableTable> {
  $$AppUsageTagTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdDate =>
      $composableBuilder(column: $table.createdDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get modifiedDate =>
      $composableBuilder(column: $table.modifiedDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedDate =>
      $composableBuilder(column: $table.deletedDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get appUsageId =>
      $composableBuilder(column: $table.appUsageId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tagId =>
      $composableBuilder(column: $table.tagId, builder: (column) => ColumnOrderings(column));
}

class $$AppUsageTagTableTableAnnotationComposer extends Composer<_$AppDatabase, $AppUsageTagTableTable> {
  $$AppUsageTagTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdDate =>
      $composableBuilder(column: $table.createdDate, builder: (column) => column);

  GeneratedColumn<DateTime> get modifiedDate =>
      $composableBuilder(column: $table.modifiedDate, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedDate =>
      $composableBuilder(column: $table.deletedDate, builder: (column) => column);

  GeneratedColumn<String> get appUsageId => $composableBuilder(column: $table.appUsageId, builder: (column) => column);

  GeneratedColumn<String> get tagId => $composableBuilder(column: $table.tagId, builder: (column) => column);
}

class $$AppUsageTagTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AppUsageTagTableTable,
    AppUsageTag,
    $$AppUsageTagTableTableFilterComposer,
    $$AppUsageTagTableTableOrderingComposer,
    $$AppUsageTagTableTableAnnotationComposer,
    $$AppUsageTagTableTableCreateCompanionBuilder,
    $$AppUsageTagTableTableUpdateCompanionBuilder,
    (AppUsageTag, BaseReferences<_$AppDatabase, $AppUsageTagTableTable, AppUsageTag>),
    AppUsageTag,
    PrefetchHooks Function()> {
  $$AppUsageTagTableTableTableManager(_$AppDatabase db, $AppUsageTagTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$AppUsageTagTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$AppUsageTagTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$AppUsageTagTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<DateTime> createdDate = const Value.absent(),
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<DateTime?> deletedDate = const Value.absent(),
            Value<String> appUsageId = const Value.absent(),
            Value<String> tagId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppUsageTagTableCompanion(
            id: id,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            deletedDate: deletedDate,
            appUsageId: appUsageId,
            tagId: tagId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required DateTime createdDate,
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<DateTime?> deletedDate = const Value.absent(),
            required String appUsageId,
            required String tagId,
            Value<int> rowid = const Value.absent(),
          }) =>
              AppUsageTagTableCompanion.insert(
            id: id,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            deletedDate: deletedDate,
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
    $$AppUsageTagTableTableAnnotationComposer,
    $$AppUsageTagTableTableCreateCompanionBuilder,
    $$AppUsageTagTableTableUpdateCompanionBuilder,
    (AppUsageTag, BaseReferences<_$AppDatabase, $AppUsageTagTableTable, AppUsageTag>),
    AppUsageTag,
    PrefetchHooks Function()>;
typedef $$HabitTableTableCreateCompanionBuilder = HabitTableCompanion Function({
  required String id,
  required DateTime createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  required String name,
  required String description,
  Value<int> rowid,
});
typedef $$HabitTableTableUpdateCompanionBuilder = HabitTableCompanion Function({
  Value<String> id,
  Value<DateTime> createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  Value<String> name,
  Value<String> description,
  Value<int> rowid,
});

class $$HabitTableTableFilterComposer extends Composer<_$AppDatabase, $HabitTableTable> {
  $$HabitTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdDate =>
      $composableBuilder(column: $table.createdDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get modifiedDate =>
      $composableBuilder(column: $table.modifiedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedDate =>
      $composableBuilder(column: $table.deletedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description =>
      $composableBuilder(column: $table.description, builder: (column) => ColumnFilters(column));
}

class $$HabitTableTableOrderingComposer extends Composer<_$AppDatabase, $HabitTableTable> {
  $$HabitTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdDate =>
      $composableBuilder(column: $table.createdDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get modifiedDate =>
      $composableBuilder(column: $table.modifiedDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedDate =>
      $composableBuilder(column: $table.deletedDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description =>
      $composableBuilder(column: $table.description, builder: (column) => ColumnOrderings(column));
}

class $$HabitTableTableAnnotationComposer extends Composer<_$AppDatabase, $HabitTableTable> {
  $$HabitTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdDate =>
      $composableBuilder(column: $table.createdDate, builder: (column) => column);

  GeneratedColumn<DateTime> get modifiedDate =>
      $composableBuilder(column: $table.modifiedDate, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedDate =>
      $composableBuilder(column: $table.deletedDate, builder: (column) => column);

  GeneratedColumn<String> get name => $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description =>
      $composableBuilder(column: $table.description, builder: (column) => column);
}

class $$HabitTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $HabitTableTable,
    Habit,
    $$HabitTableTableFilterComposer,
    $$HabitTableTableOrderingComposer,
    $$HabitTableTableAnnotationComposer,
    $$HabitTableTableCreateCompanionBuilder,
    $$HabitTableTableUpdateCompanionBuilder,
    (Habit, BaseReferences<_$AppDatabase, $HabitTableTable, Habit>),
    Habit,
    PrefetchHooks Function()> {
  $$HabitTableTableTableManager(_$AppDatabase db, $HabitTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$HabitTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$HabitTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$HabitTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<DateTime> createdDate = const Value.absent(),
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<DateTime?> deletedDate = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> description = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              HabitTableCompanion(
            id: id,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            deletedDate: deletedDate,
            name: name,
            description: description,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required DateTime createdDate,
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<DateTime?> deletedDate = const Value.absent(),
            required String name,
            required String description,
            Value<int> rowid = const Value.absent(),
          }) =>
              HabitTableCompanion.insert(
            id: id,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            deletedDate: deletedDate,
            name: name,
            description: description,
            rowid: rowid,
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
    $$HabitTableTableAnnotationComposer,
    $$HabitTableTableCreateCompanionBuilder,
    $$HabitTableTableUpdateCompanionBuilder,
    (Habit, BaseReferences<_$AppDatabase, $HabitTableTable, Habit>),
    Habit,
    PrefetchHooks Function()>;
typedef $$HabitTagTableTableCreateCompanionBuilder = HabitTagTableCompanion Function({
  required String id,
  required DateTime createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  required String habitId,
  required String tagId,
  Value<int> rowid,
});
typedef $$HabitTagTableTableUpdateCompanionBuilder = HabitTagTableCompanion Function({
  Value<String> id,
  Value<DateTime> createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  Value<String> habitId,
  Value<String> tagId,
  Value<int> rowid,
});

class $$HabitTagTableTableFilterComposer extends Composer<_$AppDatabase, $HabitTagTableTable> {
  $$HabitTagTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdDate =>
      $composableBuilder(column: $table.createdDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get modifiedDate =>
      $composableBuilder(column: $table.modifiedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedDate =>
      $composableBuilder(column: $table.deletedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get habitId =>
      $composableBuilder(column: $table.habitId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tagId =>
      $composableBuilder(column: $table.tagId, builder: (column) => ColumnFilters(column));
}

class $$HabitTagTableTableOrderingComposer extends Composer<_$AppDatabase, $HabitTagTableTable> {
  $$HabitTagTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdDate =>
      $composableBuilder(column: $table.createdDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get modifiedDate =>
      $composableBuilder(column: $table.modifiedDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedDate =>
      $composableBuilder(column: $table.deletedDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get habitId =>
      $composableBuilder(column: $table.habitId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tagId =>
      $composableBuilder(column: $table.tagId, builder: (column) => ColumnOrderings(column));
}

class $$HabitTagTableTableAnnotationComposer extends Composer<_$AppDatabase, $HabitTagTableTable> {
  $$HabitTagTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdDate =>
      $composableBuilder(column: $table.createdDate, builder: (column) => column);

  GeneratedColumn<DateTime> get modifiedDate =>
      $composableBuilder(column: $table.modifiedDate, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedDate =>
      $composableBuilder(column: $table.deletedDate, builder: (column) => column);

  GeneratedColumn<String> get habitId => $composableBuilder(column: $table.habitId, builder: (column) => column);

  GeneratedColumn<String> get tagId => $composableBuilder(column: $table.tagId, builder: (column) => column);
}

class $$HabitTagTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $HabitTagTableTable,
    HabitTag,
    $$HabitTagTableTableFilterComposer,
    $$HabitTagTableTableOrderingComposer,
    $$HabitTagTableTableAnnotationComposer,
    $$HabitTagTableTableCreateCompanionBuilder,
    $$HabitTagTableTableUpdateCompanionBuilder,
    (HabitTag, BaseReferences<_$AppDatabase, $HabitTagTableTable, HabitTag>),
    HabitTag,
    PrefetchHooks Function()> {
  $$HabitTagTableTableTableManager(_$AppDatabase db, $HabitTagTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$HabitTagTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$HabitTagTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$HabitTagTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<DateTime> createdDate = const Value.absent(),
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<DateTime?> deletedDate = const Value.absent(),
            Value<String> habitId = const Value.absent(),
            Value<String> tagId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              HabitTagTableCompanion(
            id: id,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            deletedDate: deletedDate,
            habitId: habitId,
            tagId: tagId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required DateTime createdDate,
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<DateTime?> deletedDate = const Value.absent(),
            required String habitId,
            required String tagId,
            Value<int> rowid = const Value.absent(),
          }) =>
              HabitTagTableCompanion.insert(
            id: id,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            deletedDate: deletedDate,
            habitId: habitId,
            tagId: tagId,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$HabitTagTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $HabitTagTableTable,
    HabitTag,
    $$HabitTagTableTableFilterComposer,
    $$HabitTagTableTableOrderingComposer,
    $$HabitTagTableTableAnnotationComposer,
    $$HabitTagTableTableCreateCompanionBuilder,
    $$HabitTagTableTableUpdateCompanionBuilder,
    (HabitTag, BaseReferences<_$AppDatabase, $HabitTagTableTable, HabitTag>),
    HabitTag,
    PrefetchHooks Function()>;
typedef $$HabitRecordTableTableCreateCompanionBuilder = HabitRecordTableCompanion Function({
  required String id,
  required DateTime createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  required String habitId,
  required DateTime date,
  Value<int> rowid,
});
typedef $$HabitRecordTableTableUpdateCompanionBuilder = HabitRecordTableCompanion Function({
  Value<String> id,
  Value<DateTime> createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  Value<String> habitId,
  Value<DateTime> date,
  Value<int> rowid,
});

class $$HabitRecordTableTableFilterComposer extends Composer<_$AppDatabase, $HabitRecordTableTable> {
  $$HabitRecordTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdDate =>
      $composableBuilder(column: $table.createdDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get modifiedDate =>
      $composableBuilder(column: $table.modifiedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedDate =>
      $composableBuilder(column: $table.deletedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get habitId =>
      $composableBuilder(column: $table.habitId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => ColumnFilters(column));
}

class $$HabitRecordTableTableOrderingComposer extends Composer<_$AppDatabase, $HabitRecordTableTable> {
  $$HabitRecordTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdDate =>
      $composableBuilder(column: $table.createdDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get modifiedDate =>
      $composableBuilder(column: $table.modifiedDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedDate =>
      $composableBuilder(column: $table.deletedDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get habitId =>
      $composableBuilder(column: $table.habitId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => ColumnOrderings(column));
}

class $$HabitRecordTableTableAnnotationComposer extends Composer<_$AppDatabase, $HabitRecordTableTable> {
  $$HabitRecordTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdDate =>
      $composableBuilder(column: $table.createdDate, builder: (column) => column);

  GeneratedColumn<DateTime> get modifiedDate =>
      $composableBuilder(column: $table.modifiedDate, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedDate =>
      $composableBuilder(column: $table.deletedDate, builder: (column) => column);

  GeneratedColumn<String> get habitId => $composableBuilder(column: $table.habitId, builder: (column) => column);

  GeneratedColumn<DateTime> get date => $composableBuilder(column: $table.date, builder: (column) => column);
}

class $$HabitRecordTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $HabitRecordTableTable,
    HabitRecord,
    $$HabitRecordTableTableFilterComposer,
    $$HabitRecordTableTableOrderingComposer,
    $$HabitRecordTableTableAnnotationComposer,
    $$HabitRecordTableTableCreateCompanionBuilder,
    $$HabitRecordTableTableUpdateCompanionBuilder,
    (HabitRecord, BaseReferences<_$AppDatabase, $HabitRecordTableTable, HabitRecord>),
    HabitRecord,
    PrefetchHooks Function()> {
  $$HabitRecordTableTableTableManager(_$AppDatabase db, $HabitRecordTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$HabitRecordTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$HabitRecordTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$HabitRecordTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<DateTime> createdDate = const Value.absent(),
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<DateTime?> deletedDate = const Value.absent(),
            Value<String> habitId = const Value.absent(),
            Value<DateTime> date = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              HabitRecordTableCompanion(
            id: id,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            deletedDate: deletedDate,
            habitId: habitId,
            date: date,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required DateTime createdDate,
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<DateTime?> deletedDate = const Value.absent(),
            required String habitId,
            required DateTime date,
            Value<int> rowid = const Value.absent(),
          }) =>
              HabitRecordTableCompanion.insert(
            id: id,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            deletedDate: deletedDate,
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
    $$HabitRecordTableTableAnnotationComposer,
    $$HabitRecordTableTableCreateCompanionBuilder,
    $$HabitRecordTableTableUpdateCompanionBuilder,
    (HabitRecord, BaseReferences<_$AppDatabase, $HabitRecordTableTable, HabitRecord>),
    HabitRecord,
    PrefetchHooks Function()>;
typedef $$TaskTableTableCreateCompanionBuilder = TaskTableCompanion Function({
  required String id,
  required DateTime createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  required String title,
  Value<String?> description,
  Value<EisenhowerPriority?> priority,
  Value<DateTime?> plannedDate,
  Value<DateTime?> deadlineDate,
  Value<int?> estimatedTime,
  Value<int?> elapsedTime,
  Value<bool> isCompleted,
  Value<int> rowid,
});
typedef $$TaskTableTableUpdateCompanionBuilder = TaskTableCompanion Function({
  Value<String> id,
  Value<DateTime> createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  Value<String> title,
  Value<String?> description,
  Value<EisenhowerPriority?> priority,
  Value<DateTime?> plannedDate,
  Value<DateTime?> deadlineDate,
  Value<int?> estimatedTime,
  Value<int?> elapsedTime,
  Value<bool> isCompleted,
  Value<int> rowid,
});

class $$TaskTableTableFilterComposer extends Composer<_$AppDatabase, $TaskTableTable> {
  $$TaskTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdDate =>
      $composableBuilder(column: $table.createdDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get modifiedDate =>
      $composableBuilder(column: $table.modifiedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedDate =>
      $composableBuilder(column: $table.deletedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description =>
      $composableBuilder(column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<EisenhowerPriority?, EisenhowerPriority, int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<DateTime> get plannedDate =>
      $composableBuilder(column: $table.plannedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deadlineDate =>
      $composableBuilder(column: $table.deadlineDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get estimatedTime =>
      $composableBuilder(column: $table.estimatedTime, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get elapsedTime =>
      $composableBuilder(column: $table.elapsedTime, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isCompleted =>
      $composableBuilder(column: $table.isCompleted, builder: (column) => ColumnFilters(column));
}

class $$TaskTableTableOrderingComposer extends Composer<_$AppDatabase, $TaskTableTable> {
  $$TaskTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdDate =>
      $composableBuilder(column: $table.createdDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get modifiedDate =>
      $composableBuilder(column: $table.modifiedDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedDate =>
      $composableBuilder(column: $table.deletedDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description =>
      $composableBuilder(column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get plannedDate =>
      $composableBuilder(column: $table.plannedDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deadlineDate =>
      $composableBuilder(column: $table.deadlineDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get estimatedTime =>
      $composableBuilder(column: $table.estimatedTime, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get elapsedTime =>
      $composableBuilder(column: $table.elapsedTime, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isCompleted =>
      $composableBuilder(column: $table.isCompleted, builder: (column) => ColumnOrderings(column));
}

class $$TaskTableTableAnnotationComposer extends Composer<_$AppDatabase, $TaskTableTable> {
  $$TaskTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdDate =>
      $composableBuilder(column: $table.createdDate, builder: (column) => column);

  GeneratedColumn<DateTime> get modifiedDate =>
      $composableBuilder(column: $table.modifiedDate, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedDate =>
      $composableBuilder(column: $table.deletedDate, builder: (column) => column);

  GeneratedColumn<String> get title => $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description =>
      $composableBuilder(column: $table.description, builder: (column) => column);

  GeneratedColumnWithTypeConverter<EisenhowerPriority?, int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<DateTime> get plannedDate =>
      $composableBuilder(column: $table.plannedDate, builder: (column) => column);

  GeneratedColumn<DateTime> get deadlineDate =>
      $composableBuilder(column: $table.deadlineDate, builder: (column) => column);

  GeneratedColumn<int> get estimatedTime =>
      $composableBuilder(column: $table.estimatedTime, builder: (column) => column);

  GeneratedColumn<int> get elapsedTime => $composableBuilder(column: $table.elapsedTime, builder: (column) => column);

  GeneratedColumn<bool> get isCompleted => $composableBuilder(column: $table.isCompleted, builder: (column) => column);
}

class $$TaskTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TaskTableTable,
    Task,
    $$TaskTableTableFilterComposer,
    $$TaskTableTableOrderingComposer,
    $$TaskTableTableAnnotationComposer,
    $$TaskTableTableCreateCompanionBuilder,
    $$TaskTableTableUpdateCompanionBuilder,
    (Task, BaseReferences<_$AppDatabase, $TaskTableTable, Task>),
    Task,
    PrefetchHooks Function()> {
  $$TaskTableTableTableManager(_$AppDatabase db, $TaskTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$TaskTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$TaskTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$TaskTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<DateTime> createdDate = const Value.absent(),
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<DateTime?> deletedDate = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<EisenhowerPriority?> priority = const Value.absent(),
            Value<DateTime?> plannedDate = const Value.absent(),
            Value<DateTime?> deadlineDate = const Value.absent(),
            Value<int?> estimatedTime = const Value.absent(),
            Value<int?> elapsedTime = const Value.absent(),
            Value<bool> isCompleted = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TaskTableCompanion(
            id: id,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            deletedDate: deletedDate,
            title: title,
            description: description,
            priority: priority,
            plannedDate: plannedDate,
            deadlineDate: deadlineDate,
            estimatedTime: estimatedTime,
            elapsedTime: elapsedTime,
            isCompleted: isCompleted,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required DateTime createdDate,
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<DateTime?> deletedDate = const Value.absent(),
            required String title,
            Value<String?> description = const Value.absent(),
            Value<EisenhowerPriority?> priority = const Value.absent(),
            Value<DateTime?> plannedDate = const Value.absent(),
            Value<DateTime?> deadlineDate = const Value.absent(),
            Value<int?> estimatedTime = const Value.absent(),
            Value<int?> elapsedTime = const Value.absent(),
            Value<bool> isCompleted = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TaskTableCompanion.insert(
            id: id,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            deletedDate: deletedDate,
            title: title,
            description: description,
            priority: priority,
            plannedDate: plannedDate,
            deadlineDate: deadlineDate,
            estimatedTime: estimatedTime,
            elapsedTime: elapsedTime,
            isCompleted: isCompleted,
            rowid: rowid,
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
    $$TaskTableTableAnnotationComposer,
    $$TaskTableTableCreateCompanionBuilder,
    $$TaskTableTableUpdateCompanionBuilder,
    (Task, BaseReferences<_$AppDatabase, $TaskTableTable, Task>),
    Task,
    PrefetchHooks Function()>;
typedef $$TaskTagTableTableCreateCompanionBuilder = TaskTagTableCompanion Function({
  required String id,
  required DateTime createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  required String taskId,
  required String tagId,
  Value<int> rowid,
});
typedef $$TaskTagTableTableUpdateCompanionBuilder = TaskTagTableCompanion Function({
  Value<String> id,
  Value<DateTime> createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  Value<String> taskId,
  Value<String> tagId,
  Value<int> rowid,
});

class $$TaskTagTableTableFilterComposer extends Composer<_$AppDatabase, $TaskTagTableTable> {
  $$TaskTagTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdDate =>
      $composableBuilder(column: $table.createdDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get modifiedDate =>
      $composableBuilder(column: $table.modifiedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedDate =>
      $composableBuilder(column: $table.deletedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tagId =>
      $composableBuilder(column: $table.tagId, builder: (column) => ColumnFilters(column));
}

class $$TaskTagTableTableOrderingComposer extends Composer<_$AppDatabase, $TaskTagTableTable> {
  $$TaskTagTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdDate =>
      $composableBuilder(column: $table.createdDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get modifiedDate =>
      $composableBuilder(column: $table.modifiedDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedDate =>
      $composableBuilder(column: $table.deletedDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tagId =>
      $composableBuilder(column: $table.tagId, builder: (column) => ColumnOrderings(column));
}

class $$TaskTagTableTableAnnotationComposer extends Composer<_$AppDatabase, $TaskTagTableTable> {
  $$TaskTagTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdDate =>
      $composableBuilder(column: $table.createdDate, builder: (column) => column);

  GeneratedColumn<DateTime> get modifiedDate =>
      $composableBuilder(column: $table.modifiedDate, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedDate =>
      $composableBuilder(column: $table.deletedDate, builder: (column) => column);

  GeneratedColumn<String> get taskId => $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<String> get tagId => $composableBuilder(column: $table.tagId, builder: (column) => column);
}

class $$TaskTagTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TaskTagTableTable,
    TaskTag,
    $$TaskTagTableTableFilterComposer,
    $$TaskTagTableTableOrderingComposer,
    $$TaskTagTableTableAnnotationComposer,
    $$TaskTagTableTableCreateCompanionBuilder,
    $$TaskTagTableTableUpdateCompanionBuilder,
    (TaskTag, BaseReferences<_$AppDatabase, $TaskTagTableTable, TaskTag>),
    TaskTag,
    PrefetchHooks Function()> {
  $$TaskTagTableTableTableManager(_$AppDatabase db, $TaskTagTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$TaskTagTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$TaskTagTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$TaskTagTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<DateTime> createdDate = const Value.absent(),
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<DateTime?> deletedDate = const Value.absent(),
            Value<String> taskId = const Value.absent(),
            Value<String> tagId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TaskTagTableCompanion(
            id: id,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            deletedDate: deletedDate,
            taskId: taskId,
            tagId: tagId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required DateTime createdDate,
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<DateTime?> deletedDate = const Value.absent(),
            required String taskId,
            required String tagId,
            Value<int> rowid = const Value.absent(),
          }) =>
              TaskTagTableCompanion.insert(
            id: id,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            deletedDate: deletedDate,
            taskId: taskId,
            tagId: tagId,
            rowid: rowid,
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
    $$TaskTagTableTableAnnotationComposer,
    $$TaskTagTableTableCreateCompanionBuilder,
    $$TaskTagTableTableUpdateCompanionBuilder,
    (TaskTag, BaseReferences<_$AppDatabase, $TaskTagTableTable, TaskTag>),
    TaskTag,
    PrefetchHooks Function()>;
typedef $$TagTableTableCreateCompanionBuilder = TagTableCompanion Function({
  required String id,
  required DateTime createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  required String name,
  Value<int> rowid,
});
typedef $$TagTableTableUpdateCompanionBuilder = TagTableCompanion Function({
  Value<String> id,
  Value<DateTime> createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  Value<String> name,
  Value<int> rowid,
});

class $$TagTableTableFilterComposer extends Composer<_$AppDatabase, $TagTableTable> {
  $$TagTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdDate =>
      $composableBuilder(column: $table.createdDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get modifiedDate =>
      $composableBuilder(column: $table.modifiedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedDate =>
      $composableBuilder(column: $table.deletedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(column: $table.name, builder: (column) => ColumnFilters(column));
}

class $$TagTableTableOrderingComposer extends Composer<_$AppDatabase, $TagTableTable> {
  $$TagTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdDate =>
      $composableBuilder(column: $table.createdDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get modifiedDate =>
      $composableBuilder(column: $table.modifiedDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedDate =>
      $composableBuilder(column: $table.deletedDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => ColumnOrderings(column));
}

class $$TagTableTableAnnotationComposer extends Composer<_$AppDatabase, $TagTableTable> {
  $$TagTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdDate =>
      $composableBuilder(column: $table.createdDate, builder: (column) => column);

  GeneratedColumn<DateTime> get modifiedDate =>
      $composableBuilder(column: $table.modifiedDate, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedDate =>
      $composableBuilder(column: $table.deletedDate, builder: (column) => column);

  GeneratedColumn<String> get name => $composableBuilder(column: $table.name, builder: (column) => column);
}

class $$TagTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TagTableTable,
    Tag,
    $$TagTableTableFilterComposer,
    $$TagTableTableOrderingComposer,
    $$TagTableTableAnnotationComposer,
    $$TagTableTableCreateCompanionBuilder,
    $$TagTableTableUpdateCompanionBuilder,
    (Tag, BaseReferences<_$AppDatabase, $TagTableTable, Tag>),
    Tag,
    PrefetchHooks Function()> {
  $$TagTableTableTableManager(_$AppDatabase db, $TagTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$TagTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$TagTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$TagTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<DateTime> createdDate = const Value.absent(),
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<DateTime?> deletedDate = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TagTableCompanion(
            id: id,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            deletedDate: deletedDate,
            name: name,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required DateTime createdDate,
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<DateTime?> deletedDate = const Value.absent(),
            required String name,
            Value<int> rowid = const Value.absent(),
          }) =>
              TagTableCompanion.insert(
            id: id,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            deletedDate: deletedDate,
            name: name,
            rowid: rowid,
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
    $$TagTableTableAnnotationComposer,
    $$TagTableTableCreateCompanionBuilder,
    $$TagTableTableUpdateCompanionBuilder,
    (Tag, BaseReferences<_$AppDatabase, $TagTableTable, Tag>),
    Tag,
    PrefetchHooks Function()>;
typedef $$TagTagTableTableCreateCompanionBuilder = TagTagTableCompanion Function({
  required String id,
  required DateTime createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  required String primaryTagId,
  required String secondaryTagId,
  Value<int> rowid,
});
typedef $$TagTagTableTableUpdateCompanionBuilder = TagTagTableCompanion Function({
  Value<String> id,
  Value<DateTime> createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  Value<String> primaryTagId,
  Value<String> secondaryTagId,
  Value<int> rowid,
});

class $$TagTagTableTableFilterComposer extends Composer<_$AppDatabase, $TagTagTableTable> {
  $$TagTagTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdDate =>
      $composableBuilder(column: $table.createdDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get modifiedDate =>
      $composableBuilder(column: $table.modifiedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedDate =>
      $composableBuilder(column: $table.deletedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get primaryTagId =>
      $composableBuilder(column: $table.primaryTagId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get secondaryTagId =>
      $composableBuilder(column: $table.secondaryTagId, builder: (column) => ColumnFilters(column));
}

class $$TagTagTableTableOrderingComposer extends Composer<_$AppDatabase, $TagTagTableTable> {
  $$TagTagTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdDate =>
      $composableBuilder(column: $table.createdDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get modifiedDate =>
      $composableBuilder(column: $table.modifiedDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedDate =>
      $composableBuilder(column: $table.deletedDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get primaryTagId =>
      $composableBuilder(column: $table.primaryTagId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get secondaryTagId =>
      $composableBuilder(column: $table.secondaryTagId, builder: (column) => ColumnOrderings(column));
}

class $$TagTagTableTableAnnotationComposer extends Composer<_$AppDatabase, $TagTagTableTable> {
  $$TagTagTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdDate =>
      $composableBuilder(column: $table.createdDate, builder: (column) => column);

  GeneratedColumn<DateTime> get modifiedDate =>
      $composableBuilder(column: $table.modifiedDate, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedDate =>
      $composableBuilder(column: $table.deletedDate, builder: (column) => column);

  GeneratedColumn<String> get primaryTagId =>
      $composableBuilder(column: $table.primaryTagId, builder: (column) => column);

  GeneratedColumn<String> get secondaryTagId =>
      $composableBuilder(column: $table.secondaryTagId, builder: (column) => column);
}

class $$TagTagTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TagTagTableTable,
    TagTag,
    $$TagTagTableTableFilterComposer,
    $$TagTagTableTableOrderingComposer,
    $$TagTagTableTableAnnotationComposer,
    $$TagTagTableTableCreateCompanionBuilder,
    $$TagTagTableTableUpdateCompanionBuilder,
    (TagTag, BaseReferences<_$AppDatabase, $TagTagTableTable, TagTag>),
    TagTag,
    PrefetchHooks Function()> {
  $$TagTagTableTableTableManager(_$AppDatabase db, $TagTagTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$TagTagTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$TagTagTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$TagTagTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<DateTime> createdDate = const Value.absent(),
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<DateTime?> deletedDate = const Value.absent(),
            Value<String> primaryTagId = const Value.absent(),
            Value<String> secondaryTagId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TagTagTableCompanion(
            id: id,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            deletedDate: deletedDate,
            primaryTagId: primaryTagId,
            secondaryTagId: secondaryTagId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required DateTime createdDate,
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<DateTime?> deletedDate = const Value.absent(),
            required String primaryTagId,
            required String secondaryTagId,
            Value<int> rowid = const Value.absent(),
          }) =>
              TagTagTableCompanion.insert(
            id: id,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            deletedDate: deletedDate,
            primaryTagId: primaryTagId,
            secondaryTagId: secondaryTagId,
            rowid: rowid,
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
    $$TagTagTableTableAnnotationComposer,
    $$TagTagTableTableCreateCompanionBuilder,
    $$TagTagTableTableUpdateCompanionBuilder,
    (TagTag, BaseReferences<_$AppDatabase, $TagTagTableTable, TagTag>),
    TagTag,
    PrefetchHooks Function()>;
typedef $$SettingTableTableCreateCompanionBuilder = SettingTableCompanion Function({
  required String id,
  required DateTime createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  required String key,
  required String value,
  required SettingValueType valueType,
  Value<int> rowid,
});
typedef $$SettingTableTableUpdateCompanionBuilder = SettingTableCompanion Function({
  Value<String> id,
  Value<DateTime> createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  Value<String> key,
  Value<String> value,
  Value<SettingValueType> valueType,
  Value<int> rowid,
});

class $$SettingTableTableFilterComposer extends Composer<_$AppDatabase, $SettingTableTable> {
  $$SettingTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdDate =>
      $composableBuilder(column: $table.createdDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get modifiedDate =>
      $composableBuilder(column: $table.modifiedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedDate =>
      $composableBuilder(column: $table.deletedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get key => $composableBuilder(column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<SettingValueType, SettingValueType, int> get valueType =>
      $composableBuilder(column: $table.valueType, builder: (column) => ColumnWithTypeConverterFilters(column));
}

class $$SettingTableTableOrderingComposer extends Composer<_$AppDatabase, $SettingTableTable> {
  $$SettingTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdDate =>
      $composableBuilder(column: $table.createdDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get modifiedDate =>
      $composableBuilder(column: $table.modifiedDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedDate =>
      $composableBuilder(column: $table.deletedDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get valueType =>
      $composableBuilder(column: $table.valueType, builder: (column) => ColumnOrderings(column));
}

class $$SettingTableTableAnnotationComposer extends Composer<_$AppDatabase, $SettingTableTable> {
  $$SettingTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdDate =>
      $composableBuilder(column: $table.createdDate, builder: (column) => column);

  GeneratedColumn<DateTime> get modifiedDate =>
      $composableBuilder(column: $table.modifiedDate, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedDate =>
      $composableBuilder(column: $table.deletedDate, builder: (column) => column);

  GeneratedColumn<String> get key => $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value => $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumnWithTypeConverter<SettingValueType, int> get valueType =>
      $composableBuilder(column: $table.valueType, builder: (column) => column);
}

class $$SettingTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SettingTableTable,
    Setting,
    $$SettingTableTableFilterComposer,
    $$SettingTableTableOrderingComposer,
    $$SettingTableTableAnnotationComposer,
    $$SettingTableTableCreateCompanionBuilder,
    $$SettingTableTableUpdateCompanionBuilder,
    (Setting, BaseReferences<_$AppDatabase, $SettingTableTable, Setting>),
    Setting,
    PrefetchHooks Function()> {
  $$SettingTableTableTableManager(_$AppDatabase db, $SettingTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$SettingTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$SettingTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$SettingTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<DateTime> createdDate = const Value.absent(),
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<DateTime?> deletedDate = const Value.absent(),
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<SettingValueType> valueType = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SettingTableCompanion(
            id: id,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            deletedDate: deletedDate,
            key: key,
            value: value,
            valueType: valueType,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required DateTime createdDate,
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<DateTime?> deletedDate = const Value.absent(),
            required String key,
            required String value,
            required SettingValueType valueType,
            Value<int> rowid = const Value.absent(),
          }) =>
              SettingTableCompanion.insert(
            id: id,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            deletedDate: deletedDate,
            key: key,
            value: value,
            valueType: valueType,
            rowid: rowid,
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
    $$SettingTableTableAnnotationComposer,
    $$SettingTableTableCreateCompanionBuilder,
    $$SettingTableTableUpdateCompanionBuilder,
    (Setting, BaseReferences<_$AppDatabase, $SettingTableTable, Setting>),
    Setting,
    PrefetchHooks Function()>;
typedef $$SyncDeviceTableTableCreateCompanionBuilder = SyncDeviceTableCompanion Function({
  required String id,
  required DateTime createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  required String fromIp,
  required String toIp,
  Value<String?> name,
  Value<DateTime?> lastSyncDate,
  Value<int> rowid,
});
typedef $$SyncDeviceTableTableUpdateCompanionBuilder = SyncDeviceTableCompanion Function({
  Value<String> id,
  Value<DateTime> createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  Value<String> fromIp,
  Value<String> toIp,
  Value<String?> name,
  Value<DateTime?> lastSyncDate,
  Value<int> rowid,
});

class $$SyncDeviceTableTableFilterComposer extends Composer<_$AppDatabase, $SyncDeviceTableTable> {
  $$SyncDeviceTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdDate =>
      $composableBuilder(column: $table.createdDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get modifiedDate =>
      $composableBuilder(column: $table.modifiedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedDate =>
      $composableBuilder(column: $table.deletedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fromIp =>
      $composableBuilder(column: $table.fromIp, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get toIp => $composableBuilder(column: $table.toIp, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastSyncDate =>
      $composableBuilder(column: $table.lastSyncDate, builder: (column) => ColumnFilters(column));
}

class $$SyncDeviceTableTableOrderingComposer extends Composer<_$AppDatabase, $SyncDeviceTableTable> {
  $$SyncDeviceTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdDate =>
      $composableBuilder(column: $table.createdDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get modifiedDate =>
      $composableBuilder(column: $table.modifiedDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedDate =>
      $composableBuilder(column: $table.deletedDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fromIp =>
      $composableBuilder(column: $table.fromIp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get toIp =>
      $composableBuilder(column: $table.toIp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastSyncDate =>
      $composableBuilder(column: $table.lastSyncDate, builder: (column) => ColumnOrderings(column));
}

class $$SyncDeviceTableTableAnnotationComposer extends Composer<_$AppDatabase, $SyncDeviceTableTable> {
  $$SyncDeviceTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdDate =>
      $composableBuilder(column: $table.createdDate, builder: (column) => column);

  GeneratedColumn<DateTime> get modifiedDate =>
      $composableBuilder(column: $table.modifiedDate, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedDate =>
      $composableBuilder(column: $table.deletedDate, builder: (column) => column);

  GeneratedColumn<String> get fromIp => $composableBuilder(column: $table.fromIp, builder: (column) => column);

  GeneratedColumn<String> get toIp => $composableBuilder(column: $table.toIp, builder: (column) => column);

  GeneratedColumn<String> get name => $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSyncDate =>
      $composableBuilder(column: $table.lastSyncDate, builder: (column) => column);
}

class $$SyncDeviceTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SyncDeviceTableTable,
    SyncDevice,
    $$SyncDeviceTableTableFilterComposer,
    $$SyncDeviceTableTableOrderingComposer,
    $$SyncDeviceTableTableAnnotationComposer,
    $$SyncDeviceTableTableCreateCompanionBuilder,
    $$SyncDeviceTableTableUpdateCompanionBuilder,
    (SyncDevice, BaseReferences<_$AppDatabase, $SyncDeviceTableTable, SyncDevice>),
    SyncDevice,
    PrefetchHooks Function()> {
  $$SyncDeviceTableTableTableManager(_$AppDatabase db, $SyncDeviceTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$SyncDeviceTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$SyncDeviceTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$SyncDeviceTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<DateTime> createdDate = const Value.absent(),
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<DateTime?> deletedDate = const Value.absent(),
            Value<String> fromIp = const Value.absent(),
            Value<String> toIp = const Value.absent(),
            Value<String?> name = const Value.absent(),
            Value<DateTime?> lastSyncDate = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncDeviceTableCompanion(
            id: id,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            deletedDate: deletedDate,
            fromIp: fromIp,
            toIp: toIp,
            name: name,
            lastSyncDate: lastSyncDate,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required DateTime createdDate,
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<DateTime?> deletedDate = const Value.absent(),
            required String fromIp,
            required String toIp,
            Value<String?> name = const Value.absent(),
            Value<DateTime?> lastSyncDate = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncDeviceTableCompanion.insert(
            id: id,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            deletedDate: deletedDate,
            fromIp: fromIp,
            toIp: toIp,
            name: name,
            lastSyncDate: lastSyncDate,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncDeviceTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SyncDeviceTableTable,
    SyncDevice,
    $$SyncDeviceTableTableFilterComposer,
    $$SyncDeviceTableTableOrderingComposer,
    $$SyncDeviceTableTableAnnotationComposer,
    $$SyncDeviceTableTableCreateCompanionBuilder,
    $$SyncDeviceTableTableUpdateCompanionBuilder,
    (SyncDevice, BaseReferences<_$AppDatabase, $SyncDeviceTableTable, SyncDevice>),
    SyncDevice,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AppUsageTableTableTableManager get appUsageTable => $$AppUsageTableTableTableManager(_db, _db.appUsageTable);
  $$AppUsageTagTableTableTableManager get appUsageTagTable =>
      $$AppUsageTagTableTableTableManager(_db, _db.appUsageTagTable);
  $$HabitTableTableTableManager get habitTable => $$HabitTableTableTableManager(_db, _db.habitTable);
  $$HabitTagTableTableTableManager get habitTagTable => $$HabitTagTableTableTableManager(_db, _db.habitTagTable);
  $$HabitRecordTableTableTableManager get habitRecordTable =>
      $$HabitRecordTableTableTableManager(_db, _db.habitRecordTable);
  $$TaskTableTableTableManager get taskTable => $$TaskTableTableTableManager(_db, _db.taskTable);
  $$TaskTagTableTableTableManager get taskTagTable => $$TaskTagTableTableTableManager(_db, _db.taskTagTable);
  $$TagTableTableTableManager get tagTable => $$TagTableTableTableManager(_db, _db.tagTable);
  $$TagTagTableTableTableManager get tagTagTable => $$TagTagTableTableTableManager(_db, _db.tagTagTable);
  $$SettingTableTableTableManager get settingTable => $$SettingTableTableTableManager(_db, _db.settingTable);
  $$SyncDeviceTableTableTableManager get syncDeviceTable =>
      $$SyncDeviceTableTableTableManager(_db, _db.syncDeviceTable);
}

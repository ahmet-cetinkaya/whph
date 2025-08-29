// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'drift_app_context.dart';

// ignore_for_file: type=lint
class $AppUsageIgnoreRuleTableTable extends AppUsageIgnoreRuleTable
    with TableInfo<$AppUsageIgnoreRuleTableTable, AppUsageIgnoreRule> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppUsageIgnoreRuleTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _patternMeta =
      const VerificationMeta('pattern');
  @override
  late final GeneratedColumn<String> pattern = GeneratedColumn<String>(
      'pattern', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdDateMeta =
      const VerificationMeta('createdDate');
  @override
  late final GeneratedColumn<DateTime> createdDate = GeneratedColumn<DateTime>(
      'created_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _modifiedDateMeta =
      const VerificationMeta('modifiedDate');
  @override
  late final GeneratedColumn<DateTime> modifiedDate = GeneratedColumn<DateTime>(
      'modified_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deletedDateMeta =
      const VerificationMeta('deletedDate');
  @override
  late final GeneratedColumn<DateTime> deletedDate = GeneratedColumn<DateTime>(
      'deleted_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, pattern, description, createdDate, modifiedDate, deletedDate];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_usage_ignore_rule_table';
  @override
  VerificationContext validateIntegrity(Insertable<AppUsageIgnoreRule> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('pattern')) {
      context.handle(_patternMeta,
          pattern.isAcceptableOrUnknown(data['pattern']!, _patternMeta));
    } else if (isInserting) {
      context.missing(_patternMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('created_date')) {
      context.handle(
          _createdDateMeta,
          createdDate.isAcceptableOrUnknown(
              data['created_date']!, _createdDateMeta));
    } else if (isInserting) {
      context.missing(_createdDateMeta);
    }
    if (data.containsKey('modified_date')) {
      context.handle(
          _modifiedDateMeta,
          modifiedDate.isAcceptableOrUnknown(
              data['modified_date']!, _modifiedDateMeta));
    }
    if (data.containsKey('deleted_date')) {
      context.handle(
          _deletedDateMeta,
          deletedDate.isAcceptableOrUnknown(
              data['deleted_date']!, _deletedDateMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppUsageIgnoreRule map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppUsageIgnoreRule(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      createdDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_date'])!,
      modifiedDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}modified_date']),
      deletedDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_date']),
      pattern: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}pattern'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
    );
  }

  @override
  $AppUsageIgnoreRuleTableTable createAlias(String alias) {
    return $AppUsageIgnoreRuleTableTable(attachedDatabase, alias);
  }
}

class AppUsageIgnoreRuleTableCompanion
    extends UpdateCompanion<AppUsageIgnoreRule> {
  final Value<String> id;
  final Value<String> pattern;
  final Value<String?> description;
  final Value<DateTime> createdDate;
  final Value<DateTime?> modifiedDate;
  final Value<DateTime?> deletedDate;
  final Value<int> rowid;
  const AppUsageIgnoreRuleTableCompanion({
    this.id = const Value.absent(),
    this.pattern = const Value.absent(),
    this.description = const Value.absent(),
    this.createdDate = const Value.absent(),
    this.modifiedDate = const Value.absent(),
    this.deletedDate = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppUsageIgnoreRuleTableCompanion.insert({
    required String id,
    required String pattern,
    this.description = const Value.absent(),
    required DateTime createdDate,
    this.modifiedDate = const Value.absent(),
    this.deletedDate = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        pattern = Value(pattern),
        createdDate = Value(createdDate);
  static Insertable<AppUsageIgnoreRule> custom({
    Expression<String>? id,
    Expression<String>? pattern,
    Expression<String>? description,
    Expression<DateTime>? createdDate,
    Expression<DateTime>? modifiedDate,
    Expression<DateTime>? deletedDate,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (pattern != null) 'pattern': pattern,
      if (description != null) 'description': description,
      if (createdDate != null) 'created_date': createdDate,
      if (modifiedDate != null) 'modified_date': modifiedDate,
      if (deletedDate != null) 'deleted_date': deletedDate,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppUsageIgnoreRuleTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? pattern,
      Value<String?>? description,
      Value<DateTime>? createdDate,
      Value<DateTime?>? modifiedDate,
      Value<DateTime?>? deletedDate,
      Value<int>? rowid}) {
    return AppUsageIgnoreRuleTableCompanion(
      id: id ?? this.id,
      pattern: pattern ?? this.pattern,
      description: description ?? this.description,
      createdDate: createdDate ?? this.createdDate,
      modifiedDate: modifiedDate ?? this.modifiedDate,
      deletedDate: deletedDate ?? this.deletedDate,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (pattern.present) {
      map['pattern'] = Variable<String>(pattern.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
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
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppUsageIgnoreRuleTableCompanion(')
          ..write('id: $id, ')
          ..write('pattern: $pattern, ')
          ..write('description: $description, ')
          ..write('createdDate: $createdDate, ')
          ..write('modifiedDate: $modifiedDate, ')
          ..write('deletedDate: $deletedDate, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppUsageTableTable extends AppUsageTable
    with TableInfo<$AppUsageTableTable, AppUsage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppUsageTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdDateMeta =
      const VerificationMeta('createdDate');
  @override
  late final GeneratedColumn<DateTime> createdDate = GeneratedColumn<DateTime>(
      'created_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _modifiedDateMeta =
      const VerificationMeta('modifiedDate');
  @override
  late final GeneratedColumn<DateTime> modifiedDate = GeneratedColumn<DateTime>(
      'modified_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deletedDateMeta =
      const VerificationMeta('deletedDate');
  @override
  late final GeneratedColumn<DateTime> deletedDate = GeneratedColumn<DateTime>(
      'deleted_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _displayNameMeta =
      const VerificationMeta('displayName');
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
      'display_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
      'color', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _deviceNameMeta =
      const VerificationMeta('deviceName');
  @override
  late final GeneratedColumn<String> deviceName = GeneratedColumn<String>(
      'device_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        createdDate,
        modifiedDate,
        deletedDate,
        name,
        displayName,
        color,
        deviceName
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_usage_table';
  @override
  VerificationContext validateIntegrity(Insertable<AppUsage> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_date')) {
      context.handle(
          _createdDateMeta,
          createdDate.isAcceptableOrUnknown(
              data['created_date']!, _createdDateMeta));
    } else if (isInserting) {
      context.missing(_createdDateMeta);
    }
    if (data.containsKey('modified_date')) {
      context.handle(
          _modifiedDateMeta,
          modifiedDate.isAcceptableOrUnknown(
              data['modified_date']!, _modifiedDateMeta));
    }
    if (data.containsKey('deleted_date')) {
      context.handle(
          _deletedDateMeta,
          deletedDate.isAcceptableOrUnknown(
              data['deleted_date']!, _deletedDateMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
          _displayNameMeta,
          displayName.isAcceptableOrUnknown(
              data['display_name']!, _displayNameMeta));
    }
    if (data.containsKey('color')) {
      context.handle(
          _colorMeta, color.isAcceptableOrUnknown(data['color']!, _colorMeta));
    }
    if (data.containsKey('device_name')) {
      context.handle(
          _deviceNameMeta,
          deviceName.isAcceptableOrUnknown(
              data['device_name']!, _deviceNameMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppUsage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppUsage(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      createdDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_date'])!,
      modifiedDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}modified_date']),
      deletedDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_date']),
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      displayName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}display_name']),
      color: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}color']),
      deviceName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_name']),
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
  final Value<String?> deviceName;
  final Value<int> rowid;
  const AppUsageTableCompanion({
    this.id = const Value.absent(),
    this.createdDate = const Value.absent(),
    this.modifiedDate = const Value.absent(),
    this.deletedDate = const Value.absent(),
    this.name = const Value.absent(),
    this.displayName = const Value.absent(),
    this.color = const Value.absent(),
    this.deviceName = const Value.absent(),
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
    this.deviceName = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        createdDate = Value(createdDate),
        name = Value(name);
  static Insertable<AppUsage> custom({
    Expression<String>? id,
    Expression<DateTime>? createdDate,
    Expression<DateTime>? modifiedDate,
    Expression<DateTime>? deletedDate,
    Expression<String>? name,
    Expression<String>? displayName,
    Expression<String>? color,
    Expression<String>? deviceName,
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
      if (deviceName != null) 'device_name': deviceName,
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
      Value<String?>? deviceName,
      Value<int>? rowid}) {
    return AppUsageTableCompanion(
      id: id ?? this.id,
      createdDate: createdDate ?? this.createdDate,
      modifiedDate: modifiedDate ?? this.modifiedDate,
      deletedDate: deletedDate ?? this.deletedDate,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      color: color ?? this.color,
      deviceName: deviceName ?? this.deviceName,
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
    if (deviceName.present) {
      map['device_name'] = Variable<String>(deviceName.value);
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
          ..write('deviceName: $deviceName, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppUsageTagRuleTableTable extends AppUsageTagRuleTable
    with TableInfo<$AppUsageTagRuleTableTable, AppUsageTagRule> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppUsageTagRuleTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _patternMeta =
      const VerificationMeta('pattern');
  @override
  late final GeneratedColumn<String> pattern = GeneratedColumn<String>(
      'pattern', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<String> tagId = GeneratedColumn<String>(
      'tag_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdDateMeta =
      const VerificationMeta('createdDate');
  @override
  late final GeneratedColumn<DateTime> createdDate = GeneratedColumn<DateTime>(
      'created_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _modifiedDateMeta =
      const VerificationMeta('modifiedDate');
  @override
  late final GeneratedColumn<DateTime> modifiedDate = GeneratedColumn<DateTime>(
      'modified_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deletedDateMeta =
      const VerificationMeta('deletedDate');
  @override
  late final GeneratedColumn<DateTime> deletedDate = GeneratedColumn<DateTime>(
      'deleted_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, pattern, tagId, description, createdDate, modifiedDate, deletedDate];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_usage_tag_rule_table';
  @override
  VerificationContext validateIntegrity(Insertable<AppUsageTagRule> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('pattern')) {
      context.handle(_patternMeta,
          pattern.isAcceptableOrUnknown(data['pattern']!, _patternMeta));
    } else if (isInserting) {
      context.missing(_patternMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
          _tagIdMeta, tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta));
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('created_date')) {
      context.handle(
          _createdDateMeta,
          createdDate.isAcceptableOrUnknown(
              data['created_date']!, _createdDateMeta));
    } else if (isInserting) {
      context.missing(_createdDateMeta);
    }
    if (data.containsKey('modified_date')) {
      context.handle(
          _modifiedDateMeta,
          modifiedDate.isAcceptableOrUnknown(
              data['modified_date']!, _modifiedDateMeta));
    }
    if (data.containsKey('deleted_date')) {
      context.handle(
          _deletedDateMeta,
          deletedDate.isAcceptableOrUnknown(
              data['deleted_date']!, _deletedDateMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppUsageTagRule map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppUsageTagRule(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      createdDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_date'])!,
      modifiedDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}modified_date']),
      deletedDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_date']),
      pattern: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}pattern'])!,
      tagId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tag_id'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
    );
  }

  @override
  $AppUsageTagRuleTableTable createAlias(String alias) {
    return $AppUsageTagRuleTableTable(attachedDatabase, alias);
  }
}

class AppUsageTagRuleTableCompanion extends UpdateCompanion<AppUsageTagRule> {
  final Value<String> id;
  final Value<String> pattern;
  final Value<String> tagId;
  final Value<String?> description;
  final Value<DateTime> createdDate;
  final Value<DateTime?> modifiedDate;
  final Value<DateTime?> deletedDate;
  final Value<int> rowid;
  const AppUsageTagRuleTableCompanion({
    this.id = const Value.absent(),
    this.pattern = const Value.absent(),
    this.tagId = const Value.absent(),
    this.description = const Value.absent(),
    this.createdDate = const Value.absent(),
    this.modifiedDate = const Value.absent(),
    this.deletedDate = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppUsageTagRuleTableCompanion.insert({
    required String id,
    required String pattern,
    required String tagId,
    this.description = const Value.absent(),
    required DateTime createdDate,
    this.modifiedDate = const Value.absent(),
    this.deletedDate = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        pattern = Value(pattern),
        tagId = Value(tagId),
        createdDate = Value(createdDate);
  static Insertable<AppUsageTagRule> custom({
    Expression<String>? id,
    Expression<String>? pattern,
    Expression<String>? tagId,
    Expression<String>? description,
    Expression<DateTime>? createdDate,
    Expression<DateTime>? modifiedDate,
    Expression<DateTime>? deletedDate,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (pattern != null) 'pattern': pattern,
      if (tagId != null) 'tag_id': tagId,
      if (description != null) 'description': description,
      if (createdDate != null) 'created_date': createdDate,
      if (modifiedDate != null) 'modified_date': modifiedDate,
      if (deletedDate != null) 'deleted_date': deletedDate,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppUsageTagRuleTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? pattern,
      Value<String>? tagId,
      Value<String?>? description,
      Value<DateTime>? createdDate,
      Value<DateTime?>? modifiedDate,
      Value<DateTime?>? deletedDate,
      Value<int>? rowid}) {
    return AppUsageTagRuleTableCompanion(
      id: id ?? this.id,
      pattern: pattern ?? this.pattern,
      tagId: tagId ?? this.tagId,
      description: description ?? this.description,
      createdDate: createdDate ?? this.createdDate,
      modifiedDate: modifiedDate ?? this.modifiedDate,
      deletedDate: deletedDate ?? this.deletedDate,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (pattern.present) {
      map['pattern'] = Variable<String>(pattern.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<String>(tagId.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
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
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppUsageTagRuleTableCompanion(')
          ..write('id: $id, ')
          ..write('pattern: $pattern, ')
          ..write('tagId: $tagId, ')
          ..write('description: $description, ')
          ..write('createdDate: $createdDate, ')
          ..write('modifiedDate: $modifiedDate, ')
          ..write('deletedDate: $deletedDate, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppUsageTagTableTable extends AppUsageTagTable
    with TableInfo<$AppUsageTagTableTable, AppUsageTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppUsageTagTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdDateMeta =
      const VerificationMeta('createdDate');
  @override
  late final GeneratedColumn<DateTime> createdDate = GeneratedColumn<DateTime>(
      'created_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _modifiedDateMeta =
      const VerificationMeta('modifiedDate');
  @override
  late final GeneratedColumn<DateTime> modifiedDate = GeneratedColumn<DateTime>(
      'modified_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deletedDateMeta =
      const VerificationMeta('deletedDate');
  @override
  late final GeneratedColumn<DateTime> deletedDate = GeneratedColumn<DateTime>(
      'deleted_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _appUsageIdMeta =
      const VerificationMeta('appUsageId');
  @override
  late final GeneratedColumn<String> appUsageId = GeneratedColumn<String>(
      'app_usage_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<String> tagId = GeneratedColumn<String>(
      'tag_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, createdDate, modifiedDate, deletedDate, appUsageId, tagId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_usage_tag_table';
  @override
  VerificationContext validateIntegrity(Insertable<AppUsageTag> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_date')) {
      context.handle(
          _createdDateMeta,
          createdDate.isAcceptableOrUnknown(
              data['created_date']!, _createdDateMeta));
    } else if (isInserting) {
      context.missing(_createdDateMeta);
    }
    if (data.containsKey('modified_date')) {
      context.handle(
          _modifiedDateMeta,
          modifiedDate.isAcceptableOrUnknown(
              data['modified_date']!, _modifiedDateMeta));
    }
    if (data.containsKey('deleted_date')) {
      context.handle(
          _deletedDateMeta,
          deletedDate.isAcceptableOrUnknown(
              data['deleted_date']!, _deletedDateMeta));
    }
    if (data.containsKey('app_usage_id')) {
      context.handle(
          _appUsageIdMeta,
          appUsageId.isAcceptableOrUnknown(
              data['app_usage_id']!, _appUsageIdMeta));
    } else if (isInserting) {
      context.missing(_appUsageIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
          _tagIdMeta, tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta));
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
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      createdDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_date'])!,
      modifiedDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}modified_date']),
      deletedDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_date']),
      appUsageId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}app_usage_id'])!,
      tagId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tag_id'])!,
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

class $AppUsageTimeRecordTableTable extends AppUsageTimeRecordTable
    with TableInfo<$AppUsageTimeRecordTableTable, AppUsageTimeRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppUsageTimeRecordTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _appUsageIdMeta =
      const VerificationMeta('appUsageId');
  @override
  late final GeneratedColumn<String> appUsageId = GeneratedColumn<String>(
      'app_usage_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _durationMeta =
      const VerificationMeta('duration');
  @override
  late final GeneratedColumn<int> duration = GeneratedColumn<int>(
      'duration', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _usageDateMeta =
      const VerificationMeta('usageDate');
  @override
  late final GeneratedColumn<DateTime> usageDate = GeneratedColumn<DateTime>(
      'usage_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _createdDateMeta =
      const VerificationMeta('createdDate');
  @override
  late final GeneratedColumn<DateTime> createdDate = GeneratedColumn<DateTime>(
      'created_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _modifiedDateMeta =
      const VerificationMeta('modifiedDate');
  @override
  late final GeneratedColumn<DateTime> modifiedDate = GeneratedColumn<DateTime>(
      'modified_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deletedDateMeta =
      const VerificationMeta('deletedDate');
  @override
  late final GeneratedColumn<DateTime> deletedDate = GeneratedColumn<DateTime>(
      'deleted_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        appUsageId,
        duration,
        usageDate,
        createdDate,
        modifiedDate,
        deletedDate
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_usage_time_record_table';
  @override
  VerificationContext validateIntegrity(Insertable<AppUsageTimeRecord> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('app_usage_id')) {
      context.handle(
          _appUsageIdMeta,
          appUsageId.isAcceptableOrUnknown(
              data['app_usage_id']!, _appUsageIdMeta));
    } else if (isInserting) {
      context.missing(_appUsageIdMeta);
    }
    if (data.containsKey('duration')) {
      context.handle(_durationMeta,
          duration.isAcceptableOrUnknown(data['duration']!, _durationMeta));
    } else if (isInserting) {
      context.missing(_durationMeta);
    }
    if (data.containsKey('usage_date')) {
      context.handle(_usageDateMeta,
          usageDate.isAcceptableOrUnknown(data['usage_date']!, _usageDateMeta));
    } else if (isInserting) {
      context.missing(_usageDateMeta);
    }
    if (data.containsKey('created_date')) {
      context.handle(
          _createdDateMeta,
          createdDate.isAcceptableOrUnknown(
              data['created_date']!, _createdDateMeta));
    } else if (isInserting) {
      context.missing(_createdDateMeta);
    }
    if (data.containsKey('modified_date')) {
      context.handle(
          _modifiedDateMeta,
          modifiedDate.isAcceptableOrUnknown(
              data['modified_date']!, _modifiedDateMeta));
    }
    if (data.containsKey('deleted_date')) {
      context.handle(
          _deletedDateMeta,
          deletedDate.isAcceptableOrUnknown(
              data['deleted_date']!, _deletedDateMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppUsageTimeRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppUsageTimeRecord(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      createdDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_date'])!,
      modifiedDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}modified_date']),
      deletedDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_date']),
      appUsageId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}app_usage_id'])!,
      duration: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration'])!,
      usageDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}usage_date'])!,
    );
  }

  @override
  $AppUsageTimeRecordTableTable createAlias(String alias) {
    return $AppUsageTimeRecordTableTable(attachedDatabase, alias);
  }
}

class AppUsageTimeRecordTableCompanion
    extends UpdateCompanion<AppUsageTimeRecord> {
  final Value<String> id;
  final Value<String> appUsageId;
  final Value<int> duration;
  final Value<DateTime> usageDate;
  final Value<DateTime> createdDate;
  final Value<DateTime?> modifiedDate;
  final Value<DateTime?> deletedDate;
  final Value<int> rowid;
  const AppUsageTimeRecordTableCompanion({
    this.id = const Value.absent(),
    this.appUsageId = const Value.absent(),
    this.duration = const Value.absent(),
    this.usageDate = const Value.absent(),
    this.createdDate = const Value.absent(),
    this.modifiedDate = const Value.absent(),
    this.deletedDate = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppUsageTimeRecordTableCompanion.insert({
    required String id,
    required String appUsageId,
    required int duration,
    required DateTime usageDate,
    required DateTime createdDate,
    this.modifiedDate = const Value.absent(),
    this.deletedDate = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        appUsageId = Value(appUsageId),
        duration = Value(duration),
        usageDate = Value(usageDate),
        createdDate = Value(createdDate);
  static Insertable<AppUsageTimeRecord> custom({
    Expression<String>? id,
    Expression<String>? appUsageId,
    Expression<int>? duration,
    Expression<DateTime>? usageDate,
    Expression<DateTime>? createdDate,
    Expression<DateTime>? modifiedDate,
    Expression<DateTime>? deletedDate,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (appUsageId != null) 'app_usage_id': appUsageId,
      if (duration != null) 'duration': duration,
      if (usageDate != null) 'usage_date': usageDate,
      if (createdDate != null) 'created_date': createdDate,
      if (modifiedDate != null) 'modified_date': modifiedDate,
      if (deletedDate != null) 'deleted_date': deletedDate,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppUsageTimeRecordTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? appUsageId,
      Value<int>? duration,
      Value<DateTime>? usageDate,
      Value<DateTime>? createdDate,
      Value<DateTime?>? modifiedDate,
      Value<DateTime?>? deletedDate,
      Value<int>? rowid}) {
    return AppUsageTimeRecordTableCompanion(
      id: id ?? this.id,
      appUsageId: appUsageId ?? this.appUsageId,
      duration: duration ?? this.duration,
      usageDate: usageDate ?? this.usageDate,
      createdDate: createdDate ?? this.createdDate,
      modifiedDate: modifiedDate ?? this.modifiedDate,
      deletedDate: deletedDate ?? this.deletedDate,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (appUsageId.present) {
      map['app_usage_id'] = Variable<String>(appUsageId.value);
    }
    if (duration.present) {
      map['duration'] = Variable<int>(duration.value);
    }
    if (usageDate.present) {
      map['usage_date'] = Variable<DateTime>(usageDate.value);
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
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppUsageTimeRecordTableCompanion(')
          ..write('id: $id, ')
          ..write('appUsageId: $appUsageId, ')
          ..write('duration: $duration, ')
          ..write('usageDate: $usageDate, ')
          ..write('createdDate: $createdDate, ')
          ..write('modifiedDate: $modifiedDate, ')
          ..write('deletedDate: $deletedDate, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HabitRecordTableTable extends HabitRecordTable
    with TableInfo<$HabitRecordTableTable, HabitRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HabitRecordTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdDateMeta =
      const VerificationMeta('createdDate');
  @override
  late final GeneratedColumn<DateTime> createdDate = GeneratedColumn<DateTime>(
      'created_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _modifiedDateMeta =
      const VerificationMeta('modifiedDate');
  @override
  late final GeneratedColumn<DateTime> modifiedDate = GeneratedColumn<DateTime>(
      'modified_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deletedDateMeta =
      const VerificationMeta('deletedDate');
  @override
  late final GeneratedColumn<DateTime> deletedDate = GeneratedColumn<DateTime>(
      'deleted_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _habitIdMeta =
      const VerificationMeta('habitId');
  @override
  late final GeneratedColumn<String> habitId = GeneratedColumn<String>(
      'habit_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
      'date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, createdDate, modifiedDate, deletedDate, habitId, date];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'habit_record_table';
  @override
  VerificationContext validateIntegrity(Insertable<HabitRecord> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_date')) {
      context.handle(
          _createdDateMeta,
          createdDate.isAcceptableOrUnknown(
              data['created_date']!, _createdDateMeta));
    } else if (isInserting) {
      context.missing(_createdDateMeta);
    }
    if (data.containsKey('modified_date')) {
      context.handle(
          _modifiedDateMeta,
          modifiedDate.isAcceptableOrUnknown(
              data['modified_date']!, _modifiedDateMeta));
    }
    if (data.containsKey('deleted_date')) {
      context.handle(
          _deletedDateMeta,
          deletedDate.isAcceptableOrUnknown(
              data['deleted_date']!, _deletedDateMeta));
    }
    if (data.containsKey('habit_id')) {
      context.handle(_habitIdMeta,
          habitId.isAcceptableOrUnknown(data['habit_id']!, _habitIdMeta));
    } else if (isInserting) {
      context.missing(_habitIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
          _dateMeta, date.isAcceptableOrUnknown(data['date']!, _dateMeta));
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
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      createdDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_date'])!,
      modifiedDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}modified_date']),
      deletedDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_date']),
      habitId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}habit_id'])!,
      date: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}date'])!,
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

class $HabitTableTable extends HabitTable
    with TableInfo<$HabitTableTable, Habit> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HabitTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdDateMeta =
      const VerificationMeta('createdDate');
  @override
  late final GeneratedColumn<DateTime> createdDate = GeneratedColumn<DateTime>(
      'created_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _modifiedDateMeta =
      const VerificationMeta('modifiedDate');
  @override
  late final GeneratedColumn<DateTime> modifiedDate = GeneratedColumn<DateTime>(
      'modified_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deletedDateMeta =
      const VerificationMeta('deletedDate');
  @override
  late final GeneratedColumn<DateTime> deletedDate = GeneratedColumn<DateTime>(
      'deleted_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _estimatedTimeMeta =
      const VerificationMeta('estimatedTime');
  @override
  late final GeneratedColumn<int> estimatedTime = GeneratedColumn<int>(
      'estimated_time', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _archivedDateMeta =
      const VerificationMeta('archivedDate');
  @override
  late final GeneratedColumn<DateTime> archivedDate = GeneratedColumn<DateTime>(
      'archived_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _hasReminderMeta =
      const VerificationMeta('hasReminder');
  @override
  late final GeneratedColumn<bool> hasReminder = GeneratedColumn<bool>(
      'has_reminder', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("has_reminder" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _reminderTimeMeta =
      const VerificationMeta('reminderTime');
  @override
  late final GeneratedColumn<String> reminderTime = GeneratedColumn<String>(
      'reminder_time', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _reminderDaysMeta =
      const VerificationMeta('reminderDays');
  @override
  late final GeneratedColumn<String> reminderDays = GeneratedColumn<String>(
      'reminder_days', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _hasGoalMeta =
      const VerificationMeta('hasGoal');
  @override
  late final GeneratedColumn<bool> hasGoal = GeneratedColumn<bool>(
      'has_goal', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("has_goal" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _targetFrequencyMeta =
      const VerificationMeta('targetFrequency');
  @override
  late final GeneratedColumn<int> targetFrequency = GeneratedColumn<int>(
      'target_frequency', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _periodDaysMeta =
      const VerificationMeta('periodDays');
  @override
  late final GeneratedColumn<int> periodDays = GeneratedColumn<int>(
      'period_days', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(7));
  static const VerificationMeta _orderMeta = const VerificationMeta('order');
  @override
  late final GeneratedColumn<double> order = GeneratedColumn<double>(
      'order', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        createdDate,
        modifiedDate,
        deletedDate,
        name,
        description,
        estimatedTime,
        archivedDate,
        hasReminder,
        reminderTime,
        reminderDays,
        hasGoal,
        targetFrequency,
        periodDays,
        order
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'habit_table';
  @override
  VerificationContext validateIntegrity(Insertable<Habit> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_date')) {
      context.handle(
          _createdDateMeta,
          createdDate.isAcceptableOrUnknown(
              data['created_date']!, _createdDateMeta));
    } else if (isInserting) {
      context.missing(_createdDateMeta);
    }
    if (data.containsKey('modified_date')) {
      context.handle(
          _modifiedDateMeta,
          modifiedDate.isAcceptableOrUnknown(
              data['modified_date']!, _modifiedDateMeta));
    }
    if (data.containsKey('deleted_date')) {
      context.handle(
          _deletedDateMeta,
          deletedDate.isAcceptableOrUnknown(
              data['deleted_date']!, _deletedDateMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('estimated_time')) {
      context.handle(
          _estimatedTimeMeta,
          estimatedTime.isAcceptableOrUnknown(
              data['estimated_time']!, _estimatedTimeMeta));
    }
    if (data.containsKey('archived_date')) {
      context.handle(
          _archivedDateMeta,
          archivedDate.isAcceptableOrUnknown(
              data['archived_date']!, _archivedDateMeta));
    }
    if (data.containsKey('has_reminder')) {
      context.handle(
          _hasReminderMeta,
          hasReminder.isAcceptableOrUnknown(
              data['has_reminder']!, _hasReminderMeta));
    }
    if (data.containsKey('reminder_time')) {
      context.handle(
          _reminderTimeMeta,
          reminderTime.isAcceptableOrUnknown(
              data['reminder_time']!, _reminderTimeMeta));
    }
    if (data.containsKey('reminder_days')) {
      context.handle(
          _reminderDaysMeta,
          reminderDays.isAcceptableOrUnknown(
              data['reminder_days']!, _reminderDaysMeta));
    }
    if (data.containsKey('has_goal')) {
      context.handle(_hasGoalMeta,
          hasGoal.isAcceptableOrUnknown(data['has_goal']!, _hasGoalMeta));
    }
    if (data.containsKey('target_frequency')) {
      context.handle(
          _targetFrequencyMeta,
          targetFrequency.isAcceptableOrUnknown(
              data['target_frequency']!, _targetFrequencyMeta));
    }
    if (data.containsKey('period_days')) {
      context.handle(
          _periodDaysMeta,
          periodDays.isAcceptableOrUnknown(
              data['period_days']!, _periodDaysMeta));
    }
    if (data.containsKey('order')) {
      context.handle(
          _orderMeta, order.isAcceptableOrUnknown(data['order']!, _orderMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  Habit map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Habit(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      createdDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_date'])!,
      modifiedDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}modified_date']),
      deletedDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_date']),
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description'])!,
      estimatedTime: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}estimated_time']),
      archivedDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}archived_date']),
      hasReminder: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}has_reminder'])!,
      reminderTime: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reminder_time']),
      reminderDays: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reminder_days'])!,
      hasGoal: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}has_goal'])!,
      targetFrequency: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}target_frequency'])!,
      periodDays: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}period_days'])!,
      order: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}order'])!,
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
  final Value<int?> estimatedTime;
  final Value<DateTime?> archivedDate;
  final Value<bool> hasReminder;
  final Value<String?> reminderTime;
  final Value<String> reminderDays;
  final Value<bool> hasGoal;
  final Value<int> targetFrequency;
  final Value<int> periodDays;
  final Value<double> order;
  final Value<int> rowid;
  const HabitTableCompanion({
    this.id = const Value.absent(),
    this.createdDate = const Value.absent(),
    this.modifiedDate = const Value.absent(),
    this.deletedDate = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.estimatedTime = const Value.absent(),
    this.archivedDate = const Value.absent(),
    this.hasReminder = const Value.absent(),
    this.reminderTime = const Value.absent(),
    this.reminderDays = const Value.absent(),
    this.hasGoal = const Value.absent(),
    this.targetFrequency = const Value.absent(),
    this.periodDays = const Value.absent(),
    this.order = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HabitTableCompanion.insert({
    required String id,
    required DateTime createdDate,
    this.modifiedDate = const Value.absent(),
    this.deletedDate = const Value.absent(),
    required String name,
    required String description,
    this.estimatedTime = const Value.absent(),
    this.archivedDate = const Value.absent(),
    this.hasReminder = const Value.absent(),
    this.reminderTime = const Value.absent(),
    this.reminderDays = const Value.absent(),
    this.hasGoal = const Value.absent(),
    this.targetFrequency = const Value.absent(),
    this.periodDays = const Value.absent(),
    this.order = const Value.absent(),
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
    Expression<int>? estimatedTime,
    Expression<DateTime>? archivedDate,
    Expression<bool>? hasReminder,
    Expression<String>? reminderTime,
    Expression<String>? reminderDays,
    Expression<bool>? hasGoal,
    Expression<int>? targetFrequency,
    Expression<int>? periodDays,
    Expression<double>? order,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdDate != null) 'created_date': createdDate,
      if (modifiedDate != null) 'modified_date': modifiedDate,
      if (deletedDate != null) 'deleted_date': deletedDate,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (estimatedTime != null) 'estimated_time': estimatedTime,
      if (archivedDate != null) 'archived_date': archivedDate,
      if (hasReminder != null) 'has_reminder': hasReminder,
      if (reminderTime != null) 'reminder_time': reminderTime,
      if (reminderDays != null) 'reminder_days': reminderDays,
      if (hasGoal != null) 'has_goal': hasGoal,
      if (targetFrequency != null) 'target_frequency': targetFrequency,
      if (periodDays != null) 'period_days': periodDays,
      if (order != null) 'order': order,
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
      Value<int?>? estimatedTime,
      Value<DateTime?>? archivedDate,
      Value<bool>? hasReminder,
      Value<String?>? reminderTime,
      Value<String>? reminderDays,
      Value<bool>? hasGoal,
      Value<int>? targetFrequency,
      Value<int>? periodDays,
      Value<double>? order,
      Value<int>? rowid}) {
    return HabitTableCompanion(
      id: id ?? this.id,
      createdDate: createdDate ?? this.createdDate,
      modifiedDate: modifiedDate ?? this.modifiedDate,
      deletedDate: deletedDate ?? this.deletedDate,
      name: name ?? this.name,
      description: description ?? this.description,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      archivedDate: archivedDate ?? this.archivedDate,
      hasReminder: hasReminder ?? this.hasReminder,
      reminderTime: reminderTime ?? this.reminderTime,
      reminderDays: reminderDays ?? this.reminderDays,
      hasGoal: hasGoal ?? this.hasGoal,
      targetFrequency: targetFrequency ?? this.targetFrequency,
      periodDays: periodDays ?? this.periodDays,
      order: order ?? this.order,
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
    if (estimatedTime.present) {
      map['estimated_time'] = Variable<int>(estimatedTime.value);
    }
    if (archivedDate.present) {
      map['archived_date'] = Variable<DateTime>(archivedDate.value);
    }
    if (hasReminder.present) {
      map['has_reminder'] = Variable<bool>(hasReminder.value);
    }
    if (reminderTime.present) {
      map['reminder_time'] = Variable<String>(reminderTime.value);
    }
    if (reminderDays.present) {
      map['reminder_days'] = Variable<String>(reminderDays.value);
    }
    if (hasGoal.present) {
      map['has_goal'] = Variable<bool>(hasGoal.value);
    }
    if (targetFrequency.present) {
      map['target_frequency'] = Variable<int>(targetFrequency.value);
    }
    if (periodDays.present) {
      map['period_days'] = Variable<int>(periodDays.value);
    }
    if (order.present) {
      map['order'] = Variable<double>(order.value);
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
          ..write('estimatedTime: $estimatedTime, ')
          ..write('archivedDate: $archivedDate, ')
          ..write('hasReminder: $hasReminder, ')
          ..write('reminderTime: $reminderTime, ')
          ..write('reminderDays: $reminderDays, ')
          ..write('hasGoal: $hasGoal, ')
          ..write('targetFrequency: $targetFrequency, ')
          ..write('periodDays: $periodDays, ')
          ..write('order: $order, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HabitTagTableTable extends HabitTagTable
    with TableInfo<$HabitTagTableTable, HabitTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HabitTagTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdDateMeta =
      const VerificationMeta('createdDate');
  @override
  late final GeneratedColumn<DateTime> createdDate = GeneratedColumn<DateTime>(
      'created_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _modifiedDateMeta =
      const VerificationMeta('modifiedDate');
  @override
  late final GeneratedColumn<DateTime> modifiedDate = GeneratedColumn<DateTime>(
      'modified_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deletedDateMeta =
      const VerificationMeta('deletedDate');
  @override
  late final GeneratedColumn<DateTime> deletedDate = GeneratedColumn<DateTime>(
      'deleted_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _habitIdMeta =
      const VerificationMeta('habitId');
  @override
  late final GeneratedColumn<String> habitId = GeneratedColumn<String>(
      'habit_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<String> tagId = GeneratedColumn<String>(
      'tag_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, createdDate, modifiedDate, deletedDate, habitId, tagId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'habit_tag_table';
  @override
  VerificationContext validateIntegrity(Insertable<HabitTag> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_date')) {
      context.handle(
          _createdDateMeta,
          createdDate.isAcceptableOrUnknown(
              data['created_date']!, _createdDateMeta));
    } else if (isInserting) {
      context.missing(_createdDateMeta);
    }
    if (data.containsKey('modified_date')) {
      context.handle(
          _modifiedDateMeta,
          modifiedDate.isAcceptableOrUnknown(
              data['modified_date']!, _modifiedDateMeta));
    }
    if (data.containsKey('deleted_date')) {
      context.handle(
          _deletedDateMeta,
          deletedDate.isAcceptableOrUnknown(
              data['deleted_date']!, _deletedDateMeta));
    }
    if (data.containsKey('habit_id')) {
      context.handle(_habitIdMeta,
          habitId.isAcceptableOrUnknown(data['habit_id']!, _habitIdMeta));
    } else if (isInserting) {
      context.missing(_habitIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
          _tagIdMeta, tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta));
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
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      createdDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_date'])!,
      modifiedDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}modified_date']),
      deletedDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_date']),
      habitId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}habit_id'])!,
      tagId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tag_id'])!,
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

class $NoteTableTable extends NoteTable with TableInfo<$NoteTableTable, Note> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NoteTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _contentMeta =
      const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
      'content', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _orderMeta = const VerificationMeta('order');
  @override
  late final GeneratedColumn<double> order = GeneratedColumn<double>(
      'order', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _createdDateMeta =
      const VerificationMeta('createdDate');
  @override
  late final GeneratedColumn<DateTime> createdDate = GeneratedColumn<DateTime>(
      'created_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _modifiedDateMeta =
      const VerificationMeta('modifiedDate');
  @override
  late final GeneratedColumn<DateTime> modifiedDate = GeneratedColumn<DateTime>(
      'modified_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deletedDateMeta =
      const VerificationMeta('deletedDate');
  @override
  late final GeneratedColumn<DateTime> deletedDate = GeneratedColumn<DateTime>(
      'deleted_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, title, content, order, createdDate, modifiedDate, deletedDate];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'note_table';
  @override
  VerificationContext validateIntegrity(Insertable<Note> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    }
    if (data.containsKey('order')) {
      context.handle(
          _orderMeta, order.isAcceptableOrUnknown(data['order']!, _orderMeta));
    }
    if (data.containsKey('created_date')) {
      context.handle(
          _createdDateMeta,
          createdDate.isAcceptableOrUnknown(
              data['created_date']!, _createdDateMeta));
    } else if (isInserting) {
      context.missing(_createdDateMeta);
    }
    if (data.containsKey('modified_date')) {
      context.handle(
          _modifiedDateMeta,
          modifiedDate.isAcceptableOrUnknown(
              data['modified_date']!, _modifiedDateMeta));
    }
    if (data.containsKey('deleted_date')) {
      context.handle(
          _deletedDateMeta,
          deletedDate.isAcceptableOrUnknown(
              data['deleted_date']!, _deletedDateMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Note map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Note(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      createdDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_date'])!,
      modifiedDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}modified_date']),
      deletedDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_date']),
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content']),
      order: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}order'])!,
    );
  }

  @override
  $NoteTableTable createAlias(String alias) {
    return $NoteTableTable(attachedDatabase, alias);
  }
}

class NoteTableCompanion extends UpdateCompanion<Note> {
  final Value<String> id;
  final Value<String> title;
  final Value<String?> content;
  final Value<double> order;
  final Value<DateTime> createdDate;
  final Value<DateTime?> modifiedDate;
  final Value<DateTime?> deletedDate;
  final Value<int> rowid;
  const NoteTableCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.content = const Value.absent(),
    this.order = const Value.absent(),
    this.createdDate = const Value.absent(),
    this.modifiedDate = const Value.absent(),
    this.deletedDate = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NoteTableCompanion.insert({
    required String id,
    required String title,
    this.content = const Value.absent(),
    this.order = const Value.absent(),
    required DateTime createdDate,
    this.modifiedDate = const Value.absent(),
    this.deletedDate = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        title = Value(title),
        createdDate = Value(createdDate);
  static Insertable<Note> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? content,
    Expression<double>? order,
    Expression<DateTime>? createdDate,
    Expression<DateTime>? modifiedDate,
    Expression<DateTime>? deletedDate,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (order != null) 'order': order,
      if (createdDate != null) 'created_date': createdDate,
      if (modifiedDate != null) 'modified_date': modifiedDate,
      if (deletedDate != null) 'deleted_date': deletedDate,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NoteTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? title,
      Value<String?>? content,
      Value<double>? order,
      Value<DateTime>? createdDate,
      Value<DateTime?>? modifiedDate,
      Value<DateTime?>? deletedDate,
      Value<int>? rowid}) {
    return NoteTableCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      order: order ?? this.order,
      createdDate: createdDate ?? this.createdDate,
      modifiedDate: modifiedDate ?? this.modifiedDate,
      deletedDate: deletedDate ?? this.deletedDate,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (order.present) {
      map['order'] = Variable<double>(order.value);
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
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NoteTableCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('order: $order, ')
          ..write('createdDate: $createdDate, ')
          ..write('modifiedDate: $modifiedDate, ')
          ..write('deletedDate: $deletedDate, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NoteTagTableTable extends NoteTagTable
    with TableInfo<$NoteTagTableTable, NoteTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NoteTagTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _noteIdMeta = const VerificationMeta('noteId');
  @override
  late final GeneratedColumn<String> noteId = GeneratedColumn<String>(
      'note_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<String> tagId = GeneratedColumn<String>(
      'tag_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdDateMeta =
      const VerificationMeta('createdDate');
  @override
  late final GeneratedColumn<DateTime> createdDate = GeneratedColumn<DateTime>(
      'created_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _modifiedDateMeta =
      const VerificationMeta('modifiedDate');
  @override
  late final GeneratedColumn<DateTime> modifiedDate = GeneratedColumn<DateTime>(
      'modified_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deletedDateMeta =
      const VerificationMeta('deletedDate');
  @override
  late final GeneratedColumn<DateTime> deletedDate = GeneratedColumn<DateTime>(
      'deleted_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, noteId, tagId, createdDate, modifiedDate, deletedDate];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'note_tag_table';
  @override
  VerificationContext validateIntegrity(Insertable<NoteTag> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('note_id')) {
      context.handle(_noteIdMeta,
          noteId.isAcceptableOrUnknown(data['note_id']!, _noteIdMeta));
    } else if (isInserting) {
      context.missing(_noteIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
          _tagIdMeta, tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta));
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    if (data.containsKey('created_date')) {
      context.handle(
          _createdDateMeta,
          createdDate.isAcceptableOrUnknown(
              data['created_date']!, _createdDateMeta));
    } else if (isInserting) {
      context.missing(_createdDateMeta);
    }
    if (data.containsKey('modified_date')) {
      context.handle(
          _modifiedDateMeta,
          modifiedDate.isAcceptableOrUnknown(
              data['modified_date']!, _modifiedDateMeta));
    }
    if (data.containsKey('deleted_date')) {
      context.handle(
          _deletedDateMeta,
          deletedDate.isAcceptableOrUnknown(
              data['deleted_date']!, _deletedDateMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NoteTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoteTag(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      createdDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_date'])!,
      modifiedDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}modified_date']),
      deletedDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_date']),
      noteId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note_id'])!,
      tagId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tag_id'])!,
    );
  }

  @override
  $NoteTagTableTable createAlias(String alias) {
    return $NoteTagTableTable(attachedDatabase, alias);
  }
}

class NoteTagTableCompanion extends UpdateCompanion<NoteTag> {
  final Value<String> id;
  final Value<String> noteId;
  final Value<String> tagId;
  final Value<DateTime> createdDate;
  final Value<DateTime?> modifiedDate;
  final Value<DateTime?> deletedDate;
  final Value<int> rowid;
  const NoteTagTableCompanion({
    this.id = const Value.absent(),
    this.noteId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.createdDate = const Value.absent(),
    this.modifiedDate = const Value.absent(),
    this.deletedDate = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NoteTagTableCompanion.insert({
    required String id,
    required String noteId,
    required String tagId,
    required DateTime createdDate,
    this.modifiedDate = const Value.absent(),
    this.deletedDate = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        noteId = Value(noteId),
        tagId = Value(tagId),
        createdDate = Value(createdDate);
  static Insertable<NoteTag> custom({
    Expression<String>? id,
    Expression<String>? noteId,
    Expression<String>? tagId,
    Expression<DateTime>? createdDate,
    Expression<DateTime>? modifiedDate,
    Expression<DateTime>? deletedDate,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (noteId != null) 'note_id': noteId,
      if (tagId != null) 'tag_id': tagId,
      if (createdDate != null) 'created_date': createdDate,
      if (modifiedDate != null) 'modified_date': modifiedDate,
      if (deletedDate != null) 'deleted_date': deletedDate,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NoteTagTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? noteId,
      Value<String>? tagId,
      Value<DateTime>? createdDate,
      Value<DateTime?>? modifiedDate,
      Value<DateTime?>? deletedDate,
      Value<int>? rowid}) {
    return NoteTagTableCompanion(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      tagId: tagId ?? this.tagId,
      createdDate: createdDate ?? this.createdDate,
      modifiedDate: modifiedDate ?? this.modifiedDate,
      deletedDate: deletedDate ?? this.deletedDate,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (noteId.present) {
      map['note_id'] = Variable<String>(noteId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<String>(tagId.value);
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
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NoteTagTableCompanion(')
          ..write('id: $id, ')
          ..write('noteId: $noteId, ')
          ..write('tagId: $tagId, ')
          ..write('createdDate: $createdDate, ')
          ..write('modifiedDate: $modifiedDate, ')
          ..write('deletedDate: $deletedDate, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingTableTable extends SettingTable
    with TableInfo<$SettingTableTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdDateMeta =
      const VerificationMeta('createdDate');
  @override
  late final GeneratedColumn<DateTime> createdDate = GeneratedColumn<DateTime>(
      'created_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _modifiedDateMeta =
      const VerificationMeta('modifiedDate');
  @override
  late final GeneratedColumn<DateTime> modifiedDate = GeneratedColumn<DateTime>(
      'modified_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deletedDateMeta =
      const VerificationMeta('deletedDate');
  @override
  late final GeneratedColumn<DateTime> deletedDate = GeneratedColumn<DateTime>(
      'deleted_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  late final GeneratedColumnWithTypeConverter<SettingValueType, int> valueType =
      GeneratedColumn<int>('value_type', aliasedName, false,
              type: DriftSqlType.int, requiredDuringInsert: true)
          .withConverter<SettingValueType>(
              $SettingTableTable.$convertervalueType);
  @override
  List<GeneratedColumn> get $columns =>
      [id, createdDate, modifiedDate, deletedDate, key, value, valueType];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'setting_table';
  @override
  VerificationContext validateIntegrity(Insertable<Setting> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_date')) {
      context.handle(
          _createdDateMeta,
          createdDate.isAcceptableOrUnknown(
              data['created_date']!, _createdDateMeta));
    } else if (isInserting) {
      context.missing(_createdDateMeta);
    }
    if (data.containsKey('modified_date')) {
      context.handle(
          _modifiedDateMeta,
          modifiedDate.isAcceptableOrUnknown(
              data['modified_date']!, _modifiedDateMeta));
    }
    if (data.containsKey('deleted_date')) {
      context.handle(
          _deletedDateMeta,
          deletedDate.isAcceptableOrUnknown(
              data['deleted_date']!, _deletedDateMeta));
    }
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      createdDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_date'])!,
      modifiedDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}modified_date']),
      deletedDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_date']),
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
      valueType: $SettingTableTable.$convertervalueType.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}value_type'])!),
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
      map['value_type'] = Variable<int>(
          $SettingTableTable.$convertervalueType.toSql(valueType.value));
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

class $SyncDeviceTableTable extends SyncDeviceTable
    with TableInfo<$SyncDeviceTableTable, SyncDevice> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncDeviceTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdDateMeta =
      const VerificationMeta('createdDate');
  @override
  late final GeneratedColumn<DateTime> createdDate = GeneratedColumn<DateTime>(
      'created_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _modifiedDateMeta =
      const VerificationMeta('modifiedDate');
  @override
  late final GeneratedColumn<DateTime> modifiedDate = GeneratedColumn<DateTime>(
      'modified_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deletedDateMeta =
      const VerificationMeta('deletedDate');
  @override
  late final GeneratedColumn<DateTime> deletedDate = GeneratedColumn<DateTime>(
      'deleted_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _fromIpMeta = const VerificationMeta('fromIp');
  @override
  late final GeneratedColumn<String> fromIp = GeneratedColumn<String>(
      'from_ip', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _toIpMeta = const VerificationMeta('toIp');
  @override
  late final GeneratedColumn<String> toIp = GeneratedColumn<String>(
      'to_ip', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _fromDeviceIdMeta =
      const VerificationMeta('fromDeviceId');
  @override
  late final GeneratedColumn<String> fromDeviceId = GeneratedColumn<String>(
      'from_device_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _toDeviceIdMeta =
      const VerificationMeta('toDeviceId');
  @override
  late final GeneratedColumn<String> toDeviceId = GeneratedColumn<String>(
      'to_device_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lastSyncDateMeta =
      const VerificationMeta('lastSyncDate');
  @override
  late final GeneratedColumn<DateTime> lastSyncDate = GeneratedColumn<DateTime>(
      'last_sync_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        createdDate,
        modifiedDate,
        deletedDate,
        fromIp,
        toIp,
        fromDeviceId,
        toDeviceId,
        name,
        lastSyncDate
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_device_table';
  @override
  VerificationContext validateIntegrity(Insertable<SyncDevice> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_date')) {
      context.handle(
          _createdDateMeta,
          createdDate.isAcceptableOrUnknown(
              data['created_date']!, _createdDateMeta));
    } else if (isInserting) {
      context.missing(_createdDateMeta);
    }
    if (data.containsKey('modified_date')) {
      context.handle(
          _modifiedDateMeta,
          modifiedDate.isAcceptableOrUnknown(
              data['modified_date']!, _modifiedDateMeta));
    }
    if (data.containsKey('deleted_date')) {
      context.handle(
          _deletedDateMeta,
          deletedDate.isAcceptableOrUnknown(
              data['deleted_date']!, _deletedDateMeta));
    }
    if (data.containsKey('from_ip')) {
      context.handle(_fromIpMeta,
          fromIp.isAcceptableOrUnknown(data['from_ip']!, _fromIpMeta));
    } else if (isInserting) {
      context.missing(_fromIpMeta);
    }
    if (data.containsKey('to_ip')) {
      context.handle(
          _toIpMeta, toIp.isAcceptableOrUnknown(data['to_ip']!, _toIpMeta));
    } else if (isInserting) {
      context.missing(_toIpMeta);
    }
    if (data.containsKey('from_device_id')) {
      context.handle(
          _fromDeviceIdMeta,
          fromDeviceId.isAcceptableOrUnknown(
              data['from_device_id']!, _fromDeviceIdMeta));
    } else if (isInserting) {
      context.missing(_fromDeviceIdMeta);
    }
    if (data.containsKey('to_device_id')) {
      context.handle(
          _toDeviceIdMeta,
          toDeviceId.isAcceptableOrUnknown(
              data['to_device_id']!, _toDeviceIdMeta));
    } else if (isInserting) {
      context.missing(_toDeviceIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    }
    if (data.containsKey('last_sync_date')) {
      context.handle(
          _lastSyncDateMeta,
          lastSyncDate.isAcceptableOrUnknown(
              data['last_sync_date']!, _lastSyncDateMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  SyncDevice map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncDevice(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      createdDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_date'])!,
      fromIp: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}from_ip'])!,
      toIp: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}to_ip'])!,
      modifiedDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}modified_date']),
      deletedDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_date']),
      fromDeviceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}from_device_id'])!,
      toDeviceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}to_device_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name']),
      lastSyncDate: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_sync_date']),
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
  final Value<String> fromDeviceId;
  final Value<String> toDeviceId;
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
    this.fromDeviceId = const Value.absent(),
    this.toDeviceId = const Value.absent(),
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
    required String fromDeviceId,
    required String toDeviceId,
    this.name = const Value.absent(),
    this.lastSyncDate = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        createdDate = Value(createdDate),
        fromIp = Value(fromIp),
        toIp = Value(toIp),
        fromDeviceId = Value(fromDeviceId),
        toDeviceId = Value(toDeviceId);
  static Insertable<SyncDevice> custom({
    Expression<String>? id,
    Expression<DateTime>? createdDate,
    Expression<DateTime>? modifiedDate,
    Expression<DateTime>? deletedDate,
    Expression<String>? fromIp,
    Expression<String>? toIp,
    Expression<String>? fromDeviceId,
    Expression<String>? toDeviceId,
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
      if (fromDeviceId != null) 'from_device_id': fromDeviceId,
      if (toDeviceId != null) 'to_device_id': toDeviceId,
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
      Value<String>? fromDeviceId,
      Value<String>? toDeviceId,
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
      fromDeviceId: fromDeviceId ?? this.fromDeviceId,
      toDeviceId: toDeviceId ?? this.toDeviceId,
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
    if (fromDeviceId.present) {
      map['from_device_id'] = Variable<String>(fromDeviceId.value);
    }
    if (toDeviceId.present) {
      map['to_device_id'] = Variable<String>(toDeviceId.value);
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
          ..write('fromDeviceId: $fromDeviceId, ')
          ..write('toDeviceId: $toDeviceId, ')
          ..write('name: $name, ')
          ..write('lastSyncDate: $lastSyncDate, ')
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
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdDateMeta =
      const VerificationMeta('createdDate');
  @override
  late final GeneratedColumn<DateTime> createdDate = GeneratedColumn<DateTime>(
      'created_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _modifiedDateMeta =
      const VerificationMeta('modifiedDate');
  @override
  late final GeneratedColumn<DateTime> modifiedDate = GeneratedColumn<DateTime>(
      'modified_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deletedDateMeta =
      const VerificationMeta('deletedDate');
  @override
  late final GeneratedColumn<DateTime> deletedDate = GeneratedColumn<DateTime>(
      'deleted_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
      'color', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isArchivedMeta =
      const VerificationMeta('isArchived');
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
      'is_archived', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_archived" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns =>
      [id, createdDate, modifiedDate, deletedDate, name, color, isArchived];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tag_table';
  @override
  VerificationContext validateIntegrity(Insertable<Tag> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_date')) {
      context.handle(
          _createdDateMeta,
          createdDate.isAcceptableOrUnknown(
              data['created_date']!, _createdDateMeta));
    } else if (isInserting) {
      context.missing(_createdDateMeta);
    }
    if (data.containsKey('modified_date')) {
      context.handle(
          _modifiedDateMeta,
          modifiedDate.isAcceptableOrUnknown(
              data['modified_date']!, _modifiedDateMeta));
    }
    if (data.containsKey('deleted_date')) {
      context.handle(
          _deletedDateMeta,
          deletedDate.isAcceptableOrUnknown(
              data['deleted_date']!, _deletedDateMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
          _colorMeta, color.isAcceptableOrUnknown(data['color']!, _colorMeta));
    }
    if (data.containsKey('is_archived')) {
      context.handle(
          _isArchivedMeta,
          isArchived.isAcceptableOrUnknown(
              data['is_archived']!, _isArchivedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  Tag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Tag(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      createdDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_date'])!,
      modifiedDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}modified_date']),
      deletedDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_date']),
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      isArchived: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_archived'])!,
      color: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}color']),
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
  final Value<String?> color;
  final Value<bool> isArchived;
  final Value<int> rowid;
  const TagTableCompanion({
    this.id = const Value.absent(),
    this.createdDate = const Value.absent(),
    this.modifiedDate = const Value.absent(),
    this.deletedDate = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TagTableCompanion.insert({
    required String id,
    required DateTime createdDate,
    this.modifiedDate = const Value.absent(),
    this.deletedDate = const Value.absent(),
    required String name,
    this.color = const Value.absent(),
    this.isArchived = const Value.absent(),
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
    Expression<String>? color,
    Expression<bool>? isArchived,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdDate != null) 'created_date': createdDate,
      if (modifiedDate != null) 'modified_date': modifiedDate,
      if (deletedDate != null) 'deleted_date': deletedDate,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (isArchived != null) 'is_archived': isArchived,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TagTableCompanion copyWith(
      {Value<String>? id,
      Value<DateTime>? createdDate,
      Value<DateTime?>? modifiedDate,
      Value<DateTime?>? deletedDate,
      Value<String>? name,
      Value<String?>? color,
      Value<bool>? isArchived,
      Value<int>? rowid}) {
    return TagTableCompanion(
      id: id ?? this.id,
      createdDate: createdDate ?? this.createdDate,
      modifiedDate: modifiedDate ?? this.modifiedDate,
      deletedDate: deletedDate ?? this.deletedDate,
      name: name ?? this.name,
      color: color ?? this.color,
      isArchived: isArchived ?? this.isArchived,
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
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
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
          ..write('color: $color, ')
          ..write('isArchived: $isArchived, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TagTagTableTable extends TagTagTable
    with TableInfo<$TagTagTableTable, TagTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagTagTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdDateMeta =
      const VerificationMeta('createdDate');
  @override
  late final GeneratedColumn<DateTime> createdDate = GeneratedColumn<DateTime>(
      'created_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _modifiedDateMeta =
      const VerificationMeta('modifiedDate');
  @override
  late final GeneratedColumn<DateTime> modifiedDate = GeneratedColumn<DateTime>(
      'modified_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deletedDateMeta =
      const VerificationMeta('deletedDate');
  @override
  late final GeneratedColumn<DateTime> deletedDate = GeneratedColumn<DateTime>(
      'deleted_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _primaryTagIdMeta =
      const VerificationMeta('primaryTagId');
  @override
  late final GeneratedColumn<String> primaryTagId = GeneratedColumn<String>(
      'primary_tag_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _secondaryTagIdMeta =
      const VerificationMeta('secondaryTagId');
  @override
  late final GeneratedColumn<String> secondaryTagId = GeneratedColumn<String>(
      'secondary_tag_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        createdDate,
        modifiedDate,
        deletedDate,
        primaryTagId,
        secondaryTagId
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tag_tag_table';
  @override
  VerificationContext validateIntegrity(Insertable<TagTag> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_date')) {
      context.handle(
          _createdDateMeta,
          createdDate.isAcceptableOrUnknown(
              data['created_date']!, _createdDateMeta));
    } else if (isInserting) {
      context.missing(_createdDateMeta);
    }
    if (data.containsKey('modified_date')) {
      context.handle(
          _modifiedDateMeta,
          modifiedDate.isAcceptableOrUnknown(
              data['modified_date']!, _modifiedDateMeta));
    }
    if (data.containsKey('deleted_date')) {
      context.handle(
          _deletedDateMeta,
          deletedDate.isAcceptableOrUnknown(
              data['deleted_date']!, _deletedDateMeta));
    }
    if (data.containsKey('primary_tag_id')) {
      context.handle(
          _primaryTagIdMeta,
          primaryTagId.isAcceptableOrUnknown(
              data['primary_tag_id']!, _primaryTagIdMeta));
    } else if (isInserting) {
      context.missing(_primaryTagIdMeta);
    }
    if (data.containsKey('secondary_tag_id')) {
      context.handle(
          _secondaryTagIdMeta,
          secondaryTagId.isAcceptableOrUnknown(
              data['secondary_tag_id']!, _secondaryTagIdMeta));
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
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      createdDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_date'])!,
      modifiedDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}modified_date']),
      deletedDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_date']),
      primaryTagId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}primary_tag_id'])!,
      secondaryTagId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}secondary_tag_id'])!,
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

class $TaskTableTable extends TaskTable with TableInfo<$TaskTableTable, Task> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaskTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _parentTaskIdMeta =
      const VerificationMeta('parentTaskId');
  @override
  late final GeneratedColumn<String> parentTaskId = GeneratedColumn<String>(
      'parent_task_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  late final GeneratedColumnWithTypeConverter<EisenhowerPriority?, int>
      priority = GeneratedColumn<int>('priority', aliasedName, true,
              type: DriftSqlType.int, requiredDuringInsert: false)
          .withConverter<EisenhowerPriority?>(
              $TaskTableTable.$converterpriorityn);
  static const VerificationMeta _plannedDateMeta =
      const VerificationMeta('plannedDate');
  @override
  late final GeneratedColumn<DateTime> plannedDate = GeneratedColumn<DateTime>(
      'planned_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deadlineDateMeta =
      const VerificationMeta('deadlineDate');
  @override
  late final GeneratedColumn<DateTime> deadlineDate = GeneratedColumn<DateTime>(
      'deadline_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _estimatedTimeMeta =
      const VerificationMeta('estimatedTime');
  @override
  late final GeneratedColumn<int> estimatedTime = GeneratedColumn<int>(
      'estimated_time', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _isCompletedMeta =
      const VerificationMeta('isCompleted');
  @override
  late final GeneratedColumn<bool> isCompleted = GeneratedColumn<bool>(
      'is_completed', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_completed" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdDateMeta =
      const VerificationMeta('createdDate');
  @override
  late final GeneratedColumn<DateTime> createdDate = GeneratedColumn<DateTime>(
      'created_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _modifiedDateMeta =
      const VerificationMeta('modifiedDate');
  @override
  late final GeneratedColumn<DateTime> modifiedDate = GeneratedColumn<DateTime>(
      'modified_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deletedDateMeta =
      const VerificationMeta('deletedDate');
  @override
  late final GeneratedColumn<DateTime> deletedDate = GeneratedColumn<DateTime>(
      'deleted_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _orderMeta = const VerificationMeta('order');
  @override
  late final GeneratedColumn<double> order = GeneratedColumn<double>(
      'order', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  @override
  late final GeneratedColumnWithTypeConverter<ReminderTime, int>
      plannedDateReminderTime = GeneratedColumn<int>(
              'planned_date_reminder_time', aliasedName, false,
              type: DriftSqlType.int,
              requiredDuringInsert: false,
              defaultValue: const Constant(0))
          .withConverter<ReminderTime>(
              $TaskTableTable.$converterplannedDateReminderTime);
  @override
  late final GeneratedColumnWithTypeConverter<ReminderTime, int>
      deadlineDateReminderTime = GeneratedColumn<int>(
              'deadline_date_reminder_time', aliasedName, false,
              type: DriftSqlType.int,
              requiredDuringInsert: false,
              defaultValue: const Constant(0))
          .withConverter<ReminderTime>(
              $TaskTableTable.$converterdeadlineDateReminderTime);
  @override
  late final GeneratedColumnWithTypeConverter<RecurrenceType, int>
      recurrenceType = GeneratedColumn<int>(
              'recurrence_type', aliasedName, false,
              type: DriftSqlType.int,
              requiredDuringInsert: false,
              defaultValue: const Constant(0))
          .withConverter<RecurrenceType>(
              $TaskTableTable.$converterrecurrenceType);
  static const VerificationMeta _recurrenceIntervalMeta =
      const VerificationMeta('recurrenceInterval');
  @override
  late final GeneratedColumn<int> recurrenceInterval = GeneratedColumn<int>(
      'recurrence_interval', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _recurrenceDaysStringMeta =
      const VerificationMeta('recurrenceDaysString');
  @override
  late final GeneratedColumn<String> recurrenceDaysString =
      GeneratedColumn<String>('recurrence_days_string', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _recurrenceStartDateMeta =
      const VerificationMeta('recurrenceStartDate');
  @override
  late final GeneratedColumn<DateTime> recurrenceStartDate =
      GeneratedColumn<DateTime>('recurrence_start_date', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _recurrenceEndDateMeta =
      const VerificationMeta('recurrenceEndDate');
  @override
  late final GeneratedColumn<DateTime> recurrenceEndDate =
      GeneratedColumn<DateTime>('recurrence_end_date', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _recurrenceCountMeta =
      const VerificationMeta('recurrenceCount');
  @override
  late final GeneratedColumn<int> recurrenceCount = GeneratedColumn<int>(
      'recurrence_count', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _recurrenceParentIdMeta =
      const VerificationMeta('recurrenceParentId');
  @override
  late final GeneratedColumn<String> recurrenceParentId =
      GeneratedColumn<String>('recurrence_parent_id', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        parentTaskId,
        title,
        description,
        priority,
        plannedDate,
        deadlineDate,
        estimatedTime,
        isCompleted,
        createdDate,
        modifiedDate,
        deletedDate,
        order,
        plannedDateReminderTime,
        deadlineDateReminderTime,
        recurrenceType,
        recurrenceInterval,
        recurrenceDaysString,
        recurrenceStartDate,
        recurrenceEndDate,
        recurrenceCount,
        recurrenceParentId
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'task_table';
  @override
  VerificationContext validateIntegrity(Insertable<Task> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('parent_task_id')) {
      context.handle(
          _parentTaskIdMeta,
          parentTaskId.isAcceptableOrUnknown(
              data['parent_task_id']!, _parentTaskIdMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('planned_date')) {
      context.handle(
          _plannedDateMeta,
          plannedDate.isAcceptableOrUnknown(
              data['planned_date']!, _plannedDateMeta));
    }
    if (data.containsKey('deadline_date')) {
      context.handle(
          _deadlineDateMeta,
          deadlineDate.isAcceptableOrUnknown(
              data['deadline_date']!, _deadlineDateMeta));
    }
    if (data.containsKey('estimated_time')) {
      context.handle(
          _estimatedTimeMeta,
          estimatedTime.isAcceptableOrUnknown(
              data['estimated_time']!, _estimatedTimeMeta));
    }
    if (data.containsKey('is_completed')) {
      context.handle(
          _isCompletedMeta,
          isCompleted.isAcceptableOrUnknown(
              data['is_completed']!, _isCompletedMeta));
    }
    if (data.containsKey('created_date')) {
      context.handle(
          _createdDateMeta,
          createdDate.isAcceptableOrUnknown(
              data['created_date']!, _createdDateMeta));
    } else if (isInserting) {
      context.missing(_createdDateMeta);
    }
    if (data.containsKey('modified_date')) {
      context.handle(
          _modifiedDateMeta,
          modifiedDate.isAcceptableOrUnknown(
              data['modified_date']!, _modifiedDateMeta));
    }
    if (data.containsKey('deleted_date')) {
      context.handle(
          _deletedDateMeta,
          deletedDate.isAcceptableOrUnknown(
              data['deleted_date']!, _deletedDateMeta));
    }
    if (data.containsKey('order')) {
      context.handle(
          _orderMeta, order.isAcceptableOrUnknown(data['order']!, _orderMeta));
    }
    if (data.containsKey('recurrence_interval')) {
      context.handle(
          _recurrenceIntervalMeta,
          recurrenceInterval.isAcceptableOrUnknown(
              data['recurrence_interval']!, _recurrenceIntervalMeta));
    }
    if (data.containsKey('recurrence_days_string')) {
      context.handle(
          _recurrenceDaysStringMeta,
          recurrenceDaysString.isAcceptableOrUnknown(
              data['recurrence_days_string']!, _recurrenceDaysStringMeta));
    }
    if (data.containsKey('recurrence_start_date')) {
      context.handle(
          _recurrenceStartDateMeta,
          recurrenceStartDate.isAcceptableOrUnknown(
              data['recurrence_start_date']!, _recurrenceStartDateMeta));
    }
    if (data.containsKey('recurrence_end_date')) {
      context.handle(
          _recurrenceEndDateMeta,
          recurrenceEndDate.isAcceptableOrUnknown(
              data['recurrence_end_date']!, _recurrenceEndDateMeta));
    }
    if (data.containsKey('recurrence_count')) {
      context.handle(
          _recurrenceCountMeta,
          recurrenceCount.isAcceptableOrUnknown(
              data['recurrence_count']!, _recurrenceCountMeta));
    }
    if (data.containsKey('recurrence_parent_id')) {
      context.handle(
          _recurrenceParentIdMeta,
          recurrenceParentId.isAcceptableOrUnknown(
              data['recurrence_parent_id']!, _recurrenceParentIdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  Task map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Task(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      createdDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_date'])!,
      modifiedDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}modified_date']),
      deletedDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_date']),
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      plannedDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}planned_date']),
      deadlineDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deadline_date']),
      priority: $TaskTableTable.$converterpriorityn.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}priority'])),
      estimatedTime: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}estimated_time']),
      isCompleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_completed'])!,
      parentTaskId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}parent_task_id']),
      order: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}order'])!,
      plannedDateReminderTime: $TaskTableTable.$converterplannedDateReminderTime
          .fromSql(attachedDatabase.typeMapping.read(DriftSqlType.int,
              data['${effectivePrefix}planned_date_reminder_time'])!),
      deadlineDateReminderTime: $TaskTableTable
          .$converterdeadlineDateReminderTime
          .fromSql(attachedDatabase.typeMapping.read(DriftSqlType.int,
              data['${effectivePrefix}deadline_date_reminder_time'])!),
      recurrenceType: $TaskTableTable.$converterrecurrenceType.fromSql(
          attachedDatabase.typeMapping.read(
              DriftSqlType.int, data['${effectivePrefix}recurrence_type'])!),
      recurrenceInterval: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}recurrence_interval']),
      recurrenceDaysString: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}recurrence_days_string']),
      recurrenceStartDate: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime,
          data['${effectivePrefix}recurrence_start_date']),
      recurrenceEndDate: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}recurrence_end_date']),
      recurrenceCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}recurrence_count']),
      recurrenceParentId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}recurrence_parent_id']),
    );
  }

  @override
  $TaskTableTable createAlias(String alias) {
    return $TaskTableTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<EisenhowerPriority, int, int> $converterpriority =
      const EnumIndexConverter<EisenhowerPriority>(EisenhowerPriority.values);
  static JsonTypeConverter2<EisenhowerPriority?, int?, int?>
      $converterpriorityn = JsonTypeConverter2.asNullable($converterpriority);
  static JsonTypeConverter2<ReminderTime, int, int>
      $converterplannedDateReminderTime =
      const EnumIndexConverter<ReminderTime>(ReminderTime.values);
  static JsonTypeConverter2<ReminderTime, int, int>
      $converterdeadlineDateReminderTime =
      const EnumIndexConverter<ReminderTime>(ReminderTime.values);
  static JsonTypeConverter2<RecurrenceType, int, int> $converterrecurrenceType =
      const EnumIndexConverter<RecurrenceType>(RecurrenceType.values);
}

class TaskTableCompanion extends UpdateCompanion<Task> {
  final Value<String> id;
  final Value<String?> parentTaskId;
  final Value<String> title;
  final Value<String?> description;
  final Value<EisenhowerPriority?> priority;
  final Value<DateTime?> plannedDate;
  final Value<DateTime?> deadlineDate;
  final Value<int?> estimatedTime;
  final Value<bool> isCompleted;
  final Value<DateTime> createdDate;
  final Value<DateTime?> modifiedDate;
  final Value<DateTime?> deletedDate;
  final Value<double> order;
  final Value<ReminderTime> plannedDateReminderTime;
  final Value<ReminderTime> deadlineDateReminderTime;
  final Value<RecurrenceType> recurrenceType;
  final Value<int?> recurrenceInterval;
  final Value<String?> recurrenceDaysString;
  final Value<DateTime?> recurrenceStartDate;
  final Value<DateTime?> recurrenceEndDate;
  final Value<int?> recurrenceCount;
  final Value<String?> recurrenceParentId;
  final Value<int> rowid;
  const TaskTableCompanion({
    this.id = const Value.absent(),
    this.parentTaskId = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.priority = const Value.absent(),
    this.plannedDate = const Value.absent(),
    this.deadlineDate = const Value.absent(),
    this.estimatedTime = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.createdDate = const Value.absent(),
    this.modifiedDate = const Value.absent(),
    this.deletedDate = const Value.absent(),
    this.order = const Value.absent(),
    this.plannedDateReminderTime = const Value.absent(),
    this.deadlineDateReminderTime = const Value.absent(),
    this.recurrenceType = const Value.absent(),
    this.recurrenceInterval = const Value.absent(),
    this.recurrenceDaysString = const Value.absent(),
    this.recurrenceStartDate = const Value.absent(),
    this.recurrenceEndDate = const Value.absent(),
    this.recurrenceCount = const Value.absent(),
    this.recurrenceParentId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TaskTableCompanion.insert({
    required String id,
    this.parentTaskId = const Value.absent(),
    required String title,
    this.description = const Value.absent(),
    this.priority = const Value.absent(),
    this.plannedDate = const Value.absent(),
    this.deadlineDate = const Value.absent(),
    this.estimatedTime = const Value.absent(),
    this.isCompleted = const Value.absent(),
    required DateTime createdDate,
    this.modifiedDate = const Value.absent(),
    this.deletedDate = const Value.absent(),
    this.order = const Value.absent(),
    this.plannedDateReminderTime = const Value.absent(),
    this.deadlineDateReminderTime = const Value.absent(),
    this.recurrenceType = const Value.absent(),
    this.recurrenceInterval = const Value.absent(),
    this.recurrenceDaysString = const Value.absent(),
    this.recurrenceStartDate = const Value.absent(),
    this.recurrenceEndDate = const Value.absent(),
    this.recurrenceCount = const Value.absent(),
    this.recurrenceParentId = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        title = Value(title),
        createdDate = Value(createdDate);
  static Insertable<Task> custom({
    Expression<String>? id,
    Expression<String>? parentTaskId,
    Expression<String>? title,
    Expression<String>? description,
    Expression<int>? priority,
    Expression<DateTime>? plannedDate,
    Expression<DateTime>? deadlineDate,
    Expression<int>? estimatedTime,
    Expression<bool>? isCompleted,
    Expression<DateTime>? createdDate,
    Expression<DateTime>? modifiedDate,
    Expression<DateTime>? deletedDate,
    Expression<double>? order,
    Expression<int>? plannedDateReminderTime,
    Expression<int>? deadlineDateReminderTime,
    Expression<int>? recurrenceType,
    Expression<int>? recurrenceInterval,
    Expression<String>? recurrenceDaysString,
    Expression<DateTime>? recurrenceStartDate,
    Expression<DateTime>? recurrenceEndDate,
    Expression<int>? recurrenceCount,
    Expression<String>? recurrenceParentId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (parentTaskId != null) 'parent_task_id': parentTaskId,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (priority != null) 'priority': priority,
      if (plannedDate != null) 'planned_date': plannedDate,
      if (deadlineDate != null) 'deadline_date': deadlineDate,
      if (estimatedTime != null) 'estimated_time': estimatedTime,
      if (isCompleted != null) 'is_completed': isCompleted,
      if (createdDate != null) 'created_date': createdDate,
      if (modifiedDate != null) 'modified_date': modifiedDate,
      if (deletedDate != null) 'deleted_date': deletedDate,
      if (order != null) 'order': order,
      if (plannedDateReminderTime != null)
        'planned_date_reminder_time': plannedDateReminderTime,
      if (deadlineDateReminderTime != null)
        'deadline_date_reminder_time': deadlineDateReminderTime,
      if (recurrenceType != null) 'recurrence_type': recurrenceType,
      if (recurrenceInterval != null) 'recurrence_interval': recurrenceInterval,
      if (recurrenceDaysString != null)
        'recurrence_days_string': recurrenceDaysString,
      if (recurrenceStartDate != null)
        'recurrence_start_date': recurrenceStartDate,
      if (recurrenceEndDate != null) 'recurrence_end_date': recurrenceEndDate,
      if (recurrenceCount != null) 'recurrence_count': recurrenceCount,
      if (recurrenceParentId != null)
        'recurrence_parent_id': recurrenceParentId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TaskTableCompanion copyWith(
      {Value<String>? id,
      Value<String?>? parentTaskId,
      Value<String>? title,
      Value<String?>? description,
      Value<EisenhowerPriority?>? priority,
      Value<DateTime?>? plannedDate,
      Value<DateTime?>? deadlineDate,
      Value<int?>? estimatedTime,
      Value<bool>? isCompleted,
      Value<DateTime>? createdDate,
      Value<DateTime?>? modifiedDate,
      Value<DateTime?>? deletedDate,
      Value<double>? order,
      Value<ReminderTime>? plannedDateReminderTime,
      Value<ReminderTime>? deadlineDateReminderTime,
      Value<RecurrenceType>? recurrenceType,
      Value<int?>? recurrenceInterval,
      Value<String?>? recurrenceDaysString,
      Value<DateTime?>? recurrenceStartDate,
      Value<DateTime?>? recurrenceEndDate,
      Value<int?>? recurrenceCount,
      Value<String?>? recurrenceParentId,
      Value<int>? rowid}) {
    return TaskTableCompanion(
      id: id ?? this.id,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      plannedDate: plannedDate ?? this.plannedDate,
      deadlineDate: deadlineDate ?? this.deadlineDate,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      isCompleted: isCompleted ?? this.isCompleted,
      createdDate: createdDate ?? this.createdDate,
      modifiedDate: modifiedDate ?? this.modifiedDate,
      deletedDate: deletedDate ?? this.deletedDate,
      order: order ?? this.order,
      plannedDateReminderTime:
          plannedDateReminderTime ?? this.plannedDateReminderTime,
      deadlineDateReminderTime:
          deadlineDateReminderTime ?? this.deadlineDateReminderTime,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      recurrenceInterval: recurrenceInterval ?? this.recurrenceInterval,
      recurrenceDaysString: recurrenceDaysString ?? this.recurrenceDaysString,
      recurrenceStartDate: recurrenceStartDate ?? this.recurrenceStartDate,
      recurrenceEndDate: recurrenceEndDate ?? this.recurrenceEndDate,
      recurrenceCount: recurrenceCount ?? this.recurrenceCount,
      recurrenceParentId: recurrenceParentId ?? this.recurrenceParentId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (parentTaskId.present) {
      map['parent_task_id'] = Variable<String>(parentTaskId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(
          $TaskTableTable.$converterpriorityn.toSql(priority.value));
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
    if (isCompleted.present) {
      map['is_completed'] = Variable<bool>(isCompleted.value);
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
    if (order.present) {
      map['order'] = Variable<double>(order.value);
    }
    if (plannedDateReminderTime.present) {
      map['planned_date_reminder_time'] = Variable<int>($TaskTableTable
          .$converterplannedDateReminderTime
          .toSql(plannedDateReminderTime.value));
    }
    if (deadlineDateReminderTime.present) {
      map['deadline_date_reminder_time'] = Variable<int>($TaskTableTable
          .$converterdeadlineDateReminderTime
          .toSql(deadlineDateReminderTime.value));
    }
    if (recurrenceType.present) {
      map['recurrence_type'] = Variable<int>(
          $TaskTableTable.$converterrecurrenceType.toSql(recurrenceType.value));
    }
    if (recurrenceInterval.present) {
      map['recurrence_interval'] = Variable<int>(recurrenceInterval.value);
    }
    if (recurrenceDaysString.present) {
      map['recurrence_days_string'] =
          Variable<String>(recurrenceDaysString.value);
    }
    if (recurrenceStartDate.present) {
      map['recurrence_start_date'] =
          Variable<DateTime>(recurrenceStartDate.value);
    }
    if (recurrenceEndDate.present) {
      map['recurrence_end_date'] = Variable<DateTime>(recurrenceEndDate.value);
    }
    if (recurrenceCount.present) {
      map['recurrence_count'] = Variable<int>(recurrenceCount.value);
    }
    if (recurrenceParentId.present) {
      map['recurrence_parent_id'] = Variable<String>(recurrenceParentId.value);
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
          ..write('parentTaskId: $parentTaskId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('priority: $priority, ')
          ..write('plannedDate: $plannedDate, ')
          ..write('deadlineDate: $deadlineDate, ')
          ..write('estimatedTime: $estimatedTime, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('createdDate: $createdDate, ')
          ..write('modifiedDate: $modifiedDate, ')
          ..write('deletedDate: $deletedDate, ')
          ..write('order: $order, ')
          ..write('plannedDateReminderTime: $plannedDateReminderTime, ')
          ..write('deadlineDateReminderTime: $deadlineDateReminderTime, ')
          ..write('recurrenceType: $recurrenceType, ')
          ..write('recurrenceInterval: $recurrenceInterval, ')
          ..write('recurrenceDaysString: $recurrenceDaysString, ')
          ..write('recurrenceStartDate: $recurrenceStartDate, ')
          ..write('recurrenceEndDate: $recurrenceEndDate, ')
          ..write('recurrenceCount: $recurrenceCount, ')
          ..write('recurrenceParentId: $recurrenceParentId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TaskTagTableTable extends TaskTagTable
    with TableInfo<$TaskTagTableTable, TaskTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaskTagTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdDateMeta =
      const VerificationMeta('createdDate');
  @override
  late final GeneratedColumn<DateTime> createdDate = GeneratedColumn<DateTime>(
      'created_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _modifiedDateMeta =
      const VerificationMeta('modifiedDate');
  @override
  late final GeneratedColumn<DateTime> modifiedDate = GeneratedColumn<DateTime>(
      'modified_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deletedDateMeta =
      const VerificationMeta('deletedDate');
  @override
  late final GeneratedColumn<DateTime> deletedDate = GeneratedColumn<DateTime>(
      'deleted_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
      'task_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<String> tagId = GeneratedColumn<String>(
      'tag_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, createdDate, modifiedDate, deletedDate, taskId, tagId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'task_tag_table';
  @override
  VerificationContext validateIntegrity(Insertable<TaskTag> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_date')) {
      context.handle(
          _createdDateMeta,
          createdDate.isAcceptableOrUnknown(
              data['created_date']!, _createdDateMeta));
    } else if (isInserting) {
      context.missing(_createdDateMeta);
    }
    if (data.containsKey('modified_date')) {
      context.handle(
          _modifiedDateMeta,
          modifiedDate.isAcceptableOrUnknown(
              data['modified_date']!, _modifiedDateMeta));
    }
    if (data.containsKey('deleted_date')) {
      context.handle(
          _deletedDateMeta,
          deletedDate.isAcceptableOrUnknown(
              data['deleted_date']!, _deletedDateMeta));
    }
    if (data.containsKey('task_id')) {
      context.handle(_taskIdMeta,
          taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta));
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
          _tagIdMeta, tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta));
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
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      createdDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_date'])!,
      modifiedDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}modified_date']),
      deletedDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_date']),
      taskId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}task_id'])!,
      tagId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tag_id'])!,
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

class $TaskTimeRecordTableTable extends TaskTimeRecordTable
    with TableInfo<$TaskTimeRecordTableTable, TaskTimeRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaskTimeRecordTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
      'task_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _durationMeta =
      const VerificationMeta('duration');
  @override
  late final GeneratedColumn<int> duration = GeneratedColumn<int>(
      'duration', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _createdDateMeta =
      const VerificationMeta('createdDate');
  @override
  late final GeneratedColumn<DateTime> createdDate = GeneratedColumn<DateTime>(
      'created_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _modifiedDateMeta =
      const VerificationMeta('modifiedDate');
  @override
  late final GeneratedColumn<DateTime> modifiedDate = GeneratedColumn<DateTime>(
      'modified_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deletedDateMeta =
      const VerificationMeta('deletedDate');
  @override
  late final GeneratedColumn<DateTime> deletedDate = GeneratedColumn<DateTime>(
      'deleted_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, taskId, duration, createdDate, modifiedDate, deletedDate];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'task_time_record_table';
  @override
  VerificationContext validateIntegrity(Insertable<TaskTimeRecord> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('task_id')) {
      context.handle(_taskIdMeta,
          taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta));
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('duration')) {
      context.handle(_durationMeta,
          duration.isAcceptableOrUnknown(data['duration']!, _durationMeta));
    } else if (isInserting) {
      context.missing(_durationMeta);
    }
    if (data.containsKey('created_date')) {
      context.handle(
          _createdDateMeta,
          createdDate.isAcceptableOrUnknown(
              data['created_date']!, _createdDateMeta));
    } else if (isInserting) {
      context.missing(_createdDateMeta);
    }
    if (data.containsKey('modified_date')) {
      context.handle(
          _modifiedDateMeta,
          modifiedDate.isAcceptableOrUnknown(
              data['modified_date']!, _modifiedDateMeta));
    }
    if (data.containsKey('deleted_date')) {
      context.handle(
          _deletedDateMeta,
          deletedDate.isAcceptableOrUnknown(
              data['deleted_date']!, _deletedDateMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  TaskTimeRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskTimeRecord(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      taskId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}task_id'])!,
      duration: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration'])!,
      createdDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_date'])!,
      modifiedDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}modified_date']),
      deletedDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_date']),
    );
  }

  @override
  $TaskTimeRecordTableTable createAlias(String alias) {
    return $TaskTimeRecordTableTable(attachedDatabase, alias);
  }
}

class TaskTimeRecordTableCompanion extends UpdateCompanion<TaskTimeRecord> {
  final Value<String> id;
  final Value<String> taskId;
  final Value<int> duration;
  final Value<DateTime> createdDate;
  final Value<DateTime?> modifiedDate;
  final Value<DateTime?> deletedDate;
  final Value<int> rowid;
  const TaskTimeRecordTableCompanion({
    this.id = const Value.absent(),
    this.taskId = const Value.absent(),
    this.duration = const Value.absent(),
    this.createdDate = const Value.absent(),
    this.modifiedDate = const Value.absent(),
    this.deletedDate = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TaskTimeRecordTableCompanion.insert({
    required String id,
    required String taskId,
    required int duration,
    required DateTime createdDate,
    this.modifiedDate = const Value.absent(),
    this.deletedDate = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        taskId = Value(taskId),
        duration = Value(duration),
        createdDate = Value(createdDate);
  static Insertable<TaskTimeRecord> custom({
    Expression<String>? id,
    Expression<String>? taskId,
    Expression<int>? duration,
    Expression<DateTime>? createdDate,
    Expression<DateTime>? modifiedDate,
    Expression<DateTime>? deletedDate,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (taskId != null) 'task_id': taskId,
      if (duration != null) 'duration': duration,
      if (createdDate != null) 'created_date': createdDate,
      if (modifiedDate != null) 'modified_date': modifiedDate,
      if (deletedDate != null) 'deleted_date': deletedDate,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TaskTimeRecordTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? taskId,
      Value<int>? duration,
      Value<DateTime>? createdDate,
      Value<DateTime?>? modifiedDate,
      Value<DateTime?>? deletedDate,
      Value<int>? rowid}) {
    return TaskTimeRecordTableCompanion(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      duration: duration ?? this.duration,
      createdDate: createdDate ?? this.createdDate,
      modifiedDate: modifiedDate ?? this.modifiedDate,
      deletedDate: deletedDate ?? this.deletedDate,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (duration.present) {
      map['duration'] = Variable<int>(duration.value);
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
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaskTimeRecordTableCompanion(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('duration: $duration, ')
          ..write('createdDate: $createdDate, ')
          ..write('modifiedDate: $modifiedDate, ')
          ..write('deletedDate: $deletedDate, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AppUsageIgnoreRuleTableTable appUsageIgnoreRuleTable =
      $AppUsageIgnoreRuleTableTable(this);
  late final $AppUsageTableTable appUsageTable = $AppUsageTableTable(this);
  late final $AppUsageTagRuleTableTable appUsageTagRuleTable =
      $AppUsageTagRuleTableTable(this);
  late final $AppUsageTagTableTable appUsageTagTable =
      $AppUsageTagTableTable(this);
  late final $AppUsageTimeRecordTableTable appUsageTimeRecordTable =
      $AppUsageTimeRecordTableTable(this);
  late final $HabitRecordTableTable habitRecordTable =
      $HabitRecordTableTable(this);
  late final $HabitTableTable habitTable = $HabitTableTable(this);
  late final $HabitTagTableTable habitTagTable = $HabitTagTableTable(this);
  late final $NoteTableTable noteTable = $NoteTableTable(this);
  late final $NoteTagTableTable noteTagTable = $NoteTagTableTable(this);
  late final $SettingTableTable settingTable = $SettingTableTable(this);
  late final $SyncDeviceTableTable syncDeviceTable =
      $SyncDeviceTableTable(this);
  late final $TagTableTable tagTable = $TagTableTable(this);
  late final $TagTagTableTable tagTagTable = $TagTagTableTable(this);
  late final $TaskTableTable taskTable = $TaskTableTable(this);
  late final $TaskTagTableTable taskTagTable = $TaskTagTableTable(this);
  late final $TaskTimeRecordTableTable taskTimeRecordTable =
      $TaskTimeRecordTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        appUsageIgnoreRuleTable,
        appUsageTable,
        appUsageTagRuleTable,
        appUsageTagTable,
        appUsageTimeRecordTable,
        habitRecordTable,
        habitTable,
        habitTagTable,
        noteTable,
        noteTagTable,
        settingTable,
        syncDeviceTable,
        tagTable,
        tagTagTable,
        taskTable,
        taskTagTable,
        taskTimeRecordTable
      ];
}

typedef $$AppUsageIgnoreRuleTableTableCreateCompanionBuilder
    = AppUsageIgnoreRuleTableCompanion Function({
  required String id,
  required String pattern,
  Value<String?> description,
  required DateTime createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  Value<int> rowid,
});
typedef $$AppUsageIgnoreRuleTableTableUpdateCompanionBuilder
    = AppUsageIgnoreRuleTableCompanion Function({
  Value<String> id,
  Value<String> pattern,
  Value<String?> description,
  Value<DateTime> createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  Value<int> rowid,
});

class $$AppUsageIgnoreRuleTableTableFilterComposer
    extends Composer<_$AppDatabase, $AppUsageIgnoreRuleTableTable> {
  $$AppUsageIgnoreRuleTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get pattern => $composableBuilder(
      column: $table.pattern, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => ColumnFilters(column));
}

class $$AppUsageIgnoreRuleTableTableOrderingComposer
    extends Composer<_$AppDatabase, $AppUsageIgnoreRuleTableTable> {
  $$AppUsageIgnoreRuleTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get pattern => $composableBuilder(
      column: $table.pattern, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => ColumnOrderings(column));
}

class $$AppUsageIgnoreRuleTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppUsageIgnoreRuleTableTable> {
  $$AppUsageIgnoreRuleTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get pattern =>
      $composableBuilder(column: $table.pattern, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => column);

  GeneratedColumn<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => column);
}

class $$AppUsageIgnoreRuleTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AppUsageIgnoreRuleTableTable,
    AppUsageIgnoreRule,
    $$AppUsageIgnoreRuleTableTableFilterComposer,
    $$AppUsageIgnoreRuleTableTableOrderingComposer,
    $$AppUsageIgnoreRuleTableTableAnnotationComposer,
    $$AppUsageIgnoreRuleTableTableCreateCompanionBuilder,
    $$AppUsageIgnoreRuleTableTableUpdateCompanionBuilder,
    (
      AppUsageIgnoreRule,
      BaseReferences<_$AppDatabase, $AppUsageIgnoreRuleTableTable,
          AppUsageIgnoreRule>
    ),
    AppUsageIgnoreRule,
    PrefetchHooks Function()> {
  $$AppUsageIgnoreRuleTableTableTableManager(
      _$AppDatabase db, $AppUsageIgnoreRuleTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppUsageIgnoreRuleTableTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$AppUsageIgnoreRuleTableTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppUsageIgnoreRuleTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> pattern = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<DateTime> createdDate = const Value.absent(),
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<DateTime?> deletedDate = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppUsageIgnoreRuleTableCompanion(
            id: id,
            pattern: pattern,
            description: description,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            deletedDate: deletedDate,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String pattern,
            Value<String?> description = const Value.absent(),
            required DateTime createdDate,
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<DateTime?> deletedDate = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppUsageIgnoreRuleTableCompanion.insert(
            id: id,
            pattern: pattern,
            description: description,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            deletedDate: deletedDate,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AppUsageIgnoreRuleTableTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $AppUsageIgnoreRuleTableTable,
        AppUsageIgnoreRule,
        $$AppUsageIgnoreRuleTableTableFilterComposer,
        $$AppUsageIgnoreRuleTableTableOrderingComposer,
        $$AppUsageIgnoreRuleTableTableAnnotationComposer,
        $$AppUsageIgnoreRuleTableTableCreateCompanionBuilder,
        $$AppUsageIgnoreRuleTableTableUpdateCompanionBuilder,
        (
          AppUsageIgnoreRule,
          BaseReferences<_$AppDatabase, $AppUsageIgnoreRuleTableTable,
              AppUsageIgnoreRule>
        ),
        AppUsageIgnoreRule,
        PrefetchHooks Function()>;
typedef $$AppUsageTableTableCreateCompanionBuilder = AppUsageTableCompanion
    Function({
  required String id,
  required DateTime createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  required String name,
  Value<String?> displayName,
  Value<String?> color,
  Value<String?> deviceName,
  Value<int> rowid,
});
typedef $$AppUsageTableTableUpdateCompanionBuilder = AppUsageTableCompanion
    Function({
  Value<String> id,
  Value<DateTime> createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  Value<String> name,
  Value<String?> displayName,
  Value<String?> color,
  Value<String?> deviceName,
  Value<int> rowid,
});

class $$AppUsageTableTableFilterComposer
    extends Composer<_$AppDatabase, $AppUsageTableTable> {
  $$AppUsageTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deviceName => $composableBuilder(
      column: $table.deviceName, builder: (column) => ColumnFilters(column));
}

class $$AppUsageTableTableOrderingComposer
    extends Composer<_$AppDatabase, $AppUsageTableTable> {
  $$AppUsageTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deviceName => $composableBuilder(
      column: $table.deviceName, builder: (column) => ColumnOrderings(column));
}

class $$AppUsageTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppUsageTableTable> {
  $$AppUsageTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => column);

  GeneratedColumn<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<String> get deviceName => $composableBuilder(
      column: $table.deviceName, builder: (column) => column);
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
          createFilteringComposer: () =>
              $$AppUsageTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppUsageTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppUsageTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<DateTime> createdDate = const Value.absent(),
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<DateTime?> deletedDate = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> displayName = const Value.absent(),
            Value<String?> color = const Value.absent(),
            Value<String?> deviceName = const Value.absent(),
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
            deviceName: deviceName,
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
            Value<String?> deviceName = const Value.absent(),
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
            deviceName: deviceName,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
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
typedef $$AppUsageTagRuleTableTableCreateCompanionBuilder
    = AppUsageTagRuleTableCompanion Function({
  required String id,
  required String pattern,
  required String tagId,
  Value<String?> description,
  required DateTime createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  Value<int> rowid,
});
typedef $$AppUsageTagRuleTableTableUpdateCompanionBuilder
    = AppUsageTagRuleTableCompanion Function({
  Value<String> id,
  Value<String> pattern,
  Value<String> tagId,
  Value<String?> description,
  Value<DateTime> createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  Value<int> rowid,
});

class $$AppUsageTagRuleTableTableFilterComposer
    extends Composer<_$AppDatabase, $AppUsageTagRuleTableTable> {
  $$AppUsageTagRuleTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get pattern => $composableBuilder(
      column: $table.pattern, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tagId => $composableBuilder(
      column: $table.tagId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => ColumnFilters(column));
}

class $$AppUsageTagRuleTableTableOrderingComposer
    extends Composer<_$AppDatabase, $AppUsageTagRuleTableTable> {
  $$AppUsageTagRuleTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get pattern => $composableBuilder(
      column: $table.pattern, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tagId => $composableBuilder(
      column: $table.tagId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => ColumnOrderings(column));
}

class $$AppUsageTagRuleTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppUsageTagRuleTableTable> {
  $$AppUsageTagRuleTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get pattern =>
      $composableBuilder(column: $table.pattern, builder: (column) => column);

  GeneratedColumn<String> get tagId =>
      $composableBuilder(column: $table.tagId, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => column);

  GeneratedColumn<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => column);
}

class $$AppUsageTagRuleTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AppUsageTagRuleTableTable,
    AppUsageTagRule,
    $$AppUsageTagRuleTableTableFilterComposer,
    $$AppUsageTagRuleTableTableOrderingComposer,
    $$AppUsageTagRuleTableTableAnnotationComposer,
    $$AppUsageTagRuleTableTableCreateCompanionBuilder,
    $$AppUsageTagRuleTableTableUpdateCompanionBuilder,
    (
      AppUsageTagRule,
      BaseReferences<_$AppDatabase, $AppUsageTagRuleTableTable, AppUsageTagRule>
    ),
    AppUsageTagRule,
    PrefetchHooks Function()> {
  $$AppUsageTagRuleTableTableTableManager(
      _$AppDatabase db, $AppUsageTagRuleTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppUsageTagRuleTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppUsageTagRuleTableTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppUsageTagRuleTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> pattern = const Value.absent(),
            Value<String> tagId = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<DateTime> createdDate = const Value.absent(),
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<DateTime?> deletedDate = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppUsageTagRuleTableCompanion(
            id: id,
            pattern: pattern,
            tagId: tagId,
            description: description,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            deletedDate: deletedDate,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String pattern,
            required String tagId,
            Value<String?> description = const Value.absent(),
            required DateTime createdDate,
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<DateTime?> deletedDate = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppUsageTagRuleTableCompanion.insert(
            id: id,
            pattern: pattern,
            tagId: tagId,
            description: description,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            deletedDate: deletedDate,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AppUsageTagRuleTableTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $AppUsageTagRuleTableTable,
        AppUsageTagRule,
        $$AppUsageTagRuleTableTableFilterComposer,
        $$AppUsageTagRuleTableTableOrderingComposer,
        $$AppUsageTagRuleTableTableAnnotationComposer,
        $$AppUsageTagRuleTableTableCreateCompanionBuilder,
        $$AppUsageTagRuleTableTableUpdateCompanionBuilder,
        (
          AppUsageTagRule,
          BaseReferences<_$AppDatabase, $AppUsageTagRuleTableTable,
              AppUsageTagRule>
        ),
        AppUsageTagRule,
        PrefetchHooks Function()>;
typedef $$AppUsageTagTableTableCreateCompanionBuilder
    = AppUsageTagTableCompanion Function({
  required String id,
  required DateTime createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  required String appUsageId,
  required String tagId,
  Value<int> rowid,
});
typedef $$AppUsageTagTableTableUpdateCompanionBuilder
    = AppUsageTagTableCompanion Function({
  Value<String> id,
  Value<DateTime> createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  Value<String> appUsageId,
  Value<String> tagId,
  Value<int> rowid,
});

class $$AppUsageTagTableTableFilterComposer
    extends Composer<_$AppDatabase, $AppUsageTagTableTable> {
  $$AppUsageTagTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get appUsageId => $composableBuilder(
      column: $table.appUsageId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tagId => $composableBuilder(
      column: $table.tagId, builder: (column) => ColumnFilters(column));
}

class $$AppUsageTagTableTableOrderingComposer
    extends Composer<_$AppDatabase, $AppUsageTagTableTable> {
  $$AppUsageTagTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get appUsageId => $composableBuilder(
      column: $table.appUsageId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tagId => $composableBuilder(
      column: $table.tagId, builder: (column) => ColumnOrderings(column));
}

class $$AppUsageTagTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppUsageTagTableTable> {
  $$AppUsageTagTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => column);

  GeneratedColumn<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => column);

  GeneratedColumn<String> get appUsageId => $composableBuilder(
      column: $table.appUsageId, builder: (column) => column);

  GeneratedColumn<String> get tagId =>
      $composableBuilder(column: $table.tagId, builder: (column) => column);
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
    (
      AppUsageTag,
      BaseReferences<_$AppDatabase, $AppUsageTagTableTable, AppUsageTag>
    ),
    AppUsageTag,
    PrefetchHooks Function()> {
  $$AppUsageTagTableTableTableManager(
      _$AppDatabase db, $AppUsageTagTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppUsageTagTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppUsageTagTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppUsageTagTableTableAnnotationComposer($db: db, $table: table),
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
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
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
    (
      AppUsageTag,
      BaseReferences<_$AppDatabase, $AppUsageTagTableTable, AppUsageTag>
    ),
    AppUsageTag,
    PrefetchHooks Function()>;
typedef $$AppUsageTimeRecordTableTableCreateCompanionBuilder
    = AppUsageTimeRecordTableCompanion Function({
  required String id,
  required String appUsageId,
  required int duration,
  required DateTime usageDate,
  required DateTime createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  Value<int> rowid,
});
typedef $$AppUsageTimeRecordTableTableUpdateCompanionBuilder
    = AppUsageTimeRecordTableCompanion Function({
  Value<String> id,
  Value<String> appUsageId,
  Value<int> duration,
  Value<DateTime> usageDate,
  Value<DateTime> createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  Value<int> rowid,
});

class $$AppUsageTimeRecordTableTableFilterComposer
    extends Composer<_$AppDatabase, $AppUsageTimeRecordTableTable> {
  $$AppUsageTimeRecordTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get appUsageId => $composableBuilder(
      column: $table.appUsageId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get duration => $composableBuilder(
      column: $table.duration, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get usageDate => $composableBuilder(
      column: $table.usageDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => ColumnFilters(column));
}

class $$AppUsageTimeRecordTableTableOrderingComposer
    extends Composer<_$AppDatabase, $AppUsageTimeRecordTableTable> {
  $$AppUsageTimeRecordTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get appUsageId => $composableBuilder(
      column: $table.appUsageId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get duration => $composableBuilder(
      column: $table.duration, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get usageDate => $composableBuilder(
      column: $table.usageDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => ColumnOrderings(column));
}

class $$AppUsageTimeRecordTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppUsageTimeRecordTableTable> {
  $$AppUsageTimeRecordTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get appUsageId => $composableBuilder(
      column: $table.appUsageId, builder: (column) => column);

  GeneratedColumn<int> get duration =>
      $composableBuilder(column: $table.duration, builder: (column) => column);

  GeneratedColumn<DateTime> get usageDate =>
      $composableBuilder(column: $table.usageDate, builder: (column) => column);

  GeneratedColumn<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => column);

  GeneratedColumn<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => column);
}

class $$AppUsageTimeRecordTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AppUsageTimeRecordTableTable,
    AppUsageTimeRecord,
    $$AppUsageTimeRecordTableTableFilterComposer,
    $$AppUsageTimeRecordTableTableOrderingComposer,
    $$AppUsageTimeRecordTableTableAnnotationComposer,
    $$AppUsageTimeRecordTableTableCreateCompanionBuilder,
    $$AppUsageTimeRecordTableTableUpdateCompanionBuilder,
    (
      AppUsageTimeRecord,
      BaseReferences<_$AppDatabase, $AppUsageTimeRecordTableTable,
          AppUsageTimeRecord>
    ),
    AppUsageTimeRecord,
    PrefetchHooks Function()> {
  $$AppUsageTimeRecordTableTableTableManager(
      _$AppDatabase db, $AppUsageTimeRecordTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppUsageTimeRecordTableTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$AppUsageTimeRecordTableTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppUsageTimeRecordTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> appUsageId = const Value.absent(),
            Value<int> duration = const Value.absent(),
            Value<DateTime> usageDate = const Value.absent(),
            Value<DateTime> createdDate = const Value.absent(),
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<DateTime?> deletedDate = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppUsageTimeRecordTableCompanion(
            id: id,
            appUsageId: appUsageId,
            duration: duration,
            usageDate: usageDate,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            deletedDate: deletedDate,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String appUsageId,
            required int duration,
            required DateTime usageDate,
            required DateTime createdDate,
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<DateTime?> deletedDate = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppUsageTimeRecordTableCompanion.insert(
            id: id,
            appUsageId: appUsageId,
            duration: duration,
            usageDate: usageDate,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            deletedDate: deletedDate,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AppUsageTimeRecordTableTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $AppUsageTimeRecordTableTable,
        AppUsageTimeRecord,
        $$AppUsageTimeRecordTableTableFilterComposer,
        $$AppUsageTimeRecordTableTableOrderingComposer,
        $$AppUsageTimeRecordTableTableAnnotationComposer,
        $$AppUsageTimeRecordTableTableCreateCompanionBuilder,
        $$AppUsageTimeRecordTableTableUpdateCompanionBuilder,
        (
          AppUsageTimeRecord,
          BaseReferences<_$AppDatabase, $AppUsageTimeRecordTableTable,
              AppUsageTimeRecord>
        ),
        AppUsageTimeRecord,
        PrefetchHooks Function()>;
typedef $$HabitRecordTableTableCreateCompanionBuilder
    = HabitRecordTableCompanion Function({
  required String id,
  required DateTime createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  required String habitId,
  required DateTime date,
  Value<int> rowid,
});
typedef $$HabitRecordTableTableUpdateCompanionBuilder
    = HabitRecordTableCompanion Function({
  Value<String> id,
  Value<DateTime> createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  Value<String> habitId,
  Value<DateTime> date,
  Value<int> rowid,
});

class $$HabitRecordTableTableFilterComposer
    extends Composer<_$AppDatabase, $HabitRecordTableTable> {
  $$HabitRecordTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get habitId => $composableBuilder(
      column: $table.habitId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnFilters(column));
}

class $$HabitRecordTableTableOrderingComposer
    extends Composer<_$AppDatabase, $HabitRecordTableTable> {
  $$HabitRecordTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get habitId => $composableBuilder(
      column: $table.habitId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnOrderings(column));
}

class $$HabitRecordTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $HabitRecordTableTable> {
  $$HabitRecordTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => column);

  GeneratedColumn<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => column);

  GeneratedColumn<String> get habitId =>
      $composableBuilder(column: $table.habitId, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);
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
    (
      HabitRecord,
      BaseReferences<_$AppDatabase, $HabitRecordTableTable, HabitRecord>
    ),
    HabitRecord,
    PrefetchHooks Function()> {
  $$HabitRecordTableTableTableManager(
      _$AppDatabase db, $HabitRecordTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HabitRecordTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HabitRecordTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HabitRecordTableTableAnnotationComposer($db: db, $table: table),
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
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
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
    (
      HabitRecord,
      BaseReferences<_$AppDatabase, $HabitRecordTableTable, HabitRecord>
    ),
    HabitRecord,
    PrefetchHooks Function()>;
typedef $$HabitTableTableCreateCompanionBuilder = HabitTableCompanion Function({
  required String id,
  required DateTime createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  required String name,
  required String description,
  Value<int?> estimatedTime,
  Value<DateTime?> archivedDate,
  Value<bool> hasReminder,
  Value<String?> reminderTime,
  Value<String> reminderDays,
  Value<bool> hasGoal,
  Value<int> targetFrequency,
  Value<int> periodDays,
  Value<double> order,
  Value<int> rowid,
});
typedef $$HabitTableTableUpdateCompanionBuilder = HabitTableCompanion Function({
  Value<String> id,
  Value<DateTime> createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  Value<String> name,
  Value<String> description,
  Value<int?> estimatedTime,
  Value<DateTime?> archivedDate,
  Value<bool> hasReminder,
  Value<String?> reminderTime,
  Value<String> reminderDays,
  Value<bool> hasGoal,
  Value<int> targetFrequency,
  Value<int> periodDays,
  Value<double> order,
  Value<int> rowid,
});

class $$HabitTableTableFilterComposer
    extends Composer<_$AppDatabase, $HabitTableTable> {
  $$HabitTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get estimatedTime => $composableBuilder(
      column: $table.estimatedTime, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get archivedDate => $composableBuilder(
      column: $table.archivedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get hasReminder => $composableBuilder(
      column: $table.hasReminder, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reminderTime => $composableBuilder(
      column: $table.reminderTime, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reminderDays => $composableBuilder(
      column: $table.reminderDays, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get hasGoal => $composableBuilder(
      column: $table.hasGoal, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get targetFrequency => $composableBuilder(
      column: $table.targetFrequency,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get periodDays => $composableBuilder(
      column: $table.periodDays, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get order => $composableBuilder(
      column: $table.order, builder: (column) => ColumnFilters(column));
}

class $$HabitTableTableOrderingComposer
    extends Composer<_$AppDatabase, $HabitTableTable> {
  $$HabitTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get estimatedTime => $composableBuilder(
      column: $table.estimatedTime,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get archivedDate => $composableBuilder(
      column: $table.archivedDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get hasReminder => $composableBuilder(
      column: $table.hasReminder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reminderTime => $composableBuilder(
      column: $table.reminderTime,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reminderDays => $composableBuilder(
      column: $table.reminderDays,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get hasGoal => $composableBuilder(
      column: $table.hasGoal, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get targetFrequency => $composableBuilder(
      column: $table.targetFrequency,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get periodDays => $composableBuilder(
      column: $table.periodDays, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get order => $composableBuilder(
      column: $table.order, builder: (column) => ColumnOrderings(column));
}

class $$HabitTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $HabitTableTable> {
  $$HabitTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => column);

  GeneratedColumn<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<int> get estimatedTime => $composableBuilder(
      column: $table.estimatedTime, builder: (column) => column);

  GeneratedColumn<DateTime> get archivedDate => $composableBuilder(
      column: $table.archivedDate, builder: (column) => column);

  GeneratedColumn<bool> get hasReminder => $composableBuilder(
      column: $table.hasReminder, builder: (column) => column);

  GeneratedColumn<String> get reminderTime => $composableBuilder(
      column: $table.reminderTime, builder: (column) => column);

  GeneratedColumn<String> get reminderDays => $composableBuilder(
      column: $table.reminderDays, builder: (column) => column);

  GeneratedColumn<bool> get hasGoal =>
      $composableBuilder(column: $table.hasGoal, builder: (column) => column);

  GeneratedColumn<int> get targetFrequency => $composableBuilder(
      column: $table.targetFrequency, builder: (column) => column);

  GeneratedColumn<int> get periodDays => $composableBuilder(
      column: $table.periodDays, builder: (column) => column);

  GeneratedColumn<double> get order =>
      $composableBuilder(column: $table.order, builder: (column) => column);
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
          createFilteringComposer: () =>
              $$HabitTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HabitTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HabitTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<DateTime> createdDate = const Value.absent(),
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<DateTime?> deletedDate = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> description = const Value.absent(),
            Value<int?> estimatedTime = const Value.absent(),
            Value<DateTime?> archivedDate = const Value.absent(),
            Value<bool> hasReminder = const Value.absent(),
            Value<String?> reminderTime = const Value.absent(),
            Value<String> reminderDays = const Value.absent(),
            Value<bool> hasGoal = const Value.absent(),
            Value<int> targetFrequency = const Value.absent(),
            Value<int> periodDays = const Value.absent(),
            Value<double> order = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              HabitTableCompanion(
            id: id,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            deletedDate: deletedDate,
            name: name,
            description: description,
            estimatedTime: estimatedTime,
            archivedDate: archivedDate,
            hasReminder: hasReminder,
            reminderTime: reminderTime,
            reminderDays: reminderDays,
            hasGoal: hasGoal,
            targetFrequency: targetFrequency,
            periodDays: periodDays,
            order: order,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required DateTime createdDate,
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<DateTime?> deletedDate = const Value.absent(),
            required String name,
            required String description,
            Value<int?> estimatedTime = const Value.absent(),
            Value<DateTime?> archivedDate = const Value.absent(),
            Value<bool> hasReminder = const Value.absent(),
            Value<String?> reminderTime = const Value.absent(),
            Value<String> reminderDays = const Value.absent(),
            Value<bool> hasGoal = const Value.absent(),
            Value<int> targetFrequency = const Value.absent(),
            Value<int> periodDays = const Value.absent(),
            Value<double> order = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              HabitTableCompanion.insert(
            id: id,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            deletedDate: deletedDate,
            name: name,
            description: description,
            estimatedTime: estimatedTime,
            archivedDate: archivedDate,
            hasReminder: hasReminder,
            reminderTime: reminderTime,
            reminderDays: reminderDays,
            hasGoal: hasGoal,
            targetFrequency: targetFrequency,
            periodDays: periodDays,
            order: order,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
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
typedef $$HabitTagTableTableCreateCompanionBuilder = HabitTagTableCompanion
    Function({
  required String id,
  required DateTime createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  required String habitId,
  required String tagId,
  Value<int> rowid,
});
typedef $$HabitTagTableTableUpdateCompanionBuilder = HabitTagTableCompanion
    Function({
  Value<String> id,
  Value<DateTime> createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  Value<String> habitId,
  Value<String> tagId,
  Value<int> rowid,
});

class $$HabitTagTableTableFilterComposer
    extends Composer<_$AppDatabase, $HabitTagTableTable> {
  $$HabitTagTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get habitId => $composableBuilder(
      column: $table.habitId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tagId => $composableBuilder(
      column: $table.tagId, builder: (column) => ColumnFilters(column));
}

class $$HabitTagTableTableOrderingComposer
    extends Composer<_$AppDatabase, $HabitTagTableTable> {
  $$HabitTagTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get habitId => $composableBuilder(
      column: $table.habitId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tagId => $composableBuilder(
      column: $table.tagId, builder: (column) => ColumnOrderings(column));
}

class $$HabitTagTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $HabitTagTableTable> {
  $$HabitTagTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => column);

  GeneratedColumn<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => column);

  GeneratedColumn<String> get habitId =>
      $composableBuilder(column: $table.habitId, builder: (column) => column);

  GeneratedColumn<String> get tagId =>
      $composableBuilder(column: $table.tagId, builder: (column) => column);
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
          createFilteringComposer: () =>
              $$HabitTagTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HabitTagTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HabitTagTableTableAnnotationComposer($db: db, $table: table),
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
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
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
typedef $$NoteTableTableCreateCompanionBuilder = NoteTableCompanion Function({
  required String id,
  required String title,
  Value<String?> content,
  Value<double> order,
  required DateTime createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  Value<int> rowid,
});
typedef $$NoteTableTableUpdateCompanionBuilder = NoteTableCompanion Function({
  Value<String> id,
  Value<String> title,
  Value<String?> content,
  Value<double> order,
  Value<DateTime> createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  Value<int> rowid,
});

class $$NoteTableTableFilterComposer
    extends Composer<_$AppDatabase, $NoteTableTable> {
  $$NoteTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get order => $composableBuilder(
      column: $table.order, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => ColumnFilters(column));
}

class $$NoteTableTableOrderingComposer
    extends Composer<_$AppDatabase, $NoteTableTable> {
  $$NoteTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get order => $composableBuilder(
      column: $table.order, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => ColumnOrderings(column));
}

class $$NoteTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $NoteTableTable> {
  $$NoteTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<double> get order =>
      $composableBuilder(column: $table.order, builder: (column) => column);

  GeneratedColumn<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => column);

  GeneratedColumn<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => column);
}

class $$NoteTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $NoteTableTable,
    Note,
    $$NoteTableTableFilterComposer,
    $$NoteTableTableOrderingComposer,
    $$NoteTableTableAnnotationComposer,
    $$NoteTableTableCreateCompanionBuilder,
    $$NoteTableTableUpdateCompanionBuilder,
    (Note, BaseReferences<_$AppDatabase, $NoteTableTable, Note>),
    Note,
    PrefetchHooks Function()> {
  $$NoteTableTableTableManager(_$AppDatabase db, $NoteTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NoteTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NoteTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NoteTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> content = const Value.absent(),
            Value<double> order = const Value.absent(),
            Value<DateTime> createdDate = const Value.absent(),
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<DateTime?> deletedDate = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              NoteTableCompanion(
            id: id,
            title: title,
            content: content,
            order: order,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            deletedDate: deletedDate,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String title,
            Value<String?> content = const Value.absent(),
            Value<double> order = const Value.absent(),
            required DateTime createdDate,
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<DateTime?> deletedDate = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              NoteTableCompanion.insert(
            id: id,
            title: title,
            content: content,
            order: order,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            deletedDate: deletedDate,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$NoteTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $NoteTableTable,
    Note,
    $$NoteTableTableFilterComposer,
    $$NoteTableTableOrderingComposer,
    $$NoteTableTableAnnotationComposer,
    $$NoteTableTableCreateCompanionBuilder,
    $$NoteTableTableUpdateCompanionBuilder,
    (Note, BaseReferences<_$AppDatabase, $NoteTableTable, Note>),
    Note,
    PrefetchHooks Function()>;
typedef $$NoteTagTableTableCreateCompanionBuilder = NoteTagTableCompanion
    Function({
  required String id,
  required String noteId,
  required String tagId,
  required DateTime createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  Value<int> rowid,
});
typedef $$NoteTagTableTableUpdateCompanionBuilder = NoteTagTableCompanion
    Function({
  Value<String> id,
  Value<String> noteId,
  Value<String> tagId,
  Value<DateTime> createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  Value<int> rowid,
});

class $$NoteTagTableTableFilterComposer
    extends Composer<_$AppDatabase, $NoteTagTableTable> {
  $$NoteTagTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get noteId => $composableBuilder(
      column: $table.noteId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tagId => $composableBuilder(
      column: $table.tagId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => ColumnFilters(column));
}

class $$NoteTagTableTableOrderingComposer
    extends Composer<_$AppDatabase, $NoteTagTableTable> {
  $$NoteTagTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get noteId => $composableBuilder(
      column: $table.noteId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tagId => $composableBuilder(
      column: $table.tagId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => ColumnOrderings(column));
}

class $$NoteTagTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $NoteTagTableTable> {
  $$NoteTagTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get noteId =>
      $composableBuilder(column: $table.noteId, builder: (column) => column);

  GeneratedColumn<String> get tagId =>
      $composableBuilder(column: $table.tagId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => column);

  GeneratedColumn<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => column);
}

class $$NoteTagTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $NoteTagTableTable,
    NoteTag,
    $$NoteTagTableTableFilterComposer,
    $$NoteTagTableTableOrderingComposer,
    $$NoteTagTableTableAnnotationComposer,
    $$NoteTagTableTableCreateCompanionBuilder,
    $$NoteTagTableTableUpdateCompanionBuilder,
    (NoteTag, BaseReferences<_$AppDatabase, $NoteTagTableTable, NoteTag>),
    NoteTag,
    PrefetchHooks Function()> {
  $$NoteTagTableTableTableManager(_$AppDatabase db, $NoteTagTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NoteTagTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NoteTagTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NoteTagTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> noteId = const Value.absent(),
            Value<String> tagId = const Value.absent(),
            Value<DateTime> createdDate = const Value.absent(),
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<DateTime?> deletedDate = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              NoteTagTableCompanion(
            id: id,
            noteId: noteId,
            tagId: tagId,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            deletedDate: deletedDate,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String noteId,
            required String tagId,
            required DateTime createdDate,
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<DateTime?> deletedDate = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              NoteTagTableCompanion.insert(
            id: id,
            noteId: noteId,
            tagId: tagId,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            deletedDate: deletedDate,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$NoteTagTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $NoteTagTableTable,
    NoteTag,
    $$NoteTagTableTableFilterComposer,
    $$NoteTagTableTableOrderingComposer,
    $$NoteTagTableTableAnnotationComposer,
    $$NoteTagTableTableCreateCompanionBuilder,
    $$NoteTagTableTableUpdateCompanionBuilder,
    (NoteTag, BaseReferences<_$AppDatabase, $NoteTagTableTable, NoteTag>),
    NoteTag,
    PrefetchHooks Function()>;
typedef $$SettingTableTableCreateCompanionBuilder = SettingTableCompanion
    Function({
  required String id,
  required DateTime createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  required String key,
  required String value,
  required SettingValueType valueType,
  Value<int> rowid,
});
typedef $$SettingTableTableUpdateCompanionBuilder = SettingTableCompanion
    Function({
  Value<String> id,
  Value<DateTime> createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  Value<String> key,
  Value<String> value,
  Value<SettingValueType> valueType,
  Value<int> rowid,
});

class $$SettingTableTableFilterComposer
    extends Composer<_$AppDatabase, $SettingTableTable> {
  $$SettingTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<SettingValueType, SettingValueType, int>
      get valueType => $composableBuilder(
          column: $table.valueType,
          builder: (column) => ColumnWithTypeConverterFilters(column));
}

class $$SettingTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingTableTable> {
  $$SettingTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get valueType => $composableBuilder(
      column: $table.valueType, builder: (column) => ColumnOrderings(column));
}

class $$SettingTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingTableTable> {
  $$SettingTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => column);

  GeneratedColumn<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

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
          createFilteringComposer: () =>
              $$SettingTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingTableTableAnnotationComposer($db: db, $table: table),
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
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
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
typedef $$SyncDeviceTableTableCreateCompanionBuilder = SyncDeviceTableCompanion
    Function({
  required String id,
  required DateTime createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  required String fromIp,
  required String toIp,
  required String fromDeviceId,
  required String toDeviceId,
  Value<String?> name,
  Value<DateTime?> lastSyncDate,
  Value<int> rowid,
});
typedef $$SyncDeviceTableTableUpdateCompanionBuilder = SyncDeviceTableCompanion
    Function({
  Value<String> id,
  Value<DateTime> createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  Value<String> fromIp,
  Value<String> toIp,
  Value<String> fromDeviceId,
  Value<String> toDeviceId,
  Value<String?> name,
  Value<DateTime?> lastSyncDate,
  Value<int> rowid,
});

class $$SyncDeviceTableTableFilterComposer
    extends Composer<_$AppDatabase, $SyncDeviceTableTable> {
  $$SyncDeviceTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fromIp => $composableBuilder(
      column: $table.fromIp, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get toIp => $composableBuilder(
      column: $table.toIp, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fromDeviceId => $composableBuilder(
      column: $table.fromDeviceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get toDeviceId => $composableBuilder(
      column: $table.toDeviceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastSyncDate => $composableBuilder(
      column: $table.lastSyncDate, builder: (column) => ColumnFilters(column));
}

class $$SyncDeviceTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncDeviceTableTable> {
  $$SyncDeviceTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fromIp => $composableBuilder(
      column: $table.fromIp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get toIp => $composableBuilder(
      column: $table.toIp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fromDeviceId => $composableBuilder(
      column: $table.fromDeviceId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get toDeviceId => $composableBuilder(
      column: $table.toDeviceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastSyncDate => $composableBuilder(
      column: $table.lastSyncDate,
      builder: (column) => ColumnOrderings(column));
}

class $$SyncDeviceTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncDeviceTableTable> {
  $$SyncDeviceTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => column);

  GeneratedColumn<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => column);

  GeneratedColumn<String> get fromIp =>
      $composableBuilder(column: $table.fromIp, builder: (column) => column);

  GeneratedColumn<String> get toIp =>
      $composableBuilder(column: $table.toIp, builder: (column) => column);

  GeneratedColumn<String> get fromDeviceId => $composableBuilder(
      column: $table.fromDeviceId, builder: (column) => column);

  GeneratedColumn<String> get toDeviceId => $composableBuilder(
      column: $table.toDeviceId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSyncDate => $composableBuilder(
      column: $table.lastSyncDate, builder: (column) => column);
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
    (
      SyncDevice,
      BaseReferences<_$AppDatabase, $SyncDeviceTableTable, SyncDevice>
    ),
    SyncDevice,
    PrefetchHooks Function()> {
  $$SyncDeviceTableTableTableManager(
      _$AppDatabase db, $SyncDeviceTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncDeviceTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncDeviceTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncDeviceTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<DateTime> createdDate = const Value.absent(),
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<DateTime?> deletedDate = const Value.absent(),
            Value<String> fromIp = const Value.absent(),
            Value<String> toIp = const Value.absent(),
            Value<String> fromDeviceId = const Value.absent(),
            Value<String> toDeviceId = const Value.absent(),
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
            fromDeviceId: fromDeviceId,
            toDeviceId: toDeviceId,
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
            required String fromDeviceId,
            required String toDeviceId,
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
            fromDeviceId: fromDeviceId,
            toDeviceId: toDeviceId,
            name: name,
            lastSyncDate: lastSyncDate,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
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
    (
      SyncDevice,
      BaseReferences<_$AppDatabase, $SyncDeviceTableTable, SyncDevice>
    ),
    SyncDevice,
    PrefetchHooks Function()>;
typedef $$TagTableTableCreateCompanionBuilder = TagTableCompanion Function({
  required String id,
  required DateTime createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  required String name,
  Value<String?> color,
  Value<bool> isArchived,
  Value<int> rowid,
});
typedef $$TagTableTableUpdateCompanionBuilder = TagTableCompanion Function({
  Value<String> id,
  Value<DateTime> createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  Value<String> name,
  Value<String?> color,
  Value<bool> isArchived,
  Value<int> rowid,
});

class $$TagTableTableFilterComposer
    extends Composer<_$AppDatabase, $TagTableTable> {
  $$TagTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isArchived => $composableBuilder(
      column: $table.isArchived, builder: (column) => ColumnFilters(column));
}

class $$TagTableTableOrderingComposer
    extends Composer<_$AppDatabase, $TagTableTable> {
  $$TagTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isArchived => $composableBuilder(
      column: $table.isArchived, builder: (column) => ColumnOrderings(column));
}

class $$TagTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $TagTableTable> {
  $$TagTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => column);

  GeneratedColumn<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<bool> get isArchived => $composableBuilder(
      column: $table.isArchived, builder: (column) => column);
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
          createFilteringComposer: () =>
              $$TagTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<DateTime> createdDate = const Value.absent(),
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<DateTime?> deletedDate = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> color = const Value.absent(),
            Value<bool> isArchived = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TagTableCompanion(
            id: id,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            deletedDate: deletedDate,
            name: name,
            color: color,
            isArchived: isArchived,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required DateTime createdDate,
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<DateTime?> deletedDate = const Value.absent(),
            required String name,
            Value<String?> color = const Value.absent(),
            Value<bool> isArchived = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TagTableCompanion.insert(
            id: id,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            deletedDate: deletedDate,
            name: name,
            color: color,
            isArchived: isArchived,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
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
typedef $$TagTagTableTableCreateCompanionBuilder = TagTagTableCompanion
    Function({
  required String id,
  required DateTime createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  required String primaryTagId,
  required String secondaryTagId,
  Value<int> rowid,
});
typedef $$TagTagTableTableUpdateCompanionBuilder = TagTagTableCompanion
    Function({
  Value<String> id,
  Value<DateTime> createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  Value<String> primaryTagId,
  Value<String> secondaryTagId,
  Value<int> rowid,
});

class $$TagTagTableTableFilterComposer
    extends Composer<_$AppDatabase, $TagTagTableTable> {
  $$TagTagTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get primaryTagId => $composableBuilder(
      column: $table.primaryTagId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get secondaryTagId => $composableBuilder(
      column: $table.secondaryTagId,
      builder: (column) => ColumnFilters(column));
}

class $$TagTagTableTableOrderingComposer
    extends Composer<_$AppDatabase, $TagTagTableTable> {
  $$TagTagTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get primaryTagId => $composableBuilder(
      column: $table.primaryTagId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get secondaryTagId => $composableBuilder(
      column: $table.secondaryTagId,
      builder: (column) => ColumnOrderings(column));
}

class $$TagTagTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $TagTagTableTable> {
  $$TagTagTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => column);

  GeneratedColumn<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => column);

  GeneratedColumn<String> get primaryTagId => $composableBuilder(
      column: $table.primaryTagId, builder: (column) => column);

  GeneratedColumn<String> get secondaryTagId => $composableBuilder(
      column: $table.secondaryTagId, builder: (column) => column);
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
          createFilteringComposer: () =>
              $$TagTagTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagTagTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagTagTableTableAnnotationComposer($db: db, $table: table),
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
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
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
typedef $$TaskTableTableCreateCompanionBuilder = TaskTableCompanion Function({
  required String id,
  Value<String?> parentTaskId,
  required String title,
  Value<String?> description,
  Value<EisenhowerPriority?> priority,
  Value<DateTime?> plannedDate,
  Value<DateTime?> deadlineDate,
  Value<int?> estimatedTime,
  Value<bool> isCompleted,
  required DateTime createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  Value<double> order,
  Value<ReminderTime> plannedDateReminderTime,
  Value<ReminderTime> deadlineDateReminderTime,
  Value<RecurrenceType> recurrenceType,
  Value<int?> recurrenceInterval,
  Value<String?> recurrenceDaysString,
  Value<DateTime?> recurrenceStartDate,
  Value<DateTime?> recurrenceEndDate,
  Value<int?> recurrenceCount,
  Value<String?> recurrenceParentId,
  Value<int> rowid,
});
typedef $$TaskTableTableUpdateCompanionBuilder = TaskTableCompanion Function({
  Value<String> id,
  Value<String?> parentTaskId,
  Value<String> title,
  Value<String?> description,
  Value<EisenhowerPriority?> priority,
  Value<DateTime?> plannedDate,
  Value<DateTime?> deadlineDate,
  Value<int?> estimatedTime,
  Value<bool> isCompleted,
  Value<DateTime> createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  Value<double> order,
  Value<ReminderTime> plannedDateReminderTime,
  Value<ReminderTime> deadlineDateReminderTime,
  Value<RecurrenceType> recurrenceType,
  Value<int?> recurrenceInterval,
  Value<String?> recurrenceDaysString,
  Value<DateTime?> recurrenceStartDate,
  Value<DateTime?> recurrenceEndDate,
  Value<int?> recurrenceCount,
  Value<String?> recurrenceParentId,
  Value<int> rowid,
});

class $$TaskTableTableFilterComposer
    extends Composer<_$AppDatabase, $TaskTableTable> {
  $$TaskTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get parentTaskId => $composableBuilder(
      column: $table.parentTaskId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<EisenhowerPriority?, EisenhowerPriority, int>
      get priority => $composableBuilder(
          column: $table.priority,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<DateTime> get plannedDate => $composableBuilder(
      column: $table.plannedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deadlineDate => $composableBuilder(
      column: $table.deadlineDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get estimatedTime => $composableBuilder(
      column: $table.estimatedTime, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isCompleted => $composableBuilder(
      column: $table.isCompleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get order => $composableBuilder(
      column: $table.order, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<ReminderTime, ReminderTime, int>
      get plannedDateReminderTime => $composableBuilder(
          column: $table.plannedDateReminderTime,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnWithTypeConverterFilters<ReminderTime, ReminderTime, int>
      get deadlineDateReminderTime => $composableBuilder(
          column: $table.deadlineDateReminderTime,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnWithTypeConverterFilters<RecurrenceType, RecurrenceType, int>
      get recurrenceType => $composableBuilder(
          column: $table.recurrenceType,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<int> get recurrenceInterval => $composableBuilder(
      column: $table.recurrenceInterval,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recurrenceDaysString => $composableBuilder(
      column: $table.recurrenceDaysString,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get recurrenceStartDate => $composableBuilder(
      column: $table.recurrenceStartDate,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get recurrenceEndDate => $composableBuilder(
      column: $table.recurrenceEndDate,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get recurrenceCount => $composableBuilder(
      column: $table.recurrenceCount,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recurrenceParentId => $composableBuilder(
      column: $table.recurrenceParentId,
      builder: (column) => ColumnFilters(column));
}

class $$TaskTableTableOrderingComposer
    extends Composer<_$AppDatabase, $TaskTableTable> {
  $$TaskTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get parentTaskId => $composableBuilder(
      column: $table.parentTaskId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get priority => $composableBuilder(
      column: $table.priority, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get plannedDate => $composableBuilder(
      column: $table.plannedDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deadlineDate => $composableBuilder(
      column: $table.deadlineDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get estimatedTime => $composableBuilder(
      column: $table.estimatedTime,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isCompleted => $composableBuilder(
      column: $table.isCompleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get order => $composableBuilder(
      column: $table.order, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get plannedDateReminderTime => $composableBuilder(
      column: $table.plannedDateReminderTime,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get deadlineDateReminderTime => $composableBuilder(
      column: $table.deadlineDateReminderTime,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get recurrenceType => $composableBuilder(
      column: $table.recurrenceType,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get recurrenceInterval => $composableBuilder(
      column: $table.recurrenceInterval,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recurrenceDaysString => $composableBuilder(
      column: $table.recurrenceDaysString,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get recurrenceStartDate => $composableBuilder(
      column: $table.recurrenceStartDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get recurrenceEndDate => $composableBuilder(
      column: $table.recurrenceEndDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get recurrenceCount => $composableBuilder(
      column: $table.recurrenceCount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recurrenceParentId => $composableBuilder(
      column: $table.recurrenceParentId,
      builder: (column) => ColumnOrderings(column));
}

class $$TaskTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $TaskTableTable> {
  $$TaskTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get parentTaskId => $composableBuilder(
      column: $table.parentTaskId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumnWithTypeConverter<EisenhowerPriority?, int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<DateTime> get plannedDate => $composableBuilder(
      column: $table.plannedDate, builder: (column) => column);

  GeneratedColumn<DateTime> get deadlineDate => $composableBuilder(
      column: $table.deadlineDate, builder: (column) => column);

  GeneratedColumn<int> get estimatedTime => $composableBuilder(
      column: $table.estimatedTime, builder: (column) => column);

  GeneratedColumn<bool> get isCompleted => $composableBuilder(
      column: $table.isCompleted, builder: (column) => column);

  GeneratedColumn<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => column);

  GeneratedColumn<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => column);

  GeneratedColumn<double> get order =>
      $composableBuilder(column: $table.order, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ReminderTime, int>
      get plannedDateReminderTime => $composableBuilder(
          column: $table.plannedDateReminderTime, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ReminderTime, int>
      get deadlineDateReminderTime => $composableBuilder(
          column: $table.deadlineDateReminderTime, builder: (column) => column);

  GeneratedColumnWithTypeConverter<RecurrenceType, int> get recurrenceType =>
      $composableBuilder(
          column: $table.recurrenceType, builder: (column) => column);

  GeneratedColumn<int> get recurrenceInterval => $composableBuilder(
      column: $table.recurrenceInterval, builder: (column) => column);

  GeneratedColumn<String> get recurrenceDaysString => $composableBuilder(
      column: $table.recurrenceDaysString, builder: (column) => column);

  GeneratedColumn<DateTime> get recurrenceStartDate => $composableBuilder(
      column: $table.recurrenceStartDate, builder: (column) => column);

  GeneratedColumn<DateTime> get recurrenceEndDate => $composableBuilder(
      column: $table.recurrenceEndDate, builder: (column) => column);

  GeneratedColumn<int> get recurrenceCount => $composableBuilder(
      column: $table.recurrenceCount, builder: (column) => column);

  GeneratedColumn<String> get recurrenceParentId => $composableBuilder(
      column: $table.recurrenceParentId, builder: (column) => column);
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
          createFilteringComposer: () =>
              $$TaskTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TaskTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TaskTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String?> parentTaskId = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<EisenhowerPriority?> priority = const Value.absent(),
            Value<DateTime?> plannedDate = const Value.absent(),
            Value<DateTime?> deadlineDate = const Value.absent(),
            Value<int?> estimatedTime = const Value.absent(),
            Value<bool> isCompleted = const Value.absent(),
            Value<DateTime> createdDate = const Value.absent(),
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<DateTime?> deletedDate = const Value.absent(),
            Value<double> order = const Value.absent(),
            Value<ReminderTime> plannedDateReminderTime = const Value.absent(),
            Value<ReminderTime> deadlineDateReminderTime = const Value.absent(),
            Value<RecurrenceType> recurrenceType = const Value.absent(),
            Value<int?> recurrenceInterval = const Value.absent(),
            Value<String?> recurrenceDaysString = const Value.absent(),
            Value<DateTime?> recurrenceStartDate = const Value.absent(),
            Value<DateTime?> recurrenceEndDate = const Value.absent(),
            Value<int?> recurrenceCount = const Value.absent(),
            Value<String?> recurrenceParentId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TaskTableCompanion(
            id: id,
            parentTaskId: parentTaskId,
            title: title,
            description: description,
            priority: priority,
            plannedDate: plannedDate,
            deadlineDate: deadlineDate,
            estimatedTime: estimatedTime,
            isCompleted: isCompleted,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            deletedDate: deletedDate,
            order: order,
            plannedDateReminderTime: plannedDateReminderTime,
            deadlineDateReminderTime: deadlineDateReminderTime,
            recurrenceType: recurrenceType,
            recurrenceInterval: recurrenceInterval,
            recurrenceDaysString: recurrenceDaysString,
            recurrenceStartDate: recurrenceStartDate,
            recurrenceEndDate: recurrenceEndDate,
            recurrenceCount: recurrenceCount,
            recurrenceParentId: recurrenceParentId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<String?> parentTaskId = const Value.absent(),
            required String title,
            Value<String?> description = const Value.absent(),
            Value<EisenhowerPriority?> priority = const Value.absent(),
            Value<DateTime?> plannedDate = const Value.absent(),
            Value<DateTime?> deadlineDate = const Value.absent(),
            Value<int?> estimatedTime = const Value.absent(),
            Value<bool> isCompleted = const Value.absent(),
            required DateTime createdDate,
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<DateTime?> deletedDate = const Value.absent(),
            Value<double> order = const Value.absent(),
            Value<ReminderTime> plannedDateReminderTime = const Value.absent(),
            Value<ReminderTime> deadlineDateReminderTime = const Value.absent(),
            Value<RecurrenceType> recurrenceType = const Value.absent(),
            Value<int?> recurrenceInterval = const Value.absent(),
            Value<String?> recurrenceDaysString = const Value.absent(),
            Value<DateTime?> recurrenceStartDate = const Value.absent(),
            Value<DateTime?> recurrenceEndDate = const Value.absent(),
            Value<int?> recurrenceCount = const Value.absent(),
            Value<String?> recurrenceParentId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TaskTableCompanion.insert(
            id: id,
            parentTaskId: parentTaskId,
            title: title,
            description: description,
            priority: priority,
            plannedDate: plannedDate,
            deadlineDate: deadlineDate,
            estimatedTime: estimatedTime,
            isCompleted: isCompleted,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            deletedDate: deletedDate,
            order: order,
            plannedDateReminderTime: plannedDateReminderTime,
            deadlineDateReminderTime: deadlineDateReminderTime,
            recurrenceType: recurrenceType,
            recurrenceInterval: recurrenceInterval,
            recurrenceDaysString: recurrenceDaysString,
            recurrenceStartDate: recurrenceStartDate,
            recurrenceEndDate: recurrenceEndDate,
            recurrenceCount: recurrenceCount,
            recurrenceParentId: recurrenceParentId,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
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
typedef $$TaskTagTableTableCreateCompanionBuilder = TaskTagTableCompanion
    Function({
  required String id,
  required DateTime createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  required String taskId,
  required String tagId,
  Value<int> rowid,
});
typedef $$TaskTagTableTableUpdateCompanionBuilder = TaskTagTableCompanion
    Function({
  Value<String> id,
  Value<DateTime> createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  Value<String> taskId,
  Value<String> tagId,
  Value<int> rowid,
});

class $$TaskTagTableTableFilterComposer
    extends Composer<_$AppDatabase, $TaskTagTableTable> {
  $$TaskTagTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get taskId => $composableBuilder(
      column: $table.taskId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tagId => $composableBuilder(
      column: $table.tagId, builder: (column) => ColumnFilters(column));
}

class $$TaskTagTableTableOrderingComposer
    extends Composer<_$AppDatabase, $TaskTagTableTable> {
  $$TaskTagTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get taskId => $composableBuilder(
      column: $table.taskId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tagId => $composableBuilder(
      column: $table.tagId, builder: (column) => ColumnOrderings(column));
}

class $$TaskTagTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $TaskTagTableTable> {
  $$TaskTagTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => column);

  GeneratedColumn<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => column);

  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<String> get tagId =>
      $composableBuilder(column: $table.tagId, builder: (column) => column);
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
          createFilteringComposer: () =>
              $$TaskTagTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TaskTagTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TaskTagTableTableAnnotationComposer($db: db, $table: table),
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
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
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
typedef $$TaskTimeRecordTableTableCreateCompanionBuilder
    = TaskTimeRecordTableCompanion Function({
  required String id,
  required String taskId,
  required int duration,
  required DateTime createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  Value<int> rowid,
});
typedef $$TaskTimeRecordTableTableUpdateCompanionBuilder
    = TaskTimeRecordTableCompanion Function({
  Value<String> id,
  Value<String> taskId,
  Value<int> duration,
  Value<DateTime> createdDate,
  Value<DateTime?> modifiedDate,
  Value<DateTime?> deletedDate,
  Value<int> rowid,
});

class $$TaskTimeRecordTableTableFilterComposer
    extends Composer<_$AppDatabase, $TaskTimeRecordTableTable> {
  $$TaskTimeRecordTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get taskId => $composableBuilder(
      column: $table.taskId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get duration => $composableBuilder(
      column: $table.duration, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => ColumnFilters(column));
}

class $$TaskTimeRecordTableTableOrderingComposer
    extends Composer<_$AppDatabase, $TaskTimeRecordTableTable> {
  $$TaskTimeRecordTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get taskId => $composableBuilder(
      column: $table.taskId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get duration => $composableBuilder(
      column: $table.duration, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => ColumnOrderings(column));
}

class $$TaskTimeRecordTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $TaskTimeRecordTableTable> {
  $$TaskTimeRecordTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<int> get duration =>
      $composableBuilder(column: $table.duration, builder: (column) => column);

  GeneratedColumn<DateTime> get createdDate => $composableBuilder(
      column: $table.createdDate, builder: (column) => column);

  GeneratedColumn<DateTime> get modifiedDate => $composableBuilder(
      column: $table.modifiedDate, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedDate => $composableBuilder(
      column: $table.deletedDate, builder: (column) => column);
}

class $$TaskTimeRecordTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TaskTimeRecordTableTable,
    TaskTimeRecord,
    $$TaskTimeRecordTableTableFilterComposer,
    $$TaskTimeRecordTableTableOrderingComposer,
    $$TaskTimeRecordTableTableAnnotationComposer,
    $$TaskTimeRecordTableTableCreateCompanionBuilder,
    $$TaskTimeRecordTableTableUpdateCompanionBuilder,
    (
      TaskTimeRecord,
      BaseReferences<_$AppDatabase, $TaskTimeRecordTableTable, TaskTimeRecord>
    ),
    TaskTimeRecord,
    PrefetchHooks Function()> {
  $$TaskTimeRecordTableTableTableManager(
      _$AppDatabase db, $TaskTimeRecordTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TaskTimeRecordTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TaskTimeRecordTableTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TaskTimeRecordTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> taskId = const Value.absent(),
            Value<int> duration = const Value.absent(),
            Value<DateTime> createdDate = const Value.absent(),
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<DateTime?> deletedDate = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TaskTimeRecordTableCompanion(
            id: id,
            taskId: taskId,
            duration: duration,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            deletedDate: deletedDate,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String taskId,
            required int duration,
            required DateTime createdDate,
            Value<DateTime?> modifiedDate = const Value.absent(),
            Value<DateTime?> deletedDate = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TaskTimeRecordTableCompanion.insert(
            id: id,
            taskId: taskId,
            duration: duration,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            deletedDate: deletedDate,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TaskTimeRecordTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TaskTimeRecordTableTable,
    TaskTimeRecord,
    $$TaskTimeRecordTableTableFilterComposer,
    $$TaskTimeRecordTableTableOrderingComposer,
    $$TaskTimeRecordTableTableAnnotationComposer,
    $$TaskTimeRecordTableTableCreateCompanionBuilder,
    $$TaskTimeRecordTableTableUpdateCompanionBuilder,
    (
      TaskTimeRecord,
      BaseReferences<_$AppDatabase, $TaskTimeRecordTableTable, TaskTimeRecord>
    ),
    TaskTimeRecord,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AppUsageIgnoreRuleTableTableTableManager get appUsageIgnoreRuleTable =>
      $$AppUsageIgnoreRuleTableTableTableManager(
          _db, _db.appUsageIgnoreRuleTable);
  $$AppUsageTableTableTableManager get appUsageTable =>
      $$AppUsageTableTableTableManager(_db, _db.appUsageTable);
  $$AppUsageTagRuleTableTableTableManager get appUsageTagRuleTable =>
      $$AppUsageTagRuleTableTableTableManager(_db, _db.appUsageTagRuleTable);
  $$AppUsageTagTableTableTableManager get appUsageTagTable =>
      $$AppUsageTagTableTableTableManager(_db, _db.appUsageTagTable);
  $$AppUsageTimeRecordTableTableTableManager get appUsageTimeRecordTable =>
      $$AppUsageTimeRecordTableTableTableManager(
          _db, _db.appUsageTimeRecordTable);
  $$HabitRecordTableTableTableManager get habitRecordTable =>
      $$HabitRecordTableTableTableManager(_db, _db.habitRecordTable);
  $$HabitTableTableTableManager get habitTable =>
      $$HabitTableTableTableManager(_db, _db.habitTable);
  $$HabitTagTableTableTableManager get habitTagTable =>
      $$HabitTagTableTableTableManager(_db, _db.habitTagTable);
  $$NoteTableTableTableManager get noteTable =>
      $$NoteTableTableTableManager(_db, _db.noteTable);
  $$NoteTagTableTableTableManager get noteTagTable =>
      $$NoteTagTableTableTableManager(_db, _db.noteTagTable);
  $$SettingTableTableTableManager get settingTable =>
      $$SettingTableTableTableManager(_db, _db.settingTable);
  $$SyncDeviceTableTableTableManager get syncDeviceTable =>
      $$SyncDeviceTableTableTableManager(_db, _db.syncDeviceTable);
  $$TagTableTableTableManager get tagTable =>
      $$TagTableTableTableManager(_db, _db.tagTable);
  $$TagTagTableTableTableManager get tagTagTable =>
      $$TagTagTableTableTableManager(_db, _db.tagTagTable);
  $$TaskTableTableTableManager get taskTable =>
      $$TaskTableTableTableManager(_db, _db.taskTable);
  $$TaskTagTableTableTableManager get taskTagTable =>
      $$TaskTagTableTableTableManager(_db, _db.taskTagTable);
  $$TaskTimeRecordTableTableTableManager get taskTimeRecordTable =>
      $$TaskTimeRecordTableTableTableManager(_db, _db.taskTimeRecordTable);
}

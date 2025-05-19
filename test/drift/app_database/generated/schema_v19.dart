// dart format width=80
// GENERATED CODE, DO NOT EDIT BY HAND.
// ignore_for_file: type=lint
import 'package:drift/drift.dart';

class AppUsageIgnoreRuleTable extends Table with TableInfo<AppUsageIgnoreRuleTable, AppUsageIgnoreRuleTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  AppUsageIgnoreRuleTable(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id =
      GeneratedColumn<String>('id', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<String> pattern =
      GeneratedColumn<String>('pattern', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<String> description =
      GeneratedColumn<String>('description', aliasedName, true, type: DriftSqlType.string, requiredDuringInsert: false);
  late final GeneratedColumn<DateTime> createdDate = GeneratedColumn<DateTime>('created_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  late final GeneratedColumn<DateTime> modifiedDate = GeneratedColumn<DateTime>('modified_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  late final GeneratedColumn<DateTime> deletedDate = GeneratedColumn<DateTime>('deleted_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [id, pattern, description, createdDate, modifiedDate, deletedDate];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_usage_ignore_rule_table';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppUsageIgnoreRuleTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppUsageIgnoreRuleTableData(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      pattern: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}pattern'])!,
      description: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}description']),
      createdDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_date'])!,
      modifiedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}modified_date']),
      deletedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_date']),
    );
  }

  @override
  AppUsageIgnoreRuleTable createAlias(String alias) {
    return AppUsageIgnoreRuleTable(attachedDatabase, alias);
  }
}

class AppUsageIgnoreRuleTableData extends DataClass implements Insertable<AppUsageIgnoreRuleTableData> {
  final String id;
  final String pattern;
  final String? description;
  final DateTime createdDate;
  final DateTime? modifiedDate;
  final DateTime? deletedDate;
  const AppUsageIgnoreRuleTableData(
      {required this.id,
      required this.pattern,
      this.description,
      required this.createdDate,
      this.modifiedDate,
      this.deletedDate});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['pattern'] = Variable<String>(pattern);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['created_date'] = Variable<DateTime>(createdDate);
    if (!nullToAbsent || modifiedDate != null) {
      map['modified_date'] = Variable<DateTime>(modifiedDate);
    }
    if (!nullToAbsent || deletedDate != null) {
      map['deleted_date'] = Variable<DateTime>(deletedDate);
    }
    return map;
  }

  AppUsageIgnoreRuleTableCompanion toCompanion(bool nullToAbsent) {
    return AppUsageIgnoreRuleTableCompanion(
      id: Value(id),
      pattern: Value(pattern),
      description: description == null && nullToAbsent ? const Value.absent() : Value(description),
      createdDate: Value(createdDate),
      modifiedDate: modifiedDate == null && nullToAbsent ? const Value.absent() : Value(modifiedDate),
      deletedDate: deletedDate == null && nullToAbsent ? const Value.absent() : Value(deletedDate),
    );
  }

  factory AppUsageIgnoreRuleTableData.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppUsageIgnoreRuleTableData(
      id: serializer.fromJson<String>(json['id']),
      pattern: serializer.fromJson<String>(json['pattern']),
      description: serializer.fromJson<String?>(json['description']),
      createdDate: serializer.fromJson<DateTime>(json['createdDate']),
      modifiedDate: serializer.fromJson<DateTime?>(json['modifiedDate']),
      deletedDate: serializer.fromJson<DateTime?>(json['deletedDate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'pattern': serializer.toJson<String>(pattern),
      'description': serializer.toJson<String?>(description),
      'createdDate': serializer.toJson<DateTime>(createdDate),
      'modifiedDate': serializer.toJson<DateTime?>(modifiedDate),
      'deletedDate': serializer.toJson<DateTime?>(deletedDate),
    };
  }

  AppUsageIgnoreRuleTableData copyWith(
          {String? id,
          String? pattern,
          Value<String?> description = const Value.absent(),
          DateTime? createdDate,
          Value<DateTime?> modifiedDate = const Value.absent(),
          Value<DateTime?> deletedDate = const Value.absent()}) =>
      AppUsageIgnoreRuleTableData(
        id: id ?? this.id,
        pattern: pattern ?? this.pattern,
        description: description.present ? description.value : this.description,
        createdDate: createdDate ?? this.createdDate,
        modifiedDate: modifiedDate.present ? modifiedDate.value : this.modifiedDate,
        deletedDate: deletedDate.present ? deletedDate.value : this.deletedDate,
      );
  AppUsageIgnoreRuleTableData copyWithCompanion(AppUsageIgnoreRuleTableCompanion data) {
    return AppUsageIgnoreRuleTableData(
      id: data.id.present ? data.id.value : this.id,
      pattern: data.pattern.present ? data.pattern.value : this.pattern,
      description: data.description.present ? data.description.value : this.description,
      createdDate: data.createdDate.present ? data.createdDate.value : this.createdDate,
      modifiedDate: data.modifiedDate.present ? data.modifiedDate.value : this.modifiedDate,
      deletedDate: data.deletedDate.present ? data.deletedDate.value : this.deletedDate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppUsageIgnoreRuleTableData(')
          ..write('id: $id, ')
          ..write('pattern: $pattern, ')
          ..write('description: $description, ')
          ..write('createdDate: $createdDate, ')
          ..write('modifiedDate: $modifiedDate, ')
          ..write('deletedDate: $deletedDate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, pattern, description, createdDate, modifiedDate, deletedDate);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppUsageIgnoreRuleTableData &&
          other.id == this.id &&
          other.pattern == this.pattern &&
          other.description == this.description &&
          other.createdDate == this.createdDate &&
          other.modifiedDate == this.modifiedDate &&
          other.deletedDate == this.deletedDate);
}

class AppUsageIgnoreRuleTableCompanion extends UpdateCompanion<AppUsageIgnoreRuleTableData> {
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
  static Insertable<AppUsageIgnoreRuleTableData> custom({
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

class AppUsageTable extends Table with TableInfo<AppUsageTable, AppUsageTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  AppUsageTable(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id =
      GeneratedColumn<String>('id', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<DateTime> createdDate = GeneratedColumn<DateTime>('created_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  late final GeneratedColumn<DateTime> modifiedDate = GeneratedColumn<DateTime>('modified_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  late final GeneratedColumn<DateTime> deletedDate = GeneratedColumn<DateTime>('deleted_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  late final GeneratedColumn<String> name =
      GeneratedColumn<String>('name', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>('display_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  late final GeneratedColumn<String> color =
      GeneratedColumn<String>('color', aliasedName, true, type: DriftSqlType.string, requiredDuringInsert: false);
  late final GeneratedColumn<String> deviceName =
      GeneratedColumn<String>('device_name', aliasedName, true, type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, createdDate, modifiedDate, deletedDate, name, displayName, color, deviceName];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_usage_table';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppUsageTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppUsageTableData(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      createdDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_date'])!,
      modifiedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}modified_date']),
      deletedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_date']),
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      displayName: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}display_name']),
      color: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}color']),
      deviceName: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}device_name']),
    );
  }

  @override
  AppUsageTable createAlias(String alias) {
    return AppUsageTable(attachedDatabase, alias);
  }
}

class AppUsageTableData extends DataClass implements Insertable<AppUsageTableData> {
  final String id;
  final DateTime createdDate;
  final DateTime? modifiedDate;
  final DateTime? deletedDate;
  final String name;
  final String? displayName;
  final String? color;
  final String? deviceName;
  const AppUsageTableData(
      {required this.id,
      required this.createdDate,
      this.modifiedDate,
      this.deletedDate,
      required this.name,
      this.displayName,
      this.color,
      this.deviceName});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_date'] = Variable<DateTime>(createdDate);
    if (!nullToAbsent || modifiedDate != null) {
      map['modified_date'] = Variable<DateTime>(modifiedDate);
    }
    if (!nullToAbsent || deletedDate != null) {
      map['deleted_date'] = Variable<DateTime>(deletedDate);
    }
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    if (!nullToAbsent || deviceName != null) {
      map['device_name'] = Variable<String>(deviceName);
    }
    return map;
  }

  AppUsageTableCompanion toCompanion(bool nullToAbsent) {
    return AppUsageTableCompanion(
      id: Value(id),
      createdDate: Value(createdDate),
      modifiedDate: modifiedDate == null && nullToAbsent ? const Value.absent() : Value(modifiedDate),
      deletedDate: deletedDate == null && nullToAbsent ? const Value.absent() : Value(deletedDate),
      name: Value(name),
      displayName: displayName == null && nullToAbsent ? const Value.absent() : Value(displayName),
      color: color == null && nullToAbsent ? const Value.absent() : Value(color),
      deviceName: deviceName == null && nullToAbsent ? const Value.absent() : Value(deviceName),
    );
  }

  factory AppUsageTableData.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppUsageTableData(
      id: serializer.fromJson<String>(json['id']),
      createdDate: serializer.fromJson<DateTime>(json['createdDate']),
      modifiedDate: serializer.fromJson<DateTime?>(json['modifiedDate']),
      deletedDate: serializer.fromJson<DateTime?>(json['deletedDate']),
      name: serializer.fromJson<String>(json['name']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      color: serializer.fromJson<String?>(json['color']),
      deviceName: serializer.fromJson<String?>(json['deviceName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdDate': serializer.toJson<DateTime>(createdDate),
      'modifiedDate': serializer.toJson<DateTime?>(modifiedDate),
      'deletedDate': serializer.toJson<DateTime?>(deletedDate),
      'name': serializer.toJson<String>(name),
      'displayName': serializer.toJson<String?>(displayName),
      'color': serializer.toJson<String?>(color),
      'deviceName': serializer.toJson<String?>(deviceName),
    };
  }

  AppUsageTableData copyWith(
          {String? id,
          DateTime? createdDate,
          Value<DateTime?> modifiedDate = const Value.absent(),
          Value<DateTime?> deletedDate = const Value.absent(),
          String? name,
          Value<String?> displayName = const Value.absent(),
          Value<String?> color = const Value.absent(),
          Value<String?> deviceName = const Value.absent()}) =>
      AppUsageTableData(
        id: id ?? this.id,
        createdDate: createdDate ?? this.createdDate,
        modifiedDate: modifiedDate.present ? modifiedDate.value : this.modifiedDate,
        deletedDate: deletedDate.present ? deletedDate.value : this.deletedDate,
        name: name ?? this.name,
        displayName: displayName.present ? displayName.value : this.displayName,
        color: color.present ? color.value : this.color,
        deviceName: deviceName.present ? deviceName.value : this.deviceName,
      );
  AppUsageTableData copyWithCompanion(AppUsageTableCompanion data) {
    return AppUsageTableData(
      id: data.id.present ? data.id.value : this.id,
      createdDate: data.createdDate.present ? data.createdDate.value : this.createdDate,
      modifiedDate: data.modifiedDate.present ? data.modifiedDate.value : this.modifiedDate,
      deletedDate: data.deletedDate.present ? data.deletedDate.value : this.deletedDate,
      name: data.name.present ? data.name.value : this.name,
      displayName: data.displayName.present ? data.displayName.value : this.displayName,
      color: data.color.present ? data.color.value : this.color,
      deviceName: data.deviceName.present ? data.deviceName.value : this.deviceName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppUsageTableData(')
          ..write('id: $id, ')
          ..write('createdDate: $createdDate, ')
          ..write('modifiedDate: $modifiedDate, ')
          ..write('deletedDate: $deletedDate, ')
          ..write('name: $name, ')
          ..write('displayName: $displayName, ')
          ..write('color: $color, ')
          ..write('deviceName: $deviceName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, createdDate, modifiedDate, deletedDate, name, displayName, color, deviceName);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppUsageTableData &&
          other.id == this.id &&
          other.createdDate == this.createdDate &&
          other.modifiedDate == this.modifiedDate &&
          other.deletedDate == this.deletedDate &&
          other.name == this.name &&
          other.displayName == this.displayName &&
          other.color == this.color &&
          other.deviceName == this.deviceName);
}

class AppUsageTableCompanion extends UpdateCompanion<AppUsageTableData> {
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
  static Insertable<AppUsageTableData> custom({
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

class AppUsageTagRuleTable extends Table with TableInfo<AppUsageTagRuleTable, AppUsageTagRuleTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  AppUsageTagRuleTable(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id =
      GeneratedColumn<String>('id', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<String> pattern =
      GeneratedColumn<String>('pattern', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<String> tagId =
      GeneratedColumn<String>('tag_id', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<String> description =
      GeneratedColumn<String>('description', aliasedName, true, type: DriftSqlType.string, requiredDuringInsert: false);
  late final GeneratedColumn<DateTime> createdDate = GeneratedColumn<DateTime>('created_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  late final GeneratedColumn<DateTime> modifiedDate = GeneratedColumn<DateTime>('modified_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  late final GeneratedColumn<DateTime> deletedDate = GeneratedColumn<DateTime>('deleted_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [id, pattern, tagId, description, createdDate, modifiedDate, deletedDate];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_usage_tag_rule_table';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppUsageTagRuleTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppUsageTagRuleTableData(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      pattern: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}pattern'])!,
      tagId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}tag_id'])!,
      description: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}description']),
      createdDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_date'])!,
      modifiedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}modified_date']),
      deletedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_date']),
    );
  }

  @override
  AppUsageTagRuleTable createAlias(String alias) {
    return AppUsageTagRuleTable(attachedDatabase, alias);
  }
}

class AppUsageTagRuleTableData extends DataClass implements Insertable<AppUsageTagRuleTableData> {
  final String id;
  final String pattern;
  final String tagId;
  final String? description;
  final DateTime createdDate;
  final DateTime? modifiedDate;
  final DateTime? deletedDate;
  const AppUsageTagRuleTableData(
      {required this.id,
      required this.pattern,
      required this.tagId,
      this.description,
      required this.createdDate,
      this.modifiedDate,
      this.deletedDate});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['pattern'] = Variable<String>(pattern);
    map['tag_id'] = Variable<String>(tagId);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['created_date'] = Variable<DateTime>(createdDate);
    if (!nullToAbsent || modifiedDate != null) {
      map['modified_date'] = Variable<DateTime>(modifiedDate);
    }
    if (!nullToAbsent || deletedDate != null) {
      map['deleted_date'] = Variable<DateTime>(deletedDate);
    }
    return map;
  }

  AppUsageTagRuleTableCompanion toCompanion(bool nullToAbsent) {
    return AppUsageTagRuleTableCompanion(
      id: Value(id),
      pattern: Value(pattern),
      tagId: Value(tagId),
      description: description == null && nullToAbsent ? const Value.absent() : Value(description),
      createdDate: Value(createdDate),
      modifiedDate: modifiedDate == null && nullToAbsent ? const Value.absent() : Value(modifiedDate),
      deletedDate: deletedDate == null && nullToAbsent ? const Value.absent() : Value(deletedDate),
    );
  }

  factory AppUsageTagRuleTableData.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppUsageTagRuleTableData(
      id: serializer.fromJson<String>(json['id']),
      pattern: serializer.fromJson<String>(json['pattern']),
      tagId: serializer.fromJson<String>(json['tagId']),
      description: serializer.fromJson<String?>(json['description']),
      createdDate: serializer.fromJson<DateTime>(json['createdDate']),
      modifiedDate: serializer.fromJson<DateTime?>(json['modifiedDate']),
      deletedDate: serializer.fromJson<DateTime?>(json['deletedDate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'pattern': serializer.toJson<String>(pattern),
      'tagId': serializer.toJson<String>(tagId),
      'description': serializer.toJson<String?>(description),
      'createdDate': serializer.toJson<DateTime>(createdDate),
      'modifiedDate': serializer.toJson<DateTime?>(modifiedDate),
      'deletedDate': serializer.toJson<DateTime?>(deletedDate),
    };
  }

  AppUsageTagRuleTableData copyWith(
          {String? id,
          String? pattern,
          String? tagId,
          Value<String?> description = const Value.absent(),
          DateTime? createdDate,
          Value<DateTime?> modifiedDate = const Value.absent(),
          Value<DateTime?> deletedDate = const Value.absent()}) =>
      AppUsageTagRuleTableData(
        id: id ?? this.id,
        pattern: pattern ?? this.pattern,
        tagId: tagId ?? this.tagId,
        description: description.present ? description.value : this.description,
        createdDate: createdDate ?? this.createdDate,
        modifiedDate: modifiedDate.present ? modifiedDate.value : this.modifiedDate,
        deletedDate: deletedDate.present ? deletedDate.value : this.deletedDate,
      );
  AppUsageTagRuleTableData copyWithCompanion(AppUsageTagRuleTableCompanion data) {
    return AppUsageTagRuleTableData(
      id: data.id.present ? data.id.value : this.id,
      pattern: data.pattern.present ? data.pattern.value : this.pattern,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
      description: data.description.present ? data.description.value : this.description,
      createdDate: data.createdDate.present ? data.createdDate.value : this.createdDate,
      modifiedDate: data.modifiedDate.present ? data.modifiedDate.value : this.modifiedDate,
      deletedDate: data.deletedDate.present ? data.deletedDate.value : this.deletedDate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppUsageTagRuleTableData(')
          ..write('id: $id, ')
          ..write('pattern: $pattern, ')
          ..write('tagId: $tagId, ')
          ..write('description: $description, ')
          ..write('createdDate: $createdDate, ')
          ..write('modifiedDate: $modifiedDate, ')
          ..write('deletedDate: $deletedDate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, pattern, tagId, description, createdDate, modifiedDate, deletedDate);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppUsageTagRuleTableData &&
          other.id == this.id &&
          other.pattern == this.pattern &&
          other.tagId == this.tagId &&
          other.description == this.description &&
          other.createdDate == this.createdDate &&
          other.modifiedDate == this.modifiedDate &&
          other.deletedDate == this.deletedDate);
}

class AppUsageTagRuleTableCompanion extends UpdateCompanion<AppUsageTagRuleTableData> {
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
  static Insertable<AppUsageTagRuleTableData> custom({
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

class AppUsageTagTable extends Table with TableInfo<AppUsageTagTable, AppUsageTagTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  AppUsageTagTable(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id =
      GeneratedColumn<String>('id', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<DateTime> createdDate = GeneratedColumn<DateTime>('created_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  late final GeneratedColumn<DateTime> modifiedDate = GeneratedColumn<DateTime>('modified_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  late final GeneratedColumn<DateTime> deletedDate = GeneratedColumn<DateTime>('deleted_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  late final GeneratedColumn<String> appUsageId = GeneratedColumn<String>('app_usage_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
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
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  AppUsageTagTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppUsageTagTableData(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      createdDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_date'])!,
      modifiedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}modified_date']),
      deletedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_date']),
      appUsageId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}app_usage_id'])!,
      tagId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}tag_id'])!,
    );
  }

  @override
  AppUsageTagTable createAlias(String alias) {
    return AppUsageTagTable(attachedDatabase, alias);
  }
}

class AppUsageTagTableData extends DataClass implements Insertable<AppUsageTagTableData> {
  final String id;
  final DateTime createdDate;
  final DateTime? modifiedDate;
  final DateTime? deletedDate;
  final String appUsageId;
  final String tagId;
  const AppUsageTagTableData(
      {required this.id,
      required this.createdDate,
      this.modifiedDate,
      this.deletedDate,
      required this.appUsageId,
      required this.tagId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_date'] = Variable<DateTime>(createdDate);
    if (!nullToAbsent || modifiedDate != null) {
      map['modified_date'] = Variable<DateTime>(modifiedDate);
    }
    if (!nullToAbsent || deletedDate != null) {
      map['deleted_date'] = Variable<DateTime>(deletedDate);
    }
    map['app_usage_id'] = Variable<String>(appUsageId);
    map['tag_id'] = Variable<String>(tagId);
    return map;
  }

  AppUsageTagTableCompanion toCompanion(bool nullToAbsent) {
    return AppUsageTagTableCompanion(
      id: Value(id),
      createdDate: Value(createdDate),
      modifiedDate: modifiedDate == null && nullToAbsent ? const Value.absent() : Value(modifiedDate),
      deletedDate: deletedDate == null && nullToAbsent ? const Value.absent() : Value(deletedDate),
      appUsageId: Value(appUsageId),
      tagId: Value(tagId),
    );
  }

  factory AppUsageTagTableData.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppUsageTagTableData(
      id: serializer.fromJson<String>(json['id']),
      createdDate: serializer.fromJson<DateTime>(json['createdDate']),
      modifiedDate: serializer.fromJson<DateTime?>(json['modifiedDate']),
      deletedDate: serializer.fromJson<DateTime?>(json['deletedDate']),
      appUsageId: serializer.fromJson<String>(json['appUsageId']),
      tagId: serializer.fromJson<String>(json['tagId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdDate': serializer.toJson<DateTime>(createdDate),
      'modifiedDate': serializer.toJson<DateTime?>(modifiedDate),
      'deletedDate': serializer.toJson<DateTime?>(deletedDate),
      'appUsageId': serializer.toJson<String>(appUsageId),
      'tagId': serializer.toJson<String>(tagId),
    };
  }

  AppUsageTagTableData copyWith(
          {String? id,
          DateTime? createdDate,
          Value<DateTime?> modifiedDate = const Value.absent(),
          Value<DateTime?> deletedDate = const Value.absent(),
          String? appUsageId,
          String? tagId}) =>
      AppUsageTagTableData(
        id: id ?? this.id,
        createdDate: createdDate ?? this.createdDate,
        modifiedDate: modifiedDate.present ? modifiedDate.value : this.modifiedDate,
        deletedDate: deletedDate.present ? deletedDate.value : this.deletedDate,
        appUsageId: appUsageId ?? this.appUsageId,
        tagId: tagId ?? this.tagId,
      );
  AppUsageTagTableData copyWithCompanion(AppUsageTagTableCompanion data) {
    return AppUsageTagTableData(
      id: data.id.present ? data.id.value : this.id,
      createdDate: data.createdDate.present ? data.createdDate.value : this.createdDate,
      modifiedDate: data.modifiedDate.present ? data.modifiedDate.value : this.modifiedDate,
      deletedDate: data.deletedDate.present ? data.deletedDate.value : this.deletedDate,
      appUsageId: data.appUsageId.present ? data.appUsageId.value : this.appUsageId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppUsageTagTableData(')
          ..write('id: $id, ')
          ..write('createdDate: $createdDate, ')
          ..write('modifiedDate: $modifiedDate, ')
          ..write('deletedDate: $deletedDate, ')
          ..write('appUsageId: $appUsageId, ')
          ..write('tagId: $tagId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, createdDate, modifiedDate, deletedDate, appUsageId, tagId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppUsageTagTableData &&
          other.id == this.id &&
          other.createdDate == this.createdDate &&
          other.modifiedDate == this.modifiedDate &&
          other.deletedDate == this.deletedDate &&
          other.appUsageId == this.appUsageId &&
          other.tagId == this.tagId);
}

class AppUsageTagTableCompanion extends UpdateCompanion<AppUsageTagTableData> {
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
  static Insertable<AppUsageTagTableData> custom({
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

class AppUsageTimeRecordTable extends Table with TableInfo<AppUsageTimeRecordTable, AppUsageTimeRecordTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  AppUsageTimeRecordTable(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id =
      GeneratedColumn<String>('id', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<String> appUsageId = GeneratedColumn<String>('app_usage_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<int> duration =
      GeneratedColumn<int>('duration', aliasedName, false, type: DriftSqlType.int, requiredDuringInsert: true);
  late final GeneratedColumn<DateTime> createdDate = GeneratedColumn<DateTime>('created_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  late final GeneratedColumn<DateTime> modifiedDate = GeneratedColumn<DateTime>('modified_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  late final GeneratedColumn<DateTime> deletedDate = GeneratedColumn<DateTime>('deleted_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [id, appUsageId, duration, createdDate, modifiedDate, deletedDate];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_usage_time_record_table';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppUsageTimeRecordTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppUsageTimeRecordTableData(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      appUsageId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}app_usage_id'])!,
      duration: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}duration'])!,
      createdDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_date'])!,
      modifiedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}modified_date']),
      deletedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_date']),
    );
  }

  @override
  AppUsageTimeRecordTable createAlias(String alias) {
    return AppUsageTimeRecordTable(attachedDatabase, alias);
  }
}

class AppUsageTimeRecordTableData extends DataClass implements Insertable<AppUsageTimeRecordTableData> {
  final String id;
  final String appUsageId;
  final int duration;
  final DateTime createdDate;
  final DateTime? modifiedDate;
  final DateTime? deletedDate;
  const AppUsageTimeRecordTableData(
      {required this.id,
      required this.appUsageId,
      required this.duration,
      required this.createdDate,
      this.modifiedDate,
      this.deletedDate});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['app_usage_id'] = Variable<String>(appUsageId);
    map['duration'] = Variable<int>(duration);
    map['created_date'] = Variable<DateTime>(createdDate);
    if (!nullToAbsent || modifiedDate != null) {
      map['modified_date'] = Variable<DateTime>(modifiedDate);
    }
    if (!nullToAbsent || deletedDate != null) {
      map['deleted_date'] = Variable<DateTime>(deletedDate);
    }
    return map;
  }

  AppUsageTimeRecordTableCompanion toCompanion(bool nullToAbsent) {
    return AppUsageTimeRecordTableCompanion(
      id: Value(id),
      appUsageId: Value(appUsageId),
      duration: Value(duration),
      createdDate: Value(createdDate),
      modifiedDate: modifiedDate == null && nullToAbsent ? const Value.absent() : Value(modifiedDate),
      deletedDate: deletedDate == null && nullToAbsent ? const Value.absent() : Value(deletedDate),
    );
  }

  factory AppUsageTimeRecordTableData.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppUsageTimeRecordTableData(
      id: serializer.fromJson<String>(json['id']),
      appUsageId: serializer.fromJson<String>(json['appUsageId']),
      duration: serializer.fromJson<int>(json['duration']),
      createdDate: serializer.fromJson<DateTime>(json['createdDate']),
      modifiedDate: serializer.fromJson<DateTime?>(json['modifiedDate']),
      deletedDate: serializer.fromJson<DateTime?>(json['deletedDate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'appUsageId': serializer.toJson<String>(appUsageId),
      'duration': serializer.toJson<int>(duration),
      'createdDate': serializer.toJson<DateTime>(createdDate),
      'modifiedDate': serializer.toJson<DateTime?>(modifiedDate),
      'deletedDate': serializer.toJson<DateTime?>(deletedDate),
    };
  }

  AppUsageTimeRecordTableData copyWith(
          {String? id,
          String? appUsageId,
          int? duration,
          DateTime? createdDate,
          Value<DateTime?> modifiedDate = const Value.absent(),
          Value<DateTime?> deletedDate = const Value.absent()}) =>
      AppUsageTimeRecordTableData(
        id: id ?? this.id,
        appUsageId: appUsageId ?? this.appUsageId,
        duration: duration ?? this.duration,
        createdDate: createdDate ?? this.createdDate,
        modifiedDate: modifiedDate.present ? modifiedDate.value : this.modifiedDate,
        deletedDate: deletedDate.present ? deletedDate.value : this.deletedDate,
      );
  AppUsageTimeRecordTableData copyWithCompanion(AppUsageTimeRecordTableCompanion data) {
    return AppUsageTimeRecordTableData(
      id: data.id.present ? data.id.value : this.id,
      appUsageId: data.appUsageId.present ? data.appUsageId.value : this.appUsageId,
      duration: data.duration.present ? data.duration.value : this.duration,
      createdDate: data.createdDate.present ? data.createdDate.value : this.createdDate,
      modifiedDate: data.modifiedDate.present ? data.modifiedDate.value : this.modifiedDate,
      deletedDate: data.deletedDate.present ? data.deletedDate.value : this.deletedDate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppUsageTimeRecordTableData(')
          ..write('id: $id, ')
          ..write('appUsageId: $appUsageId, ')
          ..write('duration: $duration, ')
          ..write('createdDate: $createdDate, ')
          ..write('modifiedDate: $modifiedDate, ')
          ..write('deletedDate: $deletedDate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, appUsageId, duration, createdDate, modifiedDate, deletedDate);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppUsageTimeRecordTableData &&
          other.id == this.id &&
          other.appUsageId == this.appUsageId &&
          other.duration == this.duration &&
          other.createdDate == this.createdDate &&
          other.modifiedDate == this.modifiedDate &&
          other.deletedDate == this.deletedDate);
}

class AppUsageTimeRecordTableCompanion extends UpdateCompanion<AppUsageTimeRecordTableData> {
  final Value<String> id;
  final Value<String> appUsageId;
  final Value<int> duration;
  final Value<DateTime> createdDate;
  final Value<DateTime?> modifiedDate;
  final Value<DateTime?> deletedDate;
  final Value<int> rowid;
  const AppUsageTimeRecordTableCompanion({
    this.id = const Value.absent(),
    this.appUsageId = const Value.absent(),
    this.duration = const Value.absent(),
    this.createdDate = const Value.absent(),
    this.modifiedDate = const Value.absent(),
    this.deletedDate = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppUsageTimeRecordTableCompanion.insert({
    required String id,
    required String appUsageId,
    required int duration,
    required DateTime createdDate,
    this.modifiedDate = const Value.absent(),
    this.deletedDate = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        appUsageId = Value(appUsageId),
        duration = Value(duration),
        createdDate = Value(createdDate);
  static Insertable<AppUsageTimeRecordTableData> custom({
    Expression<String>? id,
    Expression<String>? appUsageId,
    Expression<int>? duration,
    Expression<DateTime>? createdDate,
    Expression<DateTime>? modifiedDate,
    Expression<DateTime>? deletedDate,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (appUsageId != null) 'app_usage_id': appUsageId,
      if (duration != null) 'duration': duration,
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
      Value<DateTime>? createdDate,
      Value<DateTime?>? modifiedDate,
      Value<DateTime?>? deletedDate,
      Value<int>? rowid}) {
    return AppUsageTimeRecordTableCompanion(
      id: id ?? this.id,
      appUsageId: appUsageId ?? this.appUsageId,
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
    if (appUsageId.present) {
      map['app_usage_id'] = Variable<String>(appUsageId.value);
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
    return (StringBuffer('AppUsageTimeRecordTableCompanion(')
          ..write('id: $id, ')
          ..write('appUsageId: $appUsageId, ')
          ..write('duration: $duration, ')
          ..write('createdDate: $createdDate, ')
          ..write('modifiedDate: $modifiedDate, ')
          ..write('deletedDate: $deletedDate, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class HabitRecordTable extends Table with TableInfo<HabitRecordTable, HabitRecordTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  HabitRecordTable(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id =
      GeneratedColumn<String>('id', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<DateTime> createdDate = GeneratedColumn<DateTime>('created_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  late final GeneratedColumn<DateTime> modifiedDate = GeneratedColumn<DateTime>('modified_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  late final GeneratedColumn<DateTime> deletedDate = GeneratedColumn<DateTime>('deleted_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  late final GeneratedColumn<String> habitId =
      GeneratedColumn<String>('habit_id', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
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
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  HabitRecordTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HabitRecordTableData(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      createdDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_date'])!,
      modifiedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}modified_date']),
      deletedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_date']),
      habitId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}habit_id'])!,
      date: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}date'])!,
    );
  }

  @override
  HabitRecordTable createAlias(String alias) {
    return HabitRecordTable(attachedDatabase, alias);
  }
}

class HabitRecordTableData extends DataClass implements Insertable<HabitRecordTableData> {
  final String id;
  final DateTime createdDate;
  final DateTime? modifiedDate;
  final DateTime? deletedDate;
  final String habitId;
  final DateTime date;
  const HabitRecordTableData(
      {required this.id,
      required this.createdDate,
      this.modifiedDate,
      this.deletedDate,
      required this.habitId,
      required this.date});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_date'] = Variable<DateTime>(createdDate);
    if (!nullToAbsent || modifiedDate != null) {
      map['modified_date'] = Variable<DateTime>(modifiedDate);
    }
    if (!nullToAbsent || deletedDate != null) {
      map['deleted_date'] = Variable<DateTime>(deletedDate);
    }
    map['habit_id'] = Variable<String>(habitId);
    map['date'] = Variable<DateTime>(date);
    return map;
  }

  HabitRecordTableCompanion toCompanion(bool nullToAbsent) {
    return HabitRecordTableCompanion(
      id: Value(id),
      createdDate: Value(createdDate),
      modifiedDate: modifiedDate == null && nullToAbsent ? const Value.absent() : Value(modifiedDate),
      deletedDate: deletedDate == null && nullToAbsent ? const Value.absent() : Value(deletedDate),
      habitId: Value(habitId),
      date: Value(date),
    );
  }

  factory HabitRecordTableData.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HabitRecordTableData(
      id: serializer.fromJson<String>(json['id']),
      createdDate: serializer.fromJson<DateTime>(json['createdDate']),
      modifiedDate: serializer.fromJson<DateTime?>(json['modifiedDate']),
      deletedDate: serializer.fromJson<DateTime?>(json['deletedDate']),
      habitId: serializer.fromJson<String>(json['habitId']),
      date: serializer.fromJson<DateTime>(json['date']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdDate': serializer.toJson<DateTime>(createdDate),
      'modifiedDate': serializer.toJson<DateTime?>(modifiedDate),
      'deletedDate': serializer.toJson<DateTime?>(deletedDate),
      'habitId': serializer.toJson<String>(habitId),
      'date': serializer.toJson<DateTime>(date),
    };
  }

  HabitRecordTableData copyWith(
          {String? id,
          DateTime? createdDate,
          Value<DateTime?> modifiedDate = const Value.absent(),
          Value<DateTime?> deletedDate = const Value.absent(),
          String? habitId,
          DateTime? date}) =>
      HabitRecordTableData(
        id: id ?? this.id,
        createdDate: createdDate ?? this.createdDate,
        modifiedDate: modifiedDate.present ? modifiedDate.value : this.modifiedDate,
        deletedDate: deletedDate.present ? deletedDate.value : this.deletedDate,
        habitId: habitId ?? this.habitId,
        date: date ?? this.date,
      );
  HabitRecordTableData copyWithCompanion(HabitRecordTableCompanion data) {
    return HabitRecordTableData(
      id: data.id.present ? data.id.value : this.id,
      createdDate: data.createdDate.present ? data.createdDate.value : this.createdDate,
      modifiedDate: data.modifiedDate.present ? data.modifiedDate.value : this.modifiedDate,
      deletedDate: data.deletedDate.present ? data.deletedDate.value : this.deletedDate,
      habitId: data.habitId.present ? data.habitId.value : this.habitId,
      date: data.date.present ? data.date.value : this.date,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HabitRecordTableData(')
          ..write('id: $id, ')
          ..write('createdDate: $createdDate, ')
          ..write('modifiedDate: $modifiedDate, ')
          ..write('deletedDate: $deletedDate, ')
          ..write('habitId: $habitId, ')
          ..write('date: $date')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, createdDate, modifiedDate, deletedDate, habitId, date);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HabitRecordTableData &&
          other.id == this.id &&
          other.createdDate == this.createdDate &&
          other.modifiedDate == this.modifiedDate &&
          other.deletedDate == this.deletedDate &&
          other.habitId == this.habitId &&
          other.date == this.date);
}

class HabitRecordTableCompanion extends UpdateCompanion<HabitRecordTableData> {
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
  static Insertable<HabitRecordTableData> custom({
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

class HabitTable extends Table with TableInfo<HabitTable, HabitTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  HabitTable(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id =
      GeneratedColumn<String>('id', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<DateTime> createdDate = GeneratedColumn<DateTime>('created_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  late final GeneratedColumn<DateTime> modifiedDate = GeneratedColumn<DateTime>('modified_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  late final GeneratedColumn<DateTime> deletedDate = GeneratedColumn<DateTime>('deleted_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  late final GeneratedColumn<String> name =
      GeneratedColumn<String>('name', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<String> description =
      GeneratedColumn<String>('description', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<int> estimatedTime =
      GeneratedColumn<int>('estimated_time', aliasedName, true, type: DriftSqlType.int, requiredDuringInsert: false);
  late final GeneratedColumn<DateTime> archivedDate = GeneratedColumn<DateTime>('archived_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  late final GeneratedColumn<bool> hasReminder = GeneratedColumn<bool>('has_reminder', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("has_reminder" IN (0, 1))'),
      defaultValue: const CustomExpression('0'));
  late final GeneratedColumn<String> reminderTime = GeneratedColumn<String>('reminder_time', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  late final GeneratedColumn<String> reminderDays = GeneratedColumn<String>('reminder_days', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: false, defaultValue: const CustomExpression('\'\''));
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
        reminderDays
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'habit_table';
  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  HabitTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HabitTableData(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      createdDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_date'])!,
      modifiedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}modified_date']),
      deletedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_date']),
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      description: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}description'])!,
      estimatedTime: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}estimated_time']),
      archivedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}archived_date']),
      hasReminder: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}has_reminder'])!,
      reminderTime: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}reminder_time']),
      reminderDays: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}reminder_days'])!,
    );
  }

  @override
  HabitTable createAlias(String alias) {
    return HabitTable(attachedDatabase, alias);
  }
}

class HabitTableData extends DataClass implements Insertable<HabitTableData> {
  final String id;
  final DateTime createdDate;
  final DateTime? modifiedDate;
  final DateTime? deletedDate;
  final String name;
  final String description;
  final int? estimatedTime;
  final DateTime? archivedDate;
  final bool hasReminder;
  final String? reminderTime;
  final String reminderDays;
  const HabitTableData(
      {required this.id,
      required this.createdDate,
      this.modifiedDate,
      this.deletedDate,
      required this.name,
      required this.description,
      this.estimatedTime,
      this.archivedDate,
      required this.hasReminder,
      this.reminderTime,
      required this.reminderDays});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_date'] = Variable<DateTime>(createdDate);
    if (!nullToAbsent || modifiedDate != null) {
      map['modified_date'] = Variable<DateTime>(modifiedDate);
    }
    if (!nullToAbsent || deletedDate != null) {
      map['deleted_date'] = Variable<DateTime>(deletedDate);
    }
    map['name'] = Variable<String>(name);
    map['description'] = Variable<String>(description);
    if (!nullToAbsent || estimatedTime != null) {
      map['estimated_time'] = Variable<int>(estimatedTime);
    }
    if (!nullToAbsent || archivedDate != null) {
      map['archived_date'] = Variable<DateTime>(archivedDate);
    }
    map['has_reminder'] = Variable<bool>(hasReminder);
    if (!nullToAbsent || reminderTime != null) {
      map['reminder_time'] = Variable<String>(reminderTime);
    }
    map['reminder_days'] = Variable<String>(reminderDays);
    return map;
  }

  HabitTableCompanion toCompanion(bool nullToAbsent) {
    return HabitTableCompanion(
      id: Value(id),
      createdDate: Value(createdDate),
      modifiedDate: modifiedDate == null && nullToAbsent ? const Value.absent() : Value(modifiedDate),
      deletedDate: deletedDate == null && nullToAbsent ? const Value.absent() : Value(deletedDate),
      name: Value(name),
      description: Value(description),
      estimatedTime: estimatedTime == null && nullToAbsent ? const Value.absent() : Value(estimatedTime),
      archivedDate: archivedDate == null && nullToAbsent ? const Value.absent() : Value(archivedDate),
      hasReminder: Value(hasReminder),
      reminderTime: reminderTime == null && nullToAbsent ? const Value.absent() : Value(reminderTime),
      reminderDays: Value(reminderDays),
    );
  }

  factory HabitTableData.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HabitTableData(
      id: serializer.fromJson<String>(json['id']),
      createdDate: serializer.fromJson<DateTime>(json['createdDate']),
      modifiedDate: serializer.fromJson<DateTime?>(json['modifiedDate']),
      deletedDate: serializer.fromJson<DateTime?>(json['deletedDate']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String>(json['description']),
      estimatedTime: serializer.fromJson<int?>(json['estimatedTime']),
      archivedDate: serializer.fromJson<DateTime?>(json['archivedDate']),
      hasReminder: serializer.fromJson<bool>(json['hasReminder']),
      reminderTime: serializer.fromJson<String?>(json['reminderTime']),
      reminderDays: serializer.fromJson<String>(json['reminderDays']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdDate': serializer.toJson<DateTime>(createdDate),
      'modifiedDate': serializer.toJson<DateTime?>(modifiedDate),
      'deletedDate': serializer.toJson<DateTime?>(deletedDate),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String>(description),
      'estimatedTime': serializer.toJson<int?>(estimatedTime),
      'archivedDate': serializer.toJson<DateTime?>(archivedDate),
      'hasReminder': serializer.toJson<bool>(hasReminder),
      'reminderTime': serializer.toJson<String?>(reminderTime),
      'reminderDays': serializer.toJson<String>(reminderDays),
    };
  }

  HabitTableData copyWith(
          {String? id,
          DateTime? createdDate,
          Value<DateTime?> modifiedDate = const Value.absent(),
          Value<DateTime?> deletedDate = const Value.absent(),
          String? name,
          String? description,
          Value<int?> estimatedTime = const Value.absent(),
          Value<DateTime?> archivedDate = const Value.absent(),
          bool? hasReminder,
          Value<String?> reminderTime = const Value.absent(),
          String? reminderDays}) =>
      HabitTableData(
        id: id ?? this.id,
        createdDate: createdDate ?? this.createdDate,
        modifiedDate: modifiedDate.present ? modifiedDate.value : this.modifiedDate,
        deletedDate: deletedDate.present ? deletedDate.value : this.deletedDate,
        name: name ?? this.name,
        description: description ?? this.description,
        estimatedTime: estimatedTime.present ? estimatedTime.value : this.estimatedTime,
        archivedDate: archivedDate.present ? archivedDate.value : this.archivedDate,
        hasReminder: hasReminder ?? this.hasReminder,
        reminderTime: reminderTime.present ? reminderTime.value : this.reminderTime,
        reminderDays: reminderDays ?? this.reminderDays,
      );
  HabitTableData copyWithCompanion(HabitTableCompanion data) {
    return HabitTableData(
      id: data.id.present ? data.id.value : this.id,
      createdDate: data.createdDate.present ? data.createdDate.value : this.createdDate,
      modifiedDate: data.modifiedDate.present ? data.modifiedDate.value : this.modifiedDate,
      deletedDate: data.deletedDate.present ? data.deletedDate.value : this.deletedDate,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present ? data.description.value : this.description,
      estimatedTime: data.estimatedTime.present ? data.estimatedTime.value : this.estimatedTime,
      archivedDate: data.archivedDate.present ? data.archivedDate.value : this.archivedDate,
      hasReminder: data.hasReminder.present ? data.hasReminder.value : this.hasReminder,
      reminderTime: data.reminderTime.present ? data.reminderTime.value : this.reminderTime,
      reminderDays: data.reminderDays.present ? data.reminderDays.value : this.reminderDays,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HabitTableData(')
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
          ..write('reminderDays: $reminderDays')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, createdDate, modifiedDate, deletedDate, name, description, estimatedTime,
      archivedDate, hasReminder, reminderTime, reminderDays);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HabitTableData &&
          other.id == this.id &&
          other.createdDate == this.createdDate &&
          other.modifiedDate == this.modifiedDate &&
          other.deletedDate == this.deletedDate &&
          other.name == this.name &&
          other.description == this.description &&
          other.estimatedTime == this.estimatedTime &&
          other.archivedDate == this.archivedDate &&
          other.hasReminder == this.hasReminder &&
          other.reminderTime == this.reminderTime &&
          other.reminderDays == this.reminderDays);
}

class HabitTableCompanion extends UpdateCompanion<HabitTableData> {
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
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        createdDate = Value(createdDate),
        name = Value(name),
        description = Value(description);
  static Insertable<HabitTableData> custom({
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
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class HabitTagTable extends Table with TableInfo<HabitTagTable, HabitTagTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  HabitTagTable(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id =
      GeneratedColumn<String>('id', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<DateTime> createdDate = GeneratedColumn<DateTime>('created_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  late final GeneratedColumn<DateTime> modifiedDate = GeneratedColumn<DateTime>('modified_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  late final GeneratedColumn<DateTime> deletedDate = GeneratedColumn<DateTime>('deleted_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  late final GeneratedColumn<String> habitId =
      GeneratedColumn<String>('habit_id', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
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
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  HabitTagTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HabitTagTableData(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      createdDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_date'])!,
      modifiedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}modified_date']),
      deletedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_date']),
      habitId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}habit_id'])!,
      tagId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}tag_id'])!,
    );
  }

  @override
  HabitTagTable createAlias(String alias) {
    return HabitTagTable(attachedDatabase, alias);
  }
}

class HabitTagTableData extends DataClass implements Insertable<HabitTagTableData> {
  final String id;
  final DateTime createdDate;
  final DateTime? modifiedDate;
  final DateTime? deletedDate;
  final String habitId;
  final String tagId;
  const HabitTagTableData(
      {required this.id,
      required this.createdDate,
      this.modifiedDate,
      this.deletedDate,
      required this.habitId,
      required this.tagId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_date'] = Variable<DateTime>(createdDate);
    if (!nullToAbsent || modifiedDate != null) {
      map['modified_date'] = Variable<DateTime>(modifiedDate);
    }
    if (!nullToAbsent || deletedDate != null) {
      map['deleted_date'] = Variable<DateTime>(deletedDate);
    }
    map['habit_id'] = Variable<String>(habitId);
    map['tag_id'] = Variable<String>(tagId);
    return map;
  }

  HabitTagTableCompanion toCompanion(bool nullToAbsent) {
    return HabitTagTableCompanion(
      id: Value(id),
      createdDate: Value(createdDate),
      modifiedDate: modifiedDate == null && nullToAbsent ? const Value.absent() : Value(modifiedDate),
      deletedDate: deletedDate == null && nullToAbsent ? const Value.absent() : Value(deletedDate),
      habitId: Value(habitId),
      tagId: Value(tagId),
    );
  }

  factory HabitTagTableData.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HabitTagTableData(
      id: serializer.fromJson<String>(json['id']),
      createdDate: serializer.fromJson<DateTime>(json['createdDate']),
      modifiedDate: serializer.fromJson<DateTime?>(json['modifiedDate']),
      deletedDate: serializer.fromJson<DateTime?>(json['deletedDate']),
      habitId: serializer.fromJson<String>(json['habitId']),
      tagId: serializer.fromJson<String>(json['tagId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdDate': serializer.toJson<DateTime>(createdDate),
      'modifiedDate': serializer.toJson<DateTime?>(modifiedDate),
      'deletedDate': serializer.toJson<DateTime?>(deletedDate),
      'habitId': serializer.toJson<String>(habitId),
      'tagId': serializer.toJson<String>(tagId),
    };
  }

  HabitTagTableData copyWith(
          {String? id,
          DateTime? createdDate,
          Value<DateTime?> modifiedDate = const Value.absent(),
          Value<DateTime?> deletedDate = const Value.absent(),
          String? habitId,
          String? tagId}) =>
      HabitTagTableData(
        id: id ?? this.id,
        createdDate: createdDate ?? this.createdDate,
        modifiedDate: modifiedDate.present ? modifiedDate.value : this.modifiedDate,
        deletedDate: deletedDate.present ? deletedDate.value : this.deletedDate,
        habitId: habitId ?? this.habitId,
        tagId: tagId ?? this.tagId,
      );
  HabitTagTableData copyWithCompanion(HabitTagTableCompanion data) {
    return HabitTagTableData(
      id: data.id.present ? data.id.value : this.id,
      createdDate: data.createdDate.present ? data.createdDate.value : this.createdDate,
      modifiedDate: data.modifiedDate.present ? data.modifiedDate.value : this.modifiedDate,
      deletedDate: data.deletedDate.present ? data.deletedDate.value : this.deletedDate,
      habitId: data.habitId.present ? data.habitId.value : this.habitId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HabitTagTableData(')
          ..write('id: $id, ')
          ..write('createdDate: $createdDate, ')
          ..write('modifiedDate: $modifiedDate, ')
          ..write('deletedDate: $deletedDate, ')
          ..write('habitId: $habitId, ')
          ..write('tagId: $tagId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, createdDate, modifiedDate, deletedDate, habitId, tagId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HabitTagTableData &&
          other.id == this.id &&
          other.createdDate == this.createdDate &&
          other.modifiedDate == this.modifiedDate &&
          other.deletedDate == this.deletedDate &&
          other.habitId == this.habitId &&
          other.tagId == this.tagId);
}

class HabitTagTableCompanion extends UpdateCompanion<HabitTagTableData> {
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
  static Insertable<HabitTagTableData> custom({
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

class NoteTable extends Table with TableInfo<NoteTable, NoteTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  NoteTable(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id =
      GeneratedColumn<String>('id', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<String> title =
      GeneratedColumn<String>('title', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<String> content =
      GeneratedColumn<String>('content', aliasedName, true, type: DriftSqlType.string, requiredDuringInsert: false);
  late final GeneratedColumn<double> order = GeneratedColumn<double>('order', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: false, defaultValue: const CustomExpression('0.0'));
  late final GeneratedColumn<DateTime> createdDate = GeneratedColumn<DateTime>('created_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  late final GeneratedColumn<DateTime> modifiedDate = GeneratedColumn<DateTime>('modified_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  late final GeneratedColumn<DateTime> deletedDate = GeneratedColumn<DateTime>('deleted_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [id, title, content, order, createdDate, modifiedDate, deletedDate];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'note_table';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NoteTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoteTableData(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      content: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}content']),
      order: attachedDatabase.typeMapping.read(DriftSqlType.double, data['${effectivePrefix}order'])!,
      createdDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_date'])!,
      modifiedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}modified_date']),
      deletedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_date']),
    );
  }

  @override
  NoteTable createAlias(String alias) {
    return NoteTable(attachedDatabase, alias);
  }
}

class NoteTableData extends DataClass implements Insertable<NoteTableData> {
  final String id;
  final String title;
  final String? content;
  final double order;
  final DateTime createdDate;
  final DateTime? modifiedDate;
  final DateTime? deletedDate;
  const NoteTableData(
      {required this.id,
      required this.title,
      this.content,
      required this.order,
      required this.createdDate,
      this.modifiedDate,
      this.deletedDate});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || content != null) {
      map['content'] = Variable<String>(content);
    }
    map['order'] = Variable<double>(order);
    map['created_date'] = Variable<DateTime>(createdDate);
    if (!nullToAbsent || modifiedDate != null) {
      map['modified_date'] = Variable<DateTime>(modifiedDate);
    }
    if (!nullToAbsent || deletedDate != null) {
      map['deleted_date'] = Variable<DateTime>(deletedDate);
    }
    return map;
  }

  NoteTableCompanion toCompanion(bool nullToAbsent) {
    return NoteTableCompanion(
      id: Value(id),
      title: Value(title),
      content: content == null && nullToAbsent ? const Value.absent() : Value(content),
      order: Value(order),
      createdDate: Value(createdDate),
      modifiedDate: modifiedDate == null && nullToAbsent ? const Value.absent() : Value(modifiedDate),
      deletedDate: deletedDate == null && nullToAbsent ? const Value.absent() : Value(deletedDate),
    );
  }

  factory NoteTableData.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoteTableData(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      content: serializer.fromJson<String?>(json['content']),
      order: serializer.fromJson<double>(json['order']),
      createdDate: serializer.fromJson<DateTime>(json['createdDate']),
      modifiedDate: serializer.fromJson<DateTime?>(json['modifiedDate']),
      deletedDate: serializer.fromJson<DateTime?>(json['deletedDate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'content': serializer.toJson<String?>(content),
      'order': serializer.toJson<double>(order),
      'createdDate': serializer.toJson<DateTime>(createdDate),
      'modifiedDate': serializer.toJson<DateTime?>(modifiedDate),
      'deletedDate': serializer.toJson<DateTime?>(deletedDate),
    };
  }

  NoteTableData copyWith(
          {String? id,
          String? title,
          Value<String?> content = const Value.absent(),
          double? order,
          DateTime? createdDate,
          Value<DateTime?> modifiedDate = const Value.absent(),
          Value<DateTime?> deletedDate = const Value.absent()}) =>
      NoteTableData(
        id: id ?? this.id,
        title: title ?? this.title,
        content: content.present ? content.value : this.content,
        order: order ?? this.order,
        createdDate: createdDate ?? this.createdDate,
        modifiedDate: modifiedDate.present ? modifiedDate.value : this.modifiedDate,
        deletedDate: deletedDate.present ? deletedDate.value : this.deletedDate,
      );
  NoteTableData copyWithCompanion(NoteTableCompanion data) {
    return NoteTableData(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      content: data.content.present ? data.content.value : this.content,
      order: data.order.present ? data.order.value : this.order,
      createdDate: data.createdDate.present ? data.createdDate.value : this.createdDate,
      modifiedDate: data.modifiedDate.present ? data.modifiedDate.value : this.modifiedDate,
      deletedDate: data.deletedDate.present ? data.deletedDate.value : this.deletedDate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteTableData(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('order: $order, ')
          ..write('createdDate: $createdDate, ')
          ..write('modifiedDate: $modifiedDate, ')
          ..write('deletedDate: $deletedDate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, content, order, createdDate, modifiedDate, deletedDate);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteTableData &&
          other.id == this.id &&
          other.title == this.title &&
          other.content == this.content &&
          other.order == this.order &&
          other.createdDate == this.createdDate &&
          other.modifiedDate == this.modifiedDate &&
          other.deletedDate == this.deletedDate);
}

class NoteTableCompanion extends UpdateCompanion<NoteTableData> {
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
  static Insertable<NoteTableData> custom({
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

class NoteTagTable extends Table with TableInfo<NoteTagTable, NoteTagTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  NoteTagTable(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id =
      GeneratedColumn<String>('id', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<String> noteId =
      GeneratedColumn<String>('note_id', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<String> tagId =
      GeneratedColumn<String>('tag_id', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<DateTime> createdDate = GeneratedColumn<DateTime>('created_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  late final GeneratedColumn<DateTime> modifiedDate = GeneratedColumn<DateTime>('modified_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  late final GeneratedColumn<DateTime> deletedDate = GeneratedColumn<DateTime>('deleted_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [id, noteId, tagId, createdDate, modifiedDate, deletedDate];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'note_tag_table';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NoteTagTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoteTagTableData(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      noteId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}note_id'])!,
      tagId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}tag_id'])!,
      createdDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_date'])!,
      modifiedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}modified_date']),
      deletedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_date']),
    );
  }

  @override
  NoteTagTable createAlias(String alias) {
    return NoteTagTable(attachedDatabase, alias);
  }
}

class NoteTagTableData extends DataClass implements Insertable<NoteTagTableData> {
  final String id;
  final String noteId;
  final String tagId;
  final DateTime createdDate;
  final DateTime? modifiedDate;
  final DateTime? deletedDate;
  const NoteTagTableData(
      {required this.id,
      required this.noteId,
      required this.tagId,
      required this.createdDate,
      this.modifiedDate,
      this.deletedDate});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['note_id'] = Variable<String>(noteId);
    map['tag_id'] = Variable<String>(tagId);
    map['created_date'] = Variable<DateTime>(createdDate);
    if (!nullToAbsent || modifiedDate != null) {
      map['modified_date'] = Variable<DateTime>(modifiedDate);
    }
    if (!nullToAbsent || deletedDate != null) {
      map['deleted_date'] = Variable<DateTime>(deletedDate);
    }
    return map;
  }

  NoteTagTableCompanion toCompanion(bool nullToAbsent) {
    return NoteTagTableCompanion(
      id: Value(id),
      noteId: Value(noteId),
      tagId: Value(tagId),
      createdDate: Value(createdDate),
      modifiedDate: modifiedDate == null && nullToAbsent ? const Value.absent() : Value(modifiedDate),
      deletedDate: deletedDate == null && nullToAbsent ? const Value.absent() : Value(deletedDate),
    );
  }

  factory NoteTagTableData.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoteTagTableData(
      id: serializer.fromJson<String>(json['id']),
      noteId: serializer.fromJson<String>(json['noteId']),
      tagId: serializer.fromJson<String>(json['tagId']),
      createdDate: serializer.fromJson<DateTime>(json['createdDate']),
      modifiedDate: serializer.fromJson<DateTime?>(json['modifiedDate']),
      deletedDate: serializer.fromJson<DateTime?>(json['deletedDate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'noteId': serializer.toJson<String>(noteId),
      'tagId': serializer.toJson<String>(tagId),
      'createdDate': serializer.toJson<DateTime>(createdDate),
      'modifiedDate': serializer.toJson<DateTime?>(modifiedDate),
      'deletedDate': serializer.toJson<DateTime?>(deletedDate),
    };
  }

  NoteTagTableData copyWith(
          {String? id,
          String? noteId,
          String? tagId,
          DateTime? createdDate,
          Value<DateTime?> modifiedDate = const Value.absent(),
          Value<DateTime?> deletedDate = const Value.absent()}) =>
      NoteTagTableData(
        id: id ?? this.id,
        noteId: noteId ?? this.noteId,
        tagId: tagId ?? this.tagId,
        createdDate: createdDate ?? this.createdDate,
        modifiedDate: modifiedDate.present ? modifiedDate.value : this.modifiedDate,
        deletedDate: deletedDate.present ? deletedDate.value : this.deletedDate,
      );
  NoteTagTableData copyWithCompanion(NoteTagTableCompanion data) {
    return NoteTagTableData(
      id: data.id.present ? data.id.value : this.id,
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
      createdDate: data.createdDate.present ? data.createdDate.value : this.createdDate,
      modifiedDate: data.modifiedDate.present ? data.modifiedDate.value : this.modifiedDate,
      deletedDate: data.deletedDate.present ? data.deletedDate.value : this.deletedDate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteTagTableData(')
          ..write('id: $id, ')
          ..write('noteId: $noteId, ')
          ..write('tagId: $tagId, ')
          ..write('createdDate: $createdDate, ')
          ..write('modifiedDate: $modifiedDate, ')
          ..write('deletedDate: $deletedDate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, noteId, tagId, createdDate, modifiedDate, deletedDate);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteTagTableData &&
          other.id == this.id &&
          other.noteId == this.noteId &&
          other.tagId == this.tagId &&
          other.createdDate == this.createdDate &&
          other.modifiedDate == this.modifiedDate &&
          other.deletedDate == this.deletedDate);
}

class NoteTagTableCompanion extends UpdateCompanion<NoteTagTableData> {
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
  static Insertable<NoteTagTableData> custom({
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

class SettingTable extends Table with TableInfo<SettingTable, SettingTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  SettingTable(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id =
      GeneratedColumn<String>('id', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<DateTime> createdDate = GeneratedColumn<DateTime>('created_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  late final GeneratedColumn<DateTime> modifiedDate = GeneratedColumn<DateTime>('modified_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  late final GeneratedColumn<DateTime> deletedDate = GeneratedColumn<DateTime>('deleted_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  late final GeneratedColumn<String> key =
      GeneratedColumn<String>('key', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<String> value =
      GeneratedColumn<String>('value', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<int> valueType =
      GeneratedColumn<int>('value_type', aliasedName, false, type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, createdDate, modifiedDate, deletedDate, key, value, valueType];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'setting_table';
  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  SettingTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingTableData(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      createdDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_date'])!,
      modifiedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}modified_date']),
      deletedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_date']),
      key: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}value'])!,
      valueType: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}value_type'])!,
    );
  }

  @override
  SettingTable createAlias(String alias) {
    return SettingTable(attachedDatabase, alias);
  }
}

class SettingTableData extends DataClass implements Insertable<SettingTableData> {
  final String id;
  final DateTime createdDate;
  final DateTime? modifiedDate;
  final DateTime? deletedDate;
  final String key;
  final String value;
  final int valueType;
  const SettingTableData(
      {required this.id,
      required this.createdDate,
      this.modifiedDate,
      this.deletedDate,
      required this.key,
      required this.value,
      required this.valueType});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_date'] = Variable<DateTime>(createdDate);
    if (!nullToAbsent || modifiedDate != null) {
      map['modified_date'] = Variable<DateTime>(modifiedDate);
    }
    if (!nullToAbsent || deletedDate != null) {
      map['deleted_date'] = Variable<DateTime>(deletedDate);
    }
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['value_type'] = Variable<int>(valueType);
    return map;
  }

  SettingTableCompanion toCompanion(bool nullToAbsent) {
    return SettingTableCompanion(
      id: Value(id),
      createdDate: Value(createdDate),
      modifiedDate: modifiedDate == null && nullToAbsent ? const Value.absent() : Value(modifiedDate),
      deletedDate: deletedDate == null && nullToAbsent ? const Value.absent() : Value(deletedDate),
      key: Value(key),
      value: Value(value),
      valueType: Value(valueType),
    );
  }

  factory SettingTableData.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingTableData(
      id: serializer.fromJson<String>(json['id']),
      createdDate: serializer.fromJson<DateTime>(json['createdDate']),
      modifiedDate: serializer.fromJson<DateTime?>(json['modifiedDate']),
      deletedDate: serializer.fromJson<DateTime?>(json['deletedDate']),
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      valueType: serializer.fromJson<int>(json['valueType']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdDate': serializer.toJson<DateTime>(createdDate),
      'modifiedDate': serializer.toJson<DateTime?>(modifiedDate),
      'deletedDate': serializer.toJson<DateTime?>(deletedDate),
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'valueType': serializer.toJson<int>(valueType),
    };
  }

  SettingTableData copyWith(
          {String? id,
          DateTime? createdDate,
          Value<DateTime?> modifiedDate = const Value.absent(),
          Value<DateTime?> deletedDate = const Value.absent(),
          String? key,
          String? value,
          int? valueType}) =>
      SettingTableData(
        id: id ?? this.id,
        createdDate: createdDate ?? this.createdDate,
        modifiedDate: modifiedDate.present ? modifiedDate.value : this.modifiedDate,
        deletedDate: deletedDate.present ? deletedDate.value : this.deletedDate,
        key: key ?? this.key,
        value: value ?? this.value,
        valueType: valueType ?? this.valueType,
      );
  SettingTableData copyWithCompanion(SettingTableCompanion data) {
    return SettingTableData(
      id: data.id.present ? data.id.value : this.id,
      createdDate: data.createdDate.present ? data.createdDate.value : this.createdDate,
      modifiedDate: data.modifiedDate.present ? data.modifiedDate.value : this.modifiedDate,
      deletedDate: data.deletedDate.present ? data.deletedDate.value : this.deletedDate,
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      valueType: data.valueType.present ? data.valueType.value : this.valueType,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingTableData(')
          ..write('id: $id, ')
          ..write('createdDate: $createdDate, ')
          ..write('modifiedDate: $modifiedDate, ')
          ..write('deletedDate: $deletedDate, ')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('valueType: $valueType')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, createdDate, modifiedDate, deletedDate, key, value, valueType);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingTableData &&
          other.id == this.id &&
          other.createdDate == this.createdDate &&
          other.modifiedDate == this.modifiedDate &&
          other.deletedDate == this.deletedDate &&
          other.key == this.key &&
          other.value == this.value &&
          other.valueType == this.valueType);
}

class SettingTableCompanion extends UpdateCompanion<SettingTableData> {
  final Value<String> id;
  final Value<DateTime> createdDate;
  final Value<DateTime?> modifiedDate;
  final Value<DateTime?> deletedDate;
  final Value<String> key;
  final Value<String> value;
  final Value<int> valueType;
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
    required int valueType,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        createdDate = Value(createdDate),
        key = Value(key),
        value = Value(value),
        valueType = Value(valueType);
  static Insertable<SettingTableData> custom({
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
      Value<int>? valueType,
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
      map['value_type'] = Variable<int>(valueType.value);
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

class SyncDeviceTable extends Table with TableInfo<SyncDeviceTable, SyncDeviceTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  SyncDeviceTable(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id =
      GeneratedColumn<String>('id', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<DateTime> createdDate = GeneratedColumn<DateTime>('created_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  late final GeneratedColumn<DateTime> modifiedDate = GeneratedColumn<DateTime>('modified_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  late final GeneratedColumn<DateTime> deletedDate = GeneratedColumn<DateTime>('deleted_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  late final GeneratedColumn<String> fromIp =
      GeneratedColumn<String>('from_ip', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<String> toIp =
      GeneratedColumn<String>('to_ip', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<String> fromDeviceId = GeneratedColumn<String>('from_device_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<String> toDeviceId = GeneratedColumn<String>('to_device_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<String> name =
      GeneratedColumn<String>('name', aliasedName, true, type: DriftSqlType.string, requiredDuringInsert: false);
  late final GeneratedColumn<DateTime> lastSyncDate = GeneratedColumn<DateTime>('last_sync_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, createdDate, modifiedDate, deletedDate, fromIp, toIp, fromDeviceId, toDeviceId, name, lastSyncDate];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_device_table';
  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  SyncDeviceTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncDeviceTableData(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      createdDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_date'])!,
      modifiedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}modified_date']),
      deletedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_date']),
      fromIp: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}from_ip'])!,
      toIp: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}to_ip'])!,
      fromDeviceId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}from_device_id'])!,
      toDeviceId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}to_device_id'])!,
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name']),
      lastSyncDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}last_sync_date']),
    );
  }

  @override
  SyncDeviceTable createAlias(String alias) {
    return SyncDeviceTable(attachedDatabase, alias);
  }
}

class SyncDeviceTableData extends DataClass implements Insertable<SyncDeviceTableData> {
  final String id;
  final DateTime createdDate;
  final DateTime? modifiedDate;
  final DateTime? deletedDate;
  final String fromIp;
  final String toIp;
  final String fromDeviceId;
  final String toDeviceId;
  final String? name;
  final DateTime? lastSyncDate;
  const SyncDeviceTableData(
      {required this.id,
      required this.createdDate,
      this.modifiedDate,
      this.deletedDate,
      required this.fromIp,
      required this.toIp,
      required this.fromDeviceId,
      required this.toDeviceId,
      this.name,
      this.lastSyncDate});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_date'] = Variable<DateTime>(createdDate);
    if (!nullToAbsent || modifiedDate != null) {
      map['modified_date'] = Variable<DateTime>(modifiedDate);
    }
    if (!nullToAbsent || deletedDate != null) {
      map['deleted_date'] = Variable<DateTime>(deletedDate);
    }
    map['from_ip'] = Variable<String>(fromIp);
    map['to_ip'] = Variable<String>(toIp);
    map['from_device_id'] = Variable<String>(fromDeviceId);
    map['to_device_id'] = Variable<String>(toDeviceId);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || lastSyncDate != null) {
      map['last_sync_date'] = Variable<DateTime>(lastSyncDate);
    }
    return map;
  }

  SyncDeviceTableCompanion toCompanion(bool nullToAbsent) {
    return SyncDeviceTableCompanion(
      id: Value(id),
      createdDate: Value(createdDate),
      modifiedDate: modifiedDate == null && nullToAbsent ? const Value.absent() : Value(modifiedDate),
      deletedDate: deletedDate == null && nullToAbsent ? const Value.absent() : Value(deletedDate),
      fromIp: Value(fromIp),
      toIp: Value(toIp),
      fromDeviceId: Value(fromDeviceId),
      toDeviceId: Value(toDeviceId),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      lastSyncDate: lastSyncDate == null && nullToAbsent ? const Value.absent() : Value(lastSyncDate),
    );
  }

  factory SyncDeviceTableData.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncDeviceTableData(
      id: serializer.fromJson<String>(json['id']),
      createdDate: serializer.fromJson<DateTime>(json['createdDate']),
      modifiedDate: serializer.fromJson<DateTime?>(json['modifiedDate']),
      deletedDate: serializer.fromJson<DateTime?>(json['deletedDate']),
      fromIp: serializer.fromJson<String>(json['fromIp']),
      toIp: serializer.fromJson<String>(json['toIp']),
      fromDeviceId: serializer.fromJson<String>(json['fromDeviceId']),
      toDeviceId: serializer.fromJson<String>(json['toDeviceId']),
      name: serializer.fromJson<String?>(json['name']),
      lastSyncDate: serializer.fromJson<DateTime?>(json['lastSyncDate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdDate': serializer.toJson<DateTime>(createdDate),
      'modifiedDate': serializer.toJson<DateTime?>(modifiedDate),
      'deletedDate': serializer.toJson<DateTime?>(deletedDate),
      'fromIp': serializer.toJson<String>(fromIp),
      'toIp': serializer.toJson<String>(toIp),
      'fromDeviceId': serializer.toJson<String>(fromDeviceId),
      'toDeviceId': serializer.toJson<String>(toDeviceId),
      'name': serializer.toJson<String?>(name),
      'lastSyncDate': serializer.toJson<DateTime?>(lastSyncDate),
    };
  }

  SyncDeviceTableData copyWith(
          {String? id,
          DateTime? createdDate,
          Value<DateTime?> modifiedDate = const Value.absent(),
          Value<DateTime?> deletedDate = const Value.absent(),
          String? fromIp,
          String? toIp,
          String? fromDeviceId,
          String? toDeviceId,
          Value<String?> name = const Value.absent(),
          Value<DateTime?> lastSyncDate = const Value.absent()}) =>
      SyncDeviceTableData(
        id: id ?? this.id,
        createdDate: createdDate ?? this.createdDate,
        modifiedDate: modifiedDate.present ? modifiedDate.value : this.modifiedDate,
        deletedDate: deletedDate.present ? deletedDate.value : this.deletedDate,
        fromIp: fromIp ?? this.fromIp,
        toIp: toIp ?? this.toIp,
        fromDeviceId: fromDeviceId ?? this.fromDeviceId,
        toDeviceId: toDeviceId ?? this.toDeviceId,
        name: name.present ? name.value : this.name,
        lastSyncDate: lastSyncDate.present ? lastSyncDate.value : this.lastSyncDate,
      );
  SyncDeviceTableData copyWithCompanion(SyncDeviceTableCompanion data) {
    return SyncDeviceTableData(
      id: data.id.present ? data.id.value : this.id,
      createdDate: data.createdDate.present ? data.createdDate.value : this.createdDate,
      modifiedDate: data.modifiedDate.present ? data.modifiedDate.value : this.modifiedDate,
      deletedDate: data.deletedDate.present ? data.deletedDate.value : this.deletedDate,
      fromIp: data.fromIp.present ? data.fromIp.value : this.fromIp,
      toIp: data.toIp.present ? data.toIp.value : this.toIp,
      fromDeviceId: data.fromDeviceId.present ? data.fromDeviceId.value : this.fromDeviceId,
      toDeviceId: data.toDeviceId.present ? data.toDeviceId.value : this.toDeviceId,
      name: data.name.present ? data.name.value : this.name,
      lastSyncDate: data.lastSyncDate.present ? data.lastSyncDate.value : this.lastSyncDate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncDeviceTableData(')
          ..write('id: $id, ')
          ..write('createdDate: $createdDate, ')
          ..write('modifiedDate: $modifiedDate, ')
          ..write('deletedDate: $deletedDate, ')
          ..write('fromIp: $fromIp, ')
          ..write('toIp: $toIp, ')
          ..write('fromDeviceId: $fromDeviceId, ')
          ..write('toDeviceId: $toDeviceId, ')
          ..write('name: $name, ')
          ..write('lastSyncDate: $lastSyncDate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, createdDate, modifiedDate, deletedDate, fromIp, toIp, fromDeviceId, toDeviceId, name, lastSyncDate);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncDeviceTableData &&
          other.id == this.id &&
          other.createdDate == this.createdDate &&
          other.modifiedDate == this.modifiedDate &&
          other.deletedDate == this.deletedDate &&
          other.fromIp == this.fromIp &&
          other.toIp == this.toIp &&
          other.fromDeviceId == this.fromDeviceId &&
          other.toDeviceId == this.toDeviceId &&
          other.name == this.name &&
          other.lastSyncDate == this.lastSyncDate);
}

class SyncDeviceTableCompanion extends UpdateCompanion<SyncDeviceTableData> {
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
  static Insertable<SyncDeviceTableData> custom({
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

class TagTable extends Table with TableInfo<TagTable, TagTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  TagTable(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id =
      GeneratedColumn<String>('id', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<DateTime> createdDate = GeneratedColumn<DateTime>('created_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  late final GeneratedColumn<DateTime> modifiedDate = GeneratedColumn<DateTime>('modified_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  late final GeneratedColumn<DateTime> deletedDate = GeneratedColumn<DateTime>('deleted_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  late final GeneratedColumn<String> name =
      GeneratedColumn<String>('name', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<String> color =
      GeneratedColumn<String>('color', aliasedName, true, type: DriftSqlType.string, requiredDuringInsert: false);
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>('is_archived', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("is_archived" IN (0, 1))'),
      defaultValue: const CustomExpression('0'));
  @override
  List<GeneratedColumn> get $columns => [id, createdDate, modifiedDate, deletedDate, name, color, isArchived];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tag_table';
  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  TagTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TagTableData(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      createdDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_date'])!,
      modifiedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}modified_date']),
      deletedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_date']),
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      color: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}color']),
      isArchived: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}is_archived'])!,
    );
  }

  @override
  TagTable createAlias(String alias) {
    return TagTable(attachedDatabase, alias);
  }
}

class TagTableData extends DataClass implements Insertable<TagTableData> {
  final String id;
  final DateTime createdDate;
  final DateTime? modifiedDate;
  final DateTime? deletedDate;
  final String name;
  final String? color;
  final bool isArchived;
  const TagTableData(
      {required this.id,
      required this.createdDate,
      this.modifiedDate,
      this.deletedDate,
      required this.name,
      this.color,
      required this.isArchived});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_date'] = Variable<DateTime>(createdDate);
    if (!nullToAbsent || modifiedDate != null) {
      map['modified_date'] = Variable<DateTime>(modifiedDate);
    }
    if (!nullToAbsent || deletedDate != null) {
      map['deleted_date'] = Variable<DateTime>(deletedDate);
    }
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    map['is_archived'] = Variable<bool>(isArchived);
    return map;
  }

  TagTableCompanion toCompanion(bool nullToAbsent) {
    return TagTableCompanion(
      id: Value(id),
      createdDate: Value(createdDate),
      modifiedDate: modifiedDate == null && nullToAbsent ? const Value.absent() : Value(modifiedDate),
      deletedDate: deletedDate == null && nullToAbsent ? const Value.absent() : Value(deletedDate),
      name: Value(name),
      color: color == null && nullToAbsent ? const Value.absent() : Value(color),
      isArchived: Value(isArchived),
    );
  }

  factory TagTableData.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TagTableData(
      id: serializer.fromJson<String>(json['id']),
      createdDate: serializer.fromJson<DateTime>(json['createdDate']),
      modifiedDate: serializer.fromJson<DateTime?>(json['modifiedDate']),
      deletedDate: serializer.fromJson<DateTime?>(json['deletedDate']),
      name: serializer.fromJson<String>(json['name']),
      color: serializer.fromJson<String?>(json['color']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdDate': serializer.toJson<DateTime>(createdDate),
      'modifiedDate': serializer.toJson<DateTime?>(modifiedDate),
      'deletedDate': serializer.toJson<DateTime?>(deletedDate),
      'name': serializer.toJson<String>(name),
      'color': serializer.toJson<String?>(color),
      'isArchived': serializer.toJson<bool>(isArchived),
    };
  }

  TagTableData copyWith(
          {String? id,
          DateTime? createdDate,
          Value<DateTime?> modifiedDate = const Value.absent(),
          Value<DateTime?> deletedDate = const Value.absent(),
          String? name,
          Value<String?> color = const Value.absent(),
          bool? isArchived}) =>
      TagTableData(
        id: id ?? this.id,
        createdDate: createdDate ?? this.createdDate,
        modifiedDate: modifiedDate.present ? modifiedDate.value : this.modifiedDate,
        deletedDate: deletedDate.present ? deletedDate.value : this.deletedDate,
        name: name ?? this.name,
        color: color.present ? color.value : this.color,
        isArchived: isArchived ?? this.isArchived,
      );
  TagTableData copyWithCompanion(TagTableCompanion data) {
    return TagTableData(
      id: data.id.present ? data.id.value : this.id,
      createdDate: data.createdDate.present ? data.createdDate.value : this.createdDate,
      modifiedDate: data.modifiedDate.present ? data.modifiedDate.value : this.modifiedDate,
      deletedDate: data.deletedDate.present ? data.deletedDate.value : this.deletedDate,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
      isArchived: data.isArchived.present ? data.isArchived.value : this.isArchived,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TagTableData(')
          ..write('id: $id, ')
          ..write('createdDate: $createdDate, ')
          ..write('modifiedDate: $modifiedDate, ')
          ..write('deletedDate: $deletedDate, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('isArchived: $isArchived')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, createdDate, modifiedDate, deletedDate, name, color, isArchived);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TagTableData &&
          other.id == this.id &&
          other.createdDate == this.createdDate &&
          other.modifiedDate == this.modifiedDate &&
          other.deletedDate == this.deletedDate &&
          other.name == this.name &&
          other.color == this.color &&
          other.isArchived == this.isArchived);
}

class TagTableCompanion extends UpdateCompanion<TagTableData> {
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
  static Insertable<TagTableData> custom({
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

class TagTagTable extends Table with TableInfo<TagTagTable, TagTagTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  TagTagTable(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id =
      GeneratedColumn<String>('id', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<DateTime> createdDate = GeneratedColumn<DateTime>('created_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  late final GeneratedColumn<DateTime> modifiedDate = GeneratedColumn<DateTime>('modified_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  late final GeneratedColumn<DateTime> deletedDate = GeneratedColumn<DateTime>('deleted_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  late final GeneratedColumn<String> primaryTagId = GeneratedColumn<String>('primary_tag_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
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
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  TagTagTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TagTagTableData(
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
  TagTagTable createAlias(String alias) {
    return TagTagTable(attachedDatabase, alias);
  }
}

class TagTagTableData extends DataClass implements Insertable<TagTagTableData> {
  final String id;
  final DateTime createdDate;
  final DateTime? modifiedDate;
  final DateTime? deletedDate;
  final String primaryTagId;
  final String secondaryTagId;
  const TagTagTableData(
      {required this.id,
      required this.createdDate,
      this.modifiedDate,
      this.deletedDate,
      required this.primaryTagId,
      required this.secondaryTagId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_date'] = Variable<DateTime>(createdDate);
    if (!nullToAbsent || modifiedDate != null) {
      map['modified_date'] = Variable<DateTime>(modifiedDate);
    }
    if (!nullToAbsent || deletedDate != null) {
      map['deleted_date'] = Variable<DateTime>(deletedDate);
    }
    map['primary_tag_id'] = Variable<String>(primaryTagId);
    map['secondary_tag_id'] = Variable<String>(secondaryTagId);
    return map;
  }

  TagTagTableCompanion toCompanion(bool nullToAbsent) {
    return TagTagTableCompanion(
      id: Value(id),
      createdDate: Value(createdDate),
      modifiedDate: modifiedDate == null && nullToAbsent ? const Value.absent() : Value(modifiedDate),
      deletedDate: deletedDate == null && nullToAbsent ? const Value.absent() : Value(deletedDate),
      primaryTagId: Value(primaryTagId),
      secondaryTagId: Value(secondaryTagId),
    );
  }

  factory TagTagTableData.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TagTagTableData(
      id: serializer.fromJson<String>(json['id']),
      createdDate: serializer.fromJson<DateTime>(json['createdDate']),
      modifiedDate: serializer.fromJson<DateTime?>(json['modifiedDate']),
      deletedDate: serializer.fromJson<DateTime?>(json['deletedDate']),
      primaryTagId: serializer.fromJson<String>(json['primaryTagId']),
      secondaryTagId: serializer.fromJson<String>(json['secondaryTagId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdDate': serializer.toJson<DateTime>(createdDate),
      'modifiedDate': serializer.toJson<DateTime?>(modifiedDate),
      'deletedDate': serializer.toJson<DateTime?>(deletedDate),
      'primaryTagId': serializer.toJson<String>(primaryTagId),
      'secondaryTagId': serializer.toJson<String>(secondaryTagId),
    };
  }

  TagTagTableData copyWith(
          {String? id,
          DateTime? createdDate,
          Value<DateTime?> modifiedDate = const Value.absent(),
          Value<DateTime?> deletedDate = const Value.absent(),
          String? primaryTagId,
          String? secondaryTagId}) =>
      TagTagTableData(
        id: id ?? this.id,
        createdDate: createdDate ?? this.createdDate,
        modifiedDate: modifiedDate.present ? modifiedDate.value : this.modifiedDate,
        deletedDate: deletedDate.present ? deletedDate.value : this.deletedDate,
        primaryTagId: primaryTagId ?? this.primaryTagId,
        secondaryTagId: secondaryTagId ?? this.secondaryTagId,
      );
  TagTagTableData copyWithCompanion(TagTagTableCompanion data) {
    return TagTagTableData(
      id: data.id.present ? data.id.value : this.id,
      createdDate: data.createdDate.present ? data.createdDate.value : this.createdDate,
      modifiedDate: data.modifiedDate.present ? data.modifiedDate.value : this.modifiedDate,
      deletedDate: data.deletedDate.present ? data.deletedDate.value : this.deletedDate,
      primaryTagId: data.primaryTagId.present ? data.primaryTagId.value : this.primaryTagId,
      secondaryTagId: data.secondaryTagId.present ? data.secondaryTagId.value : this.secondaryTagId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TagTagTableData(')
          ..write('id: $id, ')
          ..write('createdDate: $createdDate, ')
          ..write('modifiedDate: $modifiedDate, ')
          ..write('deletedDate: $deletedDate, ')
          ..write('primaryTagId: $primaryTagId, ')
          ..write('secondaryTagId: $secondaryTagId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, createdDate, modifiedDate, deletedDate, primaryTagId, secondaryTagId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TagTagTableData &&
          other.id == this.id &&
          other.createdDate == this.createdDate &&
          other.modifiedDate == this.modifiedDate &&
          other.deletedDate == this.deletedDate &&
          other.primaryTagId == this.primaryTagId &&
          other.secondaryTagId == this.secondaryTagId);
}

class TagTagTableCompanion extends UpdateCompanion<TagTagTableData> {
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
  static Insertable<TagTagTableData> custom({
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

class TaskTable extends Table with TableInfo<TaskTable, TaskTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  TaskTable(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id =
      GeneratedColumn<String>('id', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<String> parentTaskId = GeneratedColumn<String>('parent_task_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  late final GeneratedColumn<String> title =
      GeneratedColumn<String>('title', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<String> description =
      GeneratedColumn<String>('description', aliasedName, true, type: DriftSqlType.string, requiredDuringInsert: false);
  late final GeneratedColumn<int> priority =
      GeneratedColumn<int>('priority', aliasedName, true, type: DriftSqlType.int, requiredDuringInsert: false);
  late final GeneratedColumn<DateTime> plannedDate = GeneratedColumn<DateTime>('planned_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  late final GeneratedColumn<DateTime> deadlineDate = GeneratedColumn<DateTime>('deadline_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  late final GeneratedColumn<int> estimatedTime =
      GeneratedColumn<int>('estimated_time', aliasedName, true, type: DriftSqlType.int, requiredDuringInsert: false);
  late final GeneratedColumn<bool> isCompleted = GeneratedColumn<bool>('is_completed', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("is_completed" IN (0, 1))'),
      defaultValue: const CustomExpression('0'));
  late final GeneratedColumn<DateTime> createdDate = GeneratedColumn<DateTime>('created_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  late final GeneratedColumn<DateTime> modifiedDate = GeneratedColumn<DateTime>('modified_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  late final GeneratedColumn<DateTime> deletedDate = GeneratedColumn<DateTime>('deleted_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  late final GeneratedColumn<double> order = GeneratedColumn<double>('order', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: false, defaultValue: const CustomExpression('0.0'));
  late final GeneratedColumn<int> plannedDateReminderTime = GeneratedColumn<int>(
      'planned_date_reminder_time', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false, defaultValue: const CustomExpression('0'));
  late final GeneratedColumn<int> deadlineDateReminderTime = GeneratedColumn<int>(
      'deadline_date_reminder_time', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false, defaultValue: const CustomExpression('0'));
  late final GeneratedColumn<int> recurrenceType = GeneratedColumn<int>('recurrence_type', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false, defaultValue: const CustomExpression('0'));
  late final GeneratedColumn<int> recurrenceInterval = GeneratedColumn<int>('recurrence_interval', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  late final GeneratedColumn<String> recurrenceDaysString = GeneratedColumn<String>(
      'recurrence_days_string', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  late final GeneratedColumn<DateTime> recurrenceStartDate = GeneratedColumn<DateTime>(
      'recurrence_start_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  late final GeneratedColumn<DateTime> recurrenceEndDate = GeneratedColumn<DateTime>(
      'recurrence_end_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  late final GeneratedColumn<int> recurrenceCount =
      GeneratedColumn<int>('recurrence_count', aliasedName, true, type: DriftSqlType.int, requiredDuringInsert: false);
  late final GeneratedColumn<String> recurrenceParentId = GeneratedColumn<String>(
      'recurrence_parent_id', aliasedName, true,
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
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  TaskTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskTableData(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      parentTaskId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}parent_task_id']),
      title: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      description: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}description']),
      priority: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}priority']),
      plannedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}planned_date']),
      deadlineDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}deadline_date']),
      estimatedTime: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}estimated_time']),
      isCompleted: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}is_completed'])!,
      createdDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_date'])!,
      modifiedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}modified_date']),
      deletedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_date']),
      order: attachedDatabase.typeMapping.read(DriftSqlType.double, data['${effectivePrefix}order'])!,
      plannedDateReminderTime:
          attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}planned_date_reminder_time'])!,
      deadlineDateReminderTime:
          attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}deadline_date_reminder_time'])!,
      recurrenceType: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}recurrence_type'])!,
      recurrenceInterval:
          attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}recurrence_interval']),
      recurrenceDaysString:
          attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}recurrence_days_string']),
      recurrenceStartDate:
          attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}recurrence_start_date']),
      recurrenceEndDate:
          attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}recurrence_end_date']),
      recurrenceCount: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}recurrence_count']),
      recurrenceParentId:
          attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}recurrence_parent_id']),
    );
  }

  @override
  TaskTable createAlias(String alias) {
    return TaskTable(attachedDatabase, alias);
  }
}

class TaskTableData extends DataClass implements Insertable<TaskTableData> {
  final String id;
  final String? parentTaskId;
  final String title;
  final String? description;
  final int? priority;
  final DateTime? plannedDate;
  final DateTime? deadlineDate;
  final int? estimatedTime;
  final bool isCompleted;
  final DateTime createdDate;
  final DateTime? modifiedDate;
  final DateTime? deletedDate;
  final double order;
  final int plannedDateReminderTime;
  final int deadlineDateReminderTime;
  final int recurrenceType;
  final int? recurrenceInterval;
  final String? recurrenceDaysString;
  final DateTime? recurrenceStartDate;
  final DateTime? recurrenceEndDate;
  final int? recurrenceCount;
  final String? recurrenceParentId;
  const TaskTableData(
      {required this.id,
      this.parentTaskId,
      required this.title,
      this.description,
      this.priority,
      this.plannedDate,
      this.deadlineDate,
      this.estimatedTime,
      required this.isCompleted,
      required this.createdDate,
      this.modifiedDate,
      this.deletedDate,
      required this.order,
      required this.plannedDateReminderTime,
      required this.deadlineDateReminderTime,
      required this.recurrenceType,
      this.recurrenceInterval,
      this.recurrenceDaysString,
      this.recurrenceStartDate,
      this.recurrenceEndDate,
      this.recurrenceCount,
      this.recurrenceParentId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || parentTaskId != null) {
      map['parent_task_id'] = Variable<String>(parentTaskId);
    }
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || priority != null) {
      map['priority'] = Variable<int>(priority);
    }
    if (!nullToAbsent || plannedDate != null) {
      map['planned_date'] = Variable<DateTime>(plannedDate);
    }
    if (!nullToAbsent || deadlineDate != null) {
      map['deadline_date'] = Variable<DateTime>(deadlineDate);
    }
    if (!nullToAbsent || estimatedTime != null) {
      map['estimated_time'] = Variable<int>(estimatedTime);
    }
    map['is_completed'] = Variable<bool>(isCompleted);
    map['created_date'] = Variable<DateTime>(createdDate);
    if (!nullToAbsent || modifiedDate != null) {
      map['modified_date'] = Variable<DateTime>(modifiedDate);
    }
    if (!nullToAbsent || deletedDate != null) {
      map['deleted_date'] = Variable<DateTime>(deletedDate);
    }
    map['order'] = Variable<double>(order);
    map['planned_date_reminder_time'] = Variable<int>(plannedDateReminderTime);
    map['deadline_date_reminder_time'] = Variable<int>(deadlineDateReminderTime);
    map['recurrence_type'] = Variable<int>(recurrenceType);
    if (!nullToAbsent || recurrenceInterval != null) {
      map['recurrence_interval'] = Variable<int>(recurrenceInterval);
    }
    if (!nullToAbsent || recurrenceDaysString != null) {
      map['recurrence_days_string'] = Variable<String>(recurrenceDaysString);
    }
    if (!nullToAbsent || recurrenceStartDate != null) {
      map['recurrence_start_date'] = Variable<DateTime>(recurrenceStartDate);
    }
    if (!nullToAbsent || recurrenceEndDate != null) {
      map['recurrence_end_date'] = Variable<DateTime>(recurrenceEndDate);
    }
    if (!nullToAbsent || recurrenceCount != null) {
      map['recurrence_count'] = Variable<int>(recurrenceCount);
    }
    if (!nullToAbsent || recurrenceParentId != null) {
      map['recurrence_parent_id'] = Variable<String>(recurrenceParentId);
    }
    return map;
  }

  TaskTableCompanion toCompanion(bool nullToAbsent) {
    return TaskTableCompanion(
      id: Value(id),
      parentTaskId: parentTaskId == null && nullToAbsent ? const Value.absent() : Value(parentTaskId),
      title: Value(title),
      description: description == null && nullToAbsent ? const Value.absent() : Value(description),
      priority: priority == null && nullToAbsent ? const Value.absent() : Value(priority),
      plannedDate: plannedDate == null && nullToAbsent ? const Value.absent() : Value(plannedDate),
      deadlineDate: deadlineDate == null && nullToAbsent ? const Value.absent() : Value(deadlineDate),
      estimatedTime: estimatedTime == null && nullToAbsent ? const Value.absent() : Value(estimatedTime),
      isCompleted: Value(isCompleted),
      createdDate: Value(createdDate),
      modifiedDate: modifiedDate == null && nullToAbsent ? const Value.absent() : Value(modifiedDate),
      deletedDate: deletedDate == null && nullToAbsent ? const Value.absent() : Value(deletedDate),
      order: Value(order),
      plannedDateReminderTime: Value(plannedDateReminderTime),
      deadlineDateReminderTime: Value(deadlineDateReminderTime),
      recurrenceType: Value(recurrenceType),
      recurrenceInterval: recurrenceInterval == null && nullToAbsent ? const Value.absent() : Value(recurrenceInterval),
      recurrenceDaysString:
          recurrenceDaysString == null && nullToAbsent ? const Value.absent() : Value(recurrenceDaysString),
      recurrenceStartDate:
          recurrenceStartDate == null && nullToAbsent ? const Value.absent() : Value(recurrenceStartDate),
      recurrenceEndDate: recurrenceEndDate == null && nullToAbsent ? const Value.absent() : Value(recurrenceEndDate),
      recurrenceCount: recurrenceCount == null && nullToAbsent ? const Value.absent() : Value(recurrenceCount),
      recurrenceParentId: recurrenceParentId == null && nullToAbsent ? const Value.absent() : Value(recurrenceParentId),
    );
  }

  factory TaskTableData.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskTableData(
      id: serializer.fromJson<String>(json['id']),
      parentTaskId: serializer.fromJson<String?>(json['parentTaskId']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      priority: serializer.fromJson<int?>(json['priority']),
      plannedDate: serializer.fromJson<DateTime?>(json['plannedDate']),
      deadlineDate: serializer.fromJson<DateTime?>(json['deadlineDate']),
      estimatedTime: serializer.fromJson<int?>(json['estimatedTime']),
      isCompleted: serializer.fromJson<bool>(json['isCompleted']),
      createdDate: serializer.fromJson<DateTime>(json['createdDate']),
      modifiedDate: serializer.fromJson<DateTime?>(json['modifiedDate']),
      deletedDate: serializer.fromJson<DateTime?>(json['deletedDate']),
      order: serializer.fromJson<double>(json['order']),
      plannedDateReminderTime: serializer.fromJson<int>(json['plannedDateReminderTime']),
      deadlineDateReminderTime: serializer.fromJson<int>(json['deadlineDateReminderTime']),
      recurrenceType: serializer.fromJson<int>(json['recurrenceType']),
      recurrenceInterval: serializer.fromJson<int?>(json['recurrenceInterval']),
      recurrenceDaysString: serializer.fromJson<String?>(json['recurrenceDaysString']),
      recurrenceStartDate: serializer.fromJson<DateTime?>(json['recurrenceStartDate']),
      recurrenceEndDate: serializer.fromJson<DateTime?>(json['recurrenceEndDate']),
      recurrenceCount: serializer.fromJson<int?>(json['recurrenceCount']),
      recurrenceParentId: serializer.fromJson<String?>(json['recurrenceParentId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'parentTaskId': serializer.toJson<String?>(parentTaskId),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'priority': serializer.toJson<int?>(priority),
      'plannedDate': serializer.toJson<DateTime?>(plannedDate),
      'deadlineDate': serializer.toJson<DateTime?>(deadlineDate),
      'estimatedTime': serializer.toJson<int?>(estimatedTime),
      'isCompleted': serializer.toJson<bool>(isCompleted),
      'createdDate': serializer.toJson<DateTime>(createdDate),
      'modifiedDate': serializer.toJson<DateTime?>(modifiedDate),
      'deletedDate': serializer.toJson<DateTime?>(deletedDate),
      'order': serializer.toJson<double>(order),
      'plannedDateReminderTime': serializer.toJson<int>(plannedDateReminderTime),
      'deadlineDateReminderTime': serializer.toJson<int>(deadlineDateReminderTime),
      'recurrenceType': serializer.toJson<int>(recurrenceType),
      'recurrenceInterval': serializer.toJson<int?>(recurrenceInterval),
      'recurrenceDaysString': serializer.toJson<String?>(recurrenceDaysString),
      'recurrenceStartDate': serializer.toJson<DateTime?>(recurrenceStartDate),
      'recurrenceEndDate': serializer.toJson<DateTime?>(recurrenceEndDate),
      'recurrenceCount': serializer.toJson<int?>(recurrenceCount),
      'recurrenceParentId': serializer.toJson<String?>(recurrenceParentId),
    };
  }

  TaskTableData copyWith(
          {String? id,
          Value<String?> parentTaskId = const Value.absent(),
          String? title,
          Value<String?> description = const Value.absent(),
          Value<int?> priority = const Value.absent(),
          Value<DateTime?> plannedDate = const Value.absent(),
          Value<DateTime?> deadlineDate = const Value.absent(),
          Value<int?> estimatedTime = const Value.absent(),
          bool? isCompleted,
          DateTime? createdDate,
          Value<DateTime?> modifiedDate = const Value.absent(),
          Value<DateTime?> deletedDate = const Value.absent(),
          double? order,
          int? plannedDateReminderTime,
          int? deadlineDateReminderTime,
          int? recurrenceType,
          Value<int?> recurrenceInterval = const Value.absent(),
          Value<String?> recurrenceDaysString = const Value.absent(),
          Value<DateTime?> recurrenceStartDate = const Value.absent(),
          Value<DateTime?> recurrenceEndDate = const Value.absent(),
          Value<int?> recurrenceCount = const Value.absent(),
          Value<String?> recurrenceParentId = const Value.absent()}) =>
      TaskTableData(
        id: id ?? this.id,
        parentTaskId: parentTaskId.present ? parentTaskId.value : this.parentTaskId,
        title: title ?? this.title,
        description: description.present ? description.value : this.description,
        priority: priority.present ? priority.value : this.priority,
        plannedDate: plannedDate.present ? plannedDate.value : this.plannedDate,
        deadlineDate: deadlineDate.present ? deadlineDate.value : this.deadlineDate,
        estimatedTime: estimatedTime.present ? estimatedTime.value : this.estimatedTime,
        isCompleted: isCompleted ?? this.isCompleted,
        createdDate: createdDate ?? this.createdDate,
        modifiedDate: modifiedDate.present ? modifiedDate.value : this.modifiedDate,
        deletedDate: deletedDate.present ? deletedDate.value : this.deletedDate,
        order: order ?? this.order,
        plannedDateReminderTime: plannedDateReminderTime ?? this.plannedDateReminderTime,
        deadlineDateReminderTime: deadlineDateReminderTime ?? this.deadlineDateReminderTime,
        recurrenceType: recurrenceType ?? this.recurrenceType,
        recurrenceInterval: recurrenceInterval.present ? recurrenceInterval.value : this.recurrenceInterval,
        recurrenceDaysString: recurrenceDaysString.present ? recurrenceDaysString.value : this.recurrenceDaysString,
        recurrenceStartDate: recurrenceStartDate.present ? recurrenceStartDate.value : this.recurrenceStartDate,
        recurrenceEndDate: recurrenceEndDate.present ? recurrenceEndDate.value : this.recurrenceEndDate,
        recurrenceCount: recurrenceCount.present ? recurrenceCount.value : this.recurrenceCount,
        recurrenceParentId: recurrenceParentId.present ? recurrenceParentId.value : this.recurrenceParentId,
      );
  TaskTableData copyWithCompanion(TaskTableCompanion data) {
    return TaskTableData(
      id: data.id.present ? data.id.value : this.id,
      parentTaskId: data.parentTaskId.present ? data.parentTaskId.value : this.parentTaskId,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present ? data.description.value : this.description,
      priority: data.priority.present ? data.priority.value : this.priority,
      plannedDate: data.plannedDate.present ? data.plannedDate.value : this.plannedDate,
      deadlineDate: data.deadlineDate.present ? data.deadlineDate.value : this.deadlineDate,
      estimatedTime: data.estimatedTime.present ? data.estimatedTime.value : this.estimatedTime,
      isCompleted: data.isCompleted.present ? data.isCompleted.value : this.isCompleted,
      createdDate: data.createdDate.present ? data.createdDate.value : this.createdDate,
      modifiedDate: data.modifiedDate.present ? data.modifiedDate.value : this.modifiedDate,
      deletedDate: data.deletedDate.present ? data.deletedDate.value : this.deletedDate,
      order: data.order.present ? data.order.value : this.order,
      plannedDateReminderTime:
          data.plannedDateReminderTime.present ? data.plannedDateReminderTime.value : this.plannedDateReminderTime,
      deadlineDateReminderTime:
          data.deadlineDateReminderTime.present ? data.deadlineDateReminderTime.value : this.deadlineDateReminderTime,
      recurrenceType: data.recurrenceType.present ? data.recurrenceType.value : this.recurrenceType,
      recurrenceInterval: data.recurrenceInterval.present ? data.recurrenceInterval.value : this.recurrenceInterval,
      recurrenceDaysString:
          data.recurrenceDaysString.present ? data.recurrenceDaysString.value : this.recurrenceDaysString,
      recurrenceStartDate: data.recurrenceStartDate.present ? data.recurrenceStartDate.value : this.recurrenceStartDate,
      recurrenceEndDate: data.recurrenceEndDate.present ? data.recurrenceEndDate.value : this.recurrenceEndDate,
      recurrenceCount: data.recurrenceCount.present ? data.recurrenceCount.value : this.recurrenceCount,
      recurrenceParentId: data.recurrenceParentId.present ? data.recurrenceParentId.value : this.recurrenceParentId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskTableData(')
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
          ..write('recurrenceParentId: $recurrenceParentId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
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
      ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskTableData &&
          other.id == this.id &&
          other.parentTaskId == this.parentTaskId &&
          other.title == this.title &&
          other.description == this.description &&
          other.priority == this.priority &&
          other.plannedDate == this.plannedDate &&
          other.deadlineDate == this.deadlineDate &&
          other.estimatedTime == this.estimatedTime &&
          other.isCompleted == this.isCompleted &&
          other.createdDate == this.createdDate &&
          other.modifiedDate == this.modifiedDate &&
          other.deletedDate == this.deletedDate &&
          other.order == this.order &&
          other.plannedDateReminderTime == this.plannedDateReminderTime &&
          other.deadlineDateReminderTime == this.deadlineDateReminderTime &&
          other.recurrenceType == this.recurrenceType &&
          other.recurrenceInterval == this.recurrenceInterval &&
          other.recurrenceDaysString == this.recurrenceDaysString &&
          other.recurrenceStartDate == this.recurrenceStartDate &&
          other.recurrenceEndDate == this.recurrenceEndDate &&
          other.recurrenceCount == this.recurrenceCount &&
          other.recurrenceParentId == this.recurrenceParentId);
}

class TaskTableCompanion extends UpdateCompanion<TaskTableData> {
  final Value<String> id;
  final Value<String?> parentTaskId;
  final Value<String> title;
  final Value<String?> description;
  final Value<int?> priority;
  final Value<DateTime?> plannedDate;
  final Value<DateTime?> deadlineDate;
  final Value<int?> estimatedTime;
  final Value<bool> isCompleted;
  final Value<DateTime> createdDate;
  final Value<DateTime?> modifiedDate;
  final Value<DateTime?> deletedDate;
  final Value<double> order;
  final Value<int> plannedDateReminderTime;
  final Value<int> deadlineDateReminderTime;
  final Value<int> recurrenceType;
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
  static Insertable<TaskTableData> custom({
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
      if (plannedDateReminderTime != null) 'planned_date_reminder_time': plannedDateReminderTime,
      if (deadlineDateReminderTime != null) 'deadline_date_reminder_time': deadlineDateReminderTime,
      if (recurrenceType != null) 'recurrence_type': recurrenceType,
      if (recurrenceInterval != null) 'recurrence_interval': recurrenceInterval,
      if (recurrenceDaysString != null) 'recurrence_days_string': recurrenceDaysString,
      if (recurrenceStartDate != null) 'recurrence_start_date': recurrenceStartDate,
      if (recurrenceEndDate != null) 'recurrence_end_date': recurrenceEndDate,
      if (recurrenceCount != null) 'recurrence_count': recurrenceCount,
      if (recurrenceParentId != null) 'recurrence_parent_id': recurrenceParentId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TaskTableCompanion copyWith(
      {Value<String>? id,
      Value<String?>? parentTaskId,
      Value<String>? title,
      Value<String?>? description,
      Value<int?>? priority,
      Value<DateTime?>? plannedDate,
      Value<DateTime?>? deadlineDate,
      Value<int?>? estimatedTime,
      Value<bool>? isCompleted,
      Value<DateTime>? createdDate,
      Value<DateTime?>? modifiedDate,
      Value<DateTime?>? deletedDate,
      Value<double>? order,
      Value<int>? plannedDateReminderTime,
      Value<int>? deadlineDateReminderTime,
      Value<int>? recurrenceType,
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
      plannedDateReminderTime: plannedDateReminderTime ?? this.plannedDateReminderTime,
      deadlineDateReminderTime: deadlineDateReminderTime ?? this.deadlineDateReminderTime,
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
      map['priority'] = Variable<int>(priority.value);
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
      map['planned_date_reminder_time'] = Variable<int>(plannedDateReminderTime.value);
    }
    if (deadlineDateReminderTime.present) {
      map['deadline_date_reminder_time'] = Variable<int>(deadlineDateReminderTime.value);
    }
    if (recurrenceType.present) {
      map['recurrence_type'] = Variable<int>(recurrenceType.value);
    }
    if (recurrenceInterval.present) {
      map['recurrence_interval'] = Variable<int>(recurrenceInterval.value);
    }
    if (recurrenceDaysString.present) {
      map['recurrence_days_string'] = Variable<String>(recurrenceDaysString.value);
    }
    if (recurrenceStartDate.present) {
      map['recurrence_start_date'] = Variable<DateTime>(recurrenceStartDate.value);
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

class TaskTagTable extends Table with TableInfo<TaskTagTable, TaskTagTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  TaskTagTable(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id =
      GeneratedColumn<String>('id', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<DateTime> createdDate = GeneratedColumn<DateTime>('created_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  late final GeneratedColumn<DateTime> modifiedDate = GeneratedColumn<DateTime>('modified_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  late final GeneratedColumn<DateTime> deletedDate = GeneratedColumn<DateTime>('deleted_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  late final GeneratedColumn<String> taskId =
      GeneratedColumn<String>('task_id', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
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
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  TaskTagTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskTagTableData(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      createdDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_date'])!,
      modifiedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}modified_date']),
      deletedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_date']),
      taskId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}task_id'])!,
      tagId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}tag_id'])!,
    );
  }

  @override
  TaskTagTable createAlias(String alias) {
    return TaskTagTable(attachedDatabase, alias);
  }
}

class TaskTagTableData extends DataClass implements Insertable<TaskTagTableData> {
  final String id;
  final DateTime createdDate;
  final DateTime? modifiedDate;
  final DateTime? deletedDate;
  final String taskId;
  final String tagId;
  const TaskTagTableData(
      {required this.id,
      required this.createdDate,
      this.modifiedDate,
      this.deletedDate,
      required this.taskId,
      required this.tagId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_date'] = Variable<DateTime>(createdDate);
    if (!nullToAbsent || modifiedDate != null) {
      map['modified_date'] = Variable<DateTime>(modifiedDate);
    }
    if (!nullToAbsent || deletedDate != null) {
      map['deleted_date'] = Variable<DateTime>(deletedDate);
    }
    map['task_id'] = Variable<String>(taskId);
    map['tag_id'] = Variable<String>(tagId);
    return map;
  }

  TaskTagTableCompanion toCompanion(bool nullToAbsent) {
    return TaskTagTableCompanion(
      id: Value(id),
      createdDate: Value(createdDate),
      modifiedDate: modifiedDate == null && nullToAbsent ? const Value.absent() : Value(modifiedDate),
      deletedDate: deletedDate == null && nullToAbsent ? const Value.absent() : Value(deletedDate),
      taskId: Value(taskId),
      tagId: Value(tagId),
    );
  }

  factory TaskTagTableData.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskTagTableData(
      id: serializer.fromJson<String>(json['id']),
      createdDate: serializer.fromJson<DateTime>(json['createdDate']),
      modifiedDate: serializer.fromJson<DateTime?>(json['modifiedDate']),
      deletedDate: serializer.fromJson<DateTime?>(json['deletedDate']),
      taskId: serializer.fromJson<String>(json['taskId']),
      tagId: serializer.fromJson<String>(json['tagId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdDate': serializer.toJson<DateTime>(createdDate),
      'modifiedDate': serializer.toJson<DateTime?>(modifiedDate),
      'deletedDate': serializer.toJson<DateTime?>(deletedDate),
      'taskId': serializer.toJson<String>(taskId),
      'tagId': serializer.toJson<String>(tagId),
    };
  }

  TaskTagTableData copyWith(
          {String? id,
          DateTime? createdDate,
          Value<DateTime?> modifiedDate = const Value.absent(),
          Value<DateTime?> deletedDate = const Value.absent(),
          String? taskId,
          String? tagId}) =>
      TaskTagTableData(
        id: id ?? this.id,
        createdDate: createdDate ?? this.createdDate,
        modifiedDate: modifiedDate.present ? modifiedDate.value : this.modifiedDate,
        deletedDate: deletedDate.present ? deletedDate.value : this.deletedDate,
        taskId: taskId ?? this.taskId,
        tagId: tagId ?? this.tagId,
      );
  TaskTagTableData copyWithCompanion(TaskTagTableCompanion data) {
    return TaskTagTableData(
      id: data.id.present ? data.id.value : this.id,
      createdDate: data.createdDate.present ? data.createdDate.value : this.createdDate,
      modifiedDate: data.modifiedDate.present ? data.modifiedDate.value : this.modifiedDate,
      deletedDate: data.deletedDate.present ? data.deletedDate.value : this.deletedDate,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskTagTableData(')
          ..write('id: $id, ')
          ..write('createdDate: $createdDate, ')
          ..write('modifiedDate: $modifiedDate, ')
          ..write('deletedDate: $deletedDate, ')
          ..write('taskId: $taskId, ')
          ..write('tagId: $tagId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, createdDate, modifiedDate, deletedDate, taskId, tagId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskTagTableData &&
          other.id == this.id &&
          other.createdDate == this.createdDate &&
          other.modifiedDate == this.modifiedDate &&
          other.deletedDate == this.deletedDate &&
          other.taskId == this.taskId &&
          other.tagId == this.tagId);
}

class TaskTagTableCompanion extends UpdateCompanion<TaskTagTableData> {
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
  static Insertable<TaskTagTableData> custom({
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

class TaskTimeRecordTable extends Table with TableInfo<TaskTimeRecordTable, TaskTimeRecordTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  TaskTimeRecordTable(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id =
      GeneratedColumn<String>('id', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<String> taskId =
      GeneratedColumn<String>('task_id', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<int> duration =
      GeneratedColumn<int>('duration', aliasedName, false, type: DriftSqlType.int, requiredDuringInsert: true);
  late final GeneratedColumn<DateTime> createdDate = GeneratedColumn<DateTime>('created_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  late final GeneratedColumn<DateTime> modifiedDate = GeneratedColumn<DateTime>('modified_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  late final GeneratedColumn<DateTime> deletedDate = GeneratedColumn<DateTime>('deleted_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [id, taskId, duration, createdDate, modifiedDate, deletedDate];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'task_time_record_table';
  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  TaskTimeRecordTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskTimeRecordTableData(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      taskId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}task_id'])!,
      duration: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}duration'])!,
      createdDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_date'])!,
      modifiedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}modified_date']),
      deletedDate: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_date']),
    );
  }

  @override
  TaskTimeRecordTable createAlias(String alias) {
    return TaskTimeRecordTable(attachedDatabase, alias);
  }
}

class TaskTimeRecordTableData extends DataClass implements Insertable<TaskTimeRecordTableData> {
  final String id;
  final String taskId;
  final int duration;
  final DateTime createdDate;
  final DateTime? modifiedDate;
  final DateTime? deletedDate;
  const TaskTimeRecordTableData(
      {required this.id,
      required this.taskId,
      required this.duration,
      required this.createdDate,
      this.modifiedDate,
      this.deletedDate});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['task_id'] = Variable<String>(taskId);
    map['duration'] = Variable<int>(duration);
    map['created_date'] = Variable<DateTime>(createdDate);
    if (!nullToAbsent || modifiedDate != null) {
      map['modified_date'] = Variable<DateTime>(modifiedDate);
    }
    if (!nullToAbsent || deletedDate != null) {
      map['deleted_date'] = Variable<DateTime>(deletedDate);
    }
    return map;
  }

  TaskTimeRecordTableCompanion toCompanion(bool nullToAbsent) {
    return TaskTimeRecordTableCompanion(
      id: Value(id),
      taskId: Value(taskId),
      duration: Value(duration),
      createdDate: Value(createdDate),
      modifiedDate: modifiedDate == null && nullToAbsent ? const Value.absent() : Value(modifiedDate),
      deletedDate: deletedDate == null && nullToAbsent ? const Value.absent() : Value(deletedDate),
    );
  }

  factory TaskTimeRecordTableData.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskTimeRecordTableData(
      id: serializer.fromJson<String>(json['id']),
      taskId: serializer.fromJson<String>(json['taskId']),
      duration: serializer.fromJson<int>(json['duration']),
      createdDate: serializer.fromJson<DateTime>(json['createdDate']),
      modifiedDate: serializer.fromJson<DateTime?>(json['modifiedDate']),
      deletedDate: serializer.fromJson<DateTime?>(json['deletedDate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'taskId': serializer.toJson<String>(taskId),
      'duration': serializer.toJson<int>(duration),
      'createdDate': serializer.toJson<DateTime>(createdDate),
      'modifiedDate': serializer.toJson<DateTime?>(modifiedDate),
      'deletedDate': serializer.toJson<DateTime?>(deletedDate),
    };
  }

  TaskTimeRecordTableData copyWith(
          {String? id,
          String? taskId,
          int? duration,
          DateTime? createdDate,
          Value<DateTime?> modifiedDate = const Value.absent(),
          Value<DateTime?> deletedDate = const Value.absent()}) =>
      TaskTimeRecordTableData(
        id: id ?? this.id,
        taskId: taskId ?? this.taskId,
        duration: duration ?? this.duration,
        createdDate: createdDate ?? this.createdDate,
        modifiedDate: modifiedDate.present ? modifiedDate.value : this.modifiedDate,
        deletedDate: deletedDate.present ? deletedDate.value : this.deletedDate,
      );
  TaskTimeRecordTableData copyWithCompanion(TaskTimeRecordTableCompanion data) {
    return TaskTimeRecordTableData(
      id: data.id.present ? data.id.value : this.id,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      duration: data.duration.present ? data.duration.value : this.duration,
      createdDate: data.createdDate.present ? data.createdDate.value : this.createdDate,
      modifiedDate: data.modifiedDate.present ? data.modifiedDate.value : this.modifiedDate,
      deletedDate: data.deletedDate.present ? data.deletedDate.value : this.deletedDate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskTimeRecordTableData(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('duration: $duration, ')
          ..write('createdDate: $createdDate, ')
          ..write('modifiedDate: $modifiedDate, ')
          ..write('deletedDate: $deletedDate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, taskId, duration, createdDate, modifiedDate, deletedDate);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskTimeRecordTableData &&
          other.id == this.id &&
          other.taskId == this.taskId &&
          other.duration == this.duration &&
          other.createdDate == this.createdDate &&
          other.modifiedDate == this.modifiedDate &&
          other.deletedDate == this.deletedDate);
}

class TaskTimeRecordTableCompanion extends UpdateCompanion<TaskTimeRecordTableData> {
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
  static Insertable<TaskTimeRecordTableData> custom({
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

class DatabaseAtV19 extends GeneratedDatabase {
  DatabaseAtV19(QueryExecutor e) : super(e);
  late final AppUsageIgnoreRuleTable appUsageIgnoreRuleTable = AppUsageIgnoreRuleTable(this);
  late final AppUsageTable appUsageTable = AppUsageTable(this);
  late final AppUsageTagRuleTable appUsageTagRuleTable = AppUsageTagRuleTable(this);
  late final AppUsageTagTable appUsageTagTable = AppUsageTagTable(this);
  late final AppUsageTimeRecordTable appUsageTimeRecordTable = AppUsageTimeRecordTable(this);
  late final HabitRecordTable habitRecordTable = HabitRecordTable(this);
  late final HabitTable habitTable = HabitTable(this);
  late final HabitTagTable habitTagTable = HabitTagTable(this);
  late final NoteTable noteTable = NoteTable(this);
  late final NoteTagTable noteTagTable = NoteTagTable(this);
  late final SettingTable settingTable = SettingTable(this);
  late final SyncDeviceTable syncDeviceTable = SyncDeviceTable(this);
  late final TagTable tagTable = TagTable(this);
  late final TagTagTable tagTagTable = TagTagTable(this);
  late final TaskTable taskTable = TaskTable(this);
  late final TaskTagTable taskTagTable = TaskTagTable(this);
  late final TaskTimeRecordTable taskTimeRecordTable = TaskTimeRecordTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => allSchemaEntities.whereType<TableInfo<Table, Object?>>();
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
  @override
  int get schemaVersion => 19;
}

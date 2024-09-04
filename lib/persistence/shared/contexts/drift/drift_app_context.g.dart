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

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AppUsageTableTable appUsageTable = $AppUsageTableTable(this);
  late final $TaskTableTable taskTable = $TaskTableTable(this);
  late final $TagTableTable tagTable = $TagTableTable(this);
  late final $TagTagTableTable tagTagTable = $TagTagTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [appUsageTable, taskTable, tagTable, tagTagTable];
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

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AppUsageTableTableTableManager get appUsageTable => $$AppUsageTableTableTableManager(_db, _db.appUsageTable);
  $$TaskTableTableTableManager get taskTable => $$TaskTableTableTableManager(_db, _db.taskTable);
  $$TagTableTableTableManager get tagTable => $$TagTableTableTableManager(_db, _db.tagTable);
  $$TagTagTableTableTableManager get tagTagTable => $$TagTagTableTableTableManager(_db, _db.tagTagTable);
}

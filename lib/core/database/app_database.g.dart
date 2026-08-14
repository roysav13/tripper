// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $TripsTable extends Trips with TableInfo<$TripsTable, TripRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TripsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 80),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _startDateMeta =
      const VerificationMeta('startDate');
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
      'start_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _endDateMeta =
      const VerificationMeta('endDate');
  @override
  late final GeneratedColumn<DateTime> endDate = GeneratedColumn<DateTime>(
      'end_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _colorTagMeta =
      const VerificationMeta('colorTag');
  @override
  late final GeneratedColumn<int> colorTag = GeneratedColumn<int>(
      'color_tag', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _archivedMeta =
      const VerificationMeta('archived');
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
      'archived', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("archived" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _completionPromptShownMeta =
      const VerificationMeta('completionPromptShown');
  @override
  late final GeneratedColumn<bool> completionPromptShown =
      GeneratedColumn<bool>('completion_prompt_shown', aliasedName, false,
          type: DriftSqlType.bool,
          requiredDuringInsert: false,
          defaultConstraints: GeneratedColumn.constraintIsAlways(
              'CHECK ("completion_prompt_shown" IN (0, 1))'),
          defaultValue: const Constant(false));
  static const VerificationMeta _coverPhotoPathMeta =
      const VerificationMeta('coverPhotoPath');
  @override
  late final GeneratedColumn<String> coverPhotoPath = GeneratedColumn<String>(
      'cover_photo_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        startDate,
        endDate,
        colorTag,
        archived,
        completionPromptShown,
        coverPhotoPath,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trips';
  @override
  VerificationContext validateIntegrity(Insertable<TripRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('start_date')) {
      context.handle(_startDateMeta,
          startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta));
    }
    if (data.containsKey('end_date')) {
      context.handle(_endDateMeta,
          endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta));
    }
    if (data.containsKey('color_tag')) {
      context.handle(_colorTagMeta,
          colorTag.isAcceptableOrUnknown(data['color_tag']!, _colorTagMeta));
    }
    if (data.containsKey('archived')) {
      context.handle(_archivedMeta,
          archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta));
    }
    if (data.containsKey('completion_prompt_shown')) {
      context.handle(
          _completionPromptShownMeta,
          completionPromptShown.isAcceptableOrUnknown(
              data['completion_prompt_shown']!, _completionPromptShownMeta));
    }
    if (data.containsKey('cover_photo_path')) {
      context.handle(
          _coverPhotoPathMeta,
          coverPhotoPath.isAcceptableOrUnknown(
              data['cover_photo_path']!, _coverPhotoPathMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TripRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TripRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      startDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}start_date']),
      endDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}end_date']),
      colorTag: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}color_tag'])!,
      archived: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}archived'])!,
      completionPromptShown: attachedDatabase.typeMapping.read(
          DriftSqlType.bool,
          data['${effectivePrefix}completion_prompt_shown'])!,
      coverPhotoPath: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}cover_photo_path']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $TripsTable createAlias(String alias) {
    return $TripsTable(attachedDatabase, alias);
  }
}

class TripRow extends DataClass implements Insertable<TripRow> {
  final String id;
  final String name;
  final DateTime? startDate;
  final DateTime? endDate;
  final int colorTag;
  final bool archived;

  /// "Trip over — mark places visited?" is offered exactly once (M3).
  final bool completionPromptShown;

  /// Path to a locally-stored cover photo (redesign spec §6). Null means
  /// no photo — render the generated gradient fallback instead.
  final String? coverPhotoPath;
  final DateTime createdAt;
  const TripRow(
      {required this.id,
      required this.name,
      this.startDate,
      this.endDate,
      required this.colorTag,
      required this.archived,
      required this.completionPromptShown,
      this.coverPhotoPath,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || startDate != null) {
      map['start_date'] = Variable<DateTime>(startDate);
    }
    if (!nullToAbsent || endDate != null) {
      map['end_date'] = Variable<DateTime>(endDate);
    }
    map['color_tag'] = Variable<int>(colorTag);
    map['archived'] = Variable<bool>(archived);
    map['completion_prompt_shown'] = Variable<bool>(completionPromptShown);
    if (!nullToAbsent || coverPhotoPath != null) {
      map['cover_photo_path'] = Variable<String>(coverPhotoPath);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TripsCompanion toCompanion(bool nullToAbsent) {
    return TripsCompanion(
      id: Value(id),
      name: Value(name),
      startDate: startDate == null && nullToAbsent
          ? const Value.absent()
          : Value(startDate),
      endDate: endDate == null && nullToAbsent
          ? const Value.absent()
          : Value(endDate),
      colorTag: Value(colorTag),
      archived: Value(archived),
      completionPromptShown: Value(completionPromptShown),
      coverPhotoPath: coverPhotoPath == null && nullToAbsent
          ? const Value.absent()
          : Value(coverPhotoPath),
      createdAt: Value(createdAt),
    );
  }

  factory TripRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TripRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      startDate: serializer.fromJson<DateTime?>(json['startDate']),
      endDate: serializer.fromJson<DateTime?>(json['endDate']),
      colorTag: serializer.fromJson<int>(json['colorTag']),
      archived: serializer.fromJson<bool>(json['archived']),
      completionPromptShown:
          serializer.fromJson<bool>(json['completionPromptShown']),
      coverPhotoPath: serializer.fromJson<String?>(json['coverPhotoPath']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'startDate': serializer.toJson<DateTime?>(startDate),
      'endDate': serializer.toJson<DateTime?>(endDate),
      'colorTag': serializer.toJson<int>(colorTag),
      'archived': serializer.toJson<bool>(archived),
      'completionPromptShown': serializer.toJson<bool>(completionPromptShown),
      'coverPhotoPath': serializer.toJson<String?>(coverPhotoPath),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TripRow copyWith(
          {String? id,
          String? name,
          Value<DateTime?> startDate = const Value.absent(),
          Value<DateTime?> endDate = const Value.absent(),
          int? colorTag,
          bool? archived,
          bool? completionPromptShown,
          Value<String?> coverPhotoPath = const Value.absent(),
          DateTime? createdAt}) =>
      TripRow(
        id: id ?? this.id,
        name: name ?? this.name,
        startDate: startDate.present ? startDate.value : this.startDate,
        endDate: endDate.present ? endDate.value : this.endDate,
        colorTag: colorTag ?? this.colorTag,
        archived: archived ?? this.archived,
        completionPromptShown:
            completionPromptShown ?? this.completionPromptShown,
        coverPhotoPath:
            coverPhotoPath.present ? coverPhotoPath.value : this.coverPhotoPath,
        createdAt: createdAt ?? this.createdAt,
      );
  TripRow copyWithCompanion(TripsCompanion data) {
    return TripRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      colorTag: data.colorTag.present ? data.colorTag.value : this.colorTag,
      archived: data.archived.present ? data.archived.value : this.archived,
      completionPromptShown: data.completionPromptShown.present
          ? data.completionPromptShown.value
          : this.completionPromptShown,
      coverPhotoPath: data.coverPhotoPath.present
          ? data.coverPhotoPath.value
          : this.coverPhotoPath,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TripRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('colorTag: $colorTag, ')
          ..write('archived: $archived, ')
          ..write('completionPromptShown: $completionPromptShown, ')
          ..write('coverPhotoPath: $coverPhotoPath, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, startDate, endDate, colorTag,
      archived, completionPromptShown, coverPhotoPath, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TripRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.colorTag == this.colorTag &&
          other.archived == this.archived &&
          other.completionPromptShown == this.completionPromptShown &&
          other.coverPhotoPath == this.coverPhotoPath &&
          other.createdAt == this.createdAt);
}

class TripsCompanion extends UpdateCompanion<TripRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<DateTime?> startDate;
  final Value<DateTime?> endDate;
  final Value<int> colorTag;
  final Value<bool> archived;
  final Value<bool> completionPromptShown;
  final Value<String?> coverPhotoPath;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const TripsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.colorTag = const Value.absent(),
    this.archived = const Value.absent(),
    this.completionPromptShown = const Value.absent(),
    this.coverPhotoPath = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TripsCompanion.insert({
    required String id,
    required String name,
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.colorTag = const Value.absent(),
    this.archived = const Value.absent(),
    this.completionPromptShown = const Value.absent(),
    this.coverPhotoPath = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        createdAt = Value(createdAt);
  static Insertable<TripRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<DateTime>? startDate,
    Expression<DateTime>? endDate,
    Expression<int>? colorTag,
    Expression<bool>? archived,
    Expression<bool>? completionPromptShown,
    Expression<String>? coverPhotoPath,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (colorTag != null) 'color_tag': colorTag,
      if (archived != null) 'archived': archived,
      if (completionPromptShown != null)
        'completion_prompt_shown': completionPromptShown,
      if (coverPhotoPath != null) 'cover_photo_path': coverPhotoPath,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TripsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<DateTime?>? startDate,
      Value<DateTime?>? endDate,
      Value<int>? colorTag,
      Value<bool>? archived,
      Value<bool>? completionPromptShown,
      Value<String?>? coverPhotoPath,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return TripsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      colorTag: colorTag ?? this.colorTag,
      archived: archived ?? this.archived,
      completionPromptShown:
          completionPromptShown ?? this.completionPromptShown,
      coverPhotoPath: coverPhotoPath ?? this.coverPhotoPath,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<DateTime>(endDate.value);
    }
    if (colorTag.present) {
      map['color_tag'] = Variable<int>(colorTag.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (completionPromptShown.present) {
      map['completion_prompt_shown'] =
          Variable<bool>(completionPromptShown.value);
    }
    if (coverPhotoPath.present) {
      map['cover_photo_path'] = Variable<String>(coverPhotoPath.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TripsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('colorTag: $colorTag, ')
          ..write('archived: $archived, ')
          ..write('completionPromptShown: $completionPromptShown, ')
          ..write('coverPhotoPath: $coverPhotoPath, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TripDestinationsTable extends TripDestinations
    with TableInfo<$TripDestinationsTable, TripDestinationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TripDestinationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tripIdMeta = const VerificationMeta('tripId');
  @override
  late final GeneratedColumn<String> tripId = GeneratedColumn<String>(
      'trip_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES trips (id) ON DELETE CASCADE'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 80),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _orderIndexMeta =
      const VerificationMeta('orderIndex');
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
      'order_index', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, tripId, name, orderIndex];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trip_destinations';
  @override
  VerificationContext validateIntegrity(Insertable<TripDestinationRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('trip_id')) {
      context.handle(_tripIdMeta,
          tripId.isAcceptableOrUnknown(data['trip_id']!, _tripIdMeta));
    } else if (isInserting) {
      context.missing(_tripIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('order_index')) {
      context.handle(
          _orderIndexMeta,
          orderIndex.isAcceptableOrUnknown(
              data['order_index']!, _orderIndexMeta));
    } else if (isInserting) {
      context.missing(_orderIndexMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TripDestinationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TripDestinationRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      tripId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}trip_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      orderIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}order_index'])!,
    );
  }

  @override
  $TripDestinationsTable createAlias(String alias) {
    return $TripDestinationsTable(attachedDatabase, alias);
  }
}

class TripDestinationRow extends DataClass
    implements Insertable<TripDestinationRow> {
  final String id;
  final String tripId;
  final String name;
  final int orderIndex;
  const TripDestinationRow(
      {required this.id,
      required this.tripId,
      required this.name,
      required this.orderIndex});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['trip_id'] = Variable<String>(tripId);
    map['name'] = Variable<String>(name);
    map['order_index'] = Variable<int>(orderIndex);
    return map;
  }

  TripDestinationsCompanion toCompanion(bool nullToAbsent) {
    return TripDestinationsCompanion(
      id: Value(id),
      tripId: Value(tripId),
      name: Value(name),
      orderIndex: Value(orderIndex),
    );
  }

  factory TripDestinationRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TripDestinationRow(
      id: serializer.fromJson<String>(json['id']),
      tripId: serializer.fromJson<String>(json['tripId']),
      name: serializer.fromJson<String>(json['name']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tripId': serializer.toJson<String>(tripId),
      'name': serializer.toJson<String>(name),
      'orderIndex': serializer.toJson<int>(orderIndex),
    };
  }

  TripDestinationRow copyWith(
          {String? id, String? tripId, String? name, int? orderIndex}) =>
      TripDestinationRow(
        id: id ?? this.id,
        tripId: tripId ?? this.tripId,
        name: name ?? this.name,
        orderIndex: orderIndex ?? this.orderIndex,
      );
  TripDestinationRow copyWithCompanion(TripDestinationsCompanion data) {
    return TripDestinationRow(
      id: data.id.present ? data.id.value : this.id,
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      name: data.name.present ? data.name.value : this.name,
      orderIndex:
          data.orderIndex.present ? data.orderIndex.value : this.orderIndex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TripDestinationRow(')
          ..write('id: $id, ')
          ..write('tripId: $tripId, ')
          ..write('name: $name, ')
          ..write('orderIndex: $orderIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, tripId, name, orderIndex);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TripDestinationRow &&
          other.id == this.id &&
          other.tripId == this.tripId &&
          other.name == this.name &&
          other.orderIndex == this.orderIndex);
}

class TripDestinationsCompanion extends UpdateCompanion<TripDestinationRow> {
  final Value<String> id;
  final Value<String> tripId;
  final Value<String> name;
  final Value<int> orderIndex;
  final Value<int> rowid;
  const TripDestinationsCompanion({
    this.id = const Value.absent(),
    this.tripId = const Value.absent(),
    this.name = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TripDestinationsCompanion.insert({
    required String id,
    required String tripId,
    required String name,
    required int orderIndex,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        tripId = Value(tripId),
        name = Value(name),
        orderIndex = Value(orderIndex);
  static Insertable<TripDestinationRow> custom({
    Expression<String>? id,
    Expression<String>? tripId,
    Expression<String>? name,
    Expression<int>? orderIndex,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tripId != null) 'trip_id': tripId,
      if (name != null) 'name': name,
      if (orderIndex != null) 'order_index': orderIndex,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TripDestinationsCompanion copyWith(
      {Value<String>? id,
      Value<String>? tripId,
      Value<String>? name,
      Value<int>? orderIndex,
      Value<int>? rowid}) {
    return TripDestinationsCompanion(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      name: name ?? this.name,
      orderIndex: orderIndex ?? this.orderIndex,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tripId.present) {
      map['trip_id'] = Variable<String>(tripId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TripDestinationsCompanion(')
          ..write('id: $id, ')
          ..write('tripId: $tripId, ')
          ..write('name: $name, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DocumentsTable extends Documents
    with TableInfo<$DocumentsTable, DocumentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DocumentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 120),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<int> category = GeneratedColumn<int>(
      'category', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _filePathMeta =
      const VerificationMeta('filePath');
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
      'file_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _mimeTypeMeta =
      const VerificationMeta('mimeType');
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
      'mime_type', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _expiryDateMeta =
      const VerificationMeta('expiryDate');
  @override
  late final GeneratedColumn<DateTime> expiryDate = GeneratedColumn<DateTime>(
      'expiry_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _isGlobalMeta =
      const VerificationMeta('isGlobal');
  @override
  late final GeneratedColumn<bool> isGlobal = GeneratedColumn<bool>(
      'is_global', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_global" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isPinnedMeta =
      const VerificationMeta('isPinned');
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
      'is_pinned', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_pinned" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _detailsJsonMeta =
      const VerificationMeta('detailsJson');
  @override
  late final GeneratedColumn<String> detailsJson = GeneratedColumn<String>(
      'details_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('{}'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        title,
        category,
        filePath,
        mimeType,
        expiryDate,
        isGlobal,
        isPinned,
        detailsJson,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'documents';
  @override
  VerificationContext validateIntegrity(Insertable<DocumentRow> instance,
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
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(_filePathMeta,
          filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta));
    }
    if (data.containsKey('mime_type')) {
      context.handle(_mimeTypeMeta,
          mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta));
    }
    if (data.containsKey('expiry_date')) {
      context.handle(
          _expiryDateMeta,
          expiryDate.isAcceptableOrUnknown(
              data['expiry_date']!, _expiryDateMeta));
    }
    if (data.containsKey('is_global')) {
      context.handle(_isGlobalMeta,
          isGlobal.isAcceptableOrUnknown(data['is_global']!, _isGlobalMeta));
    }
    if (data.containsKey('is_pinned')) {
      context.handle(_isPinnedMeta,
          isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta));
    }
    if (data.containsKey('details_json')) {
      context.handle(
          _detailsJsonMeta,
          detailsJson.isAcceptableOrUnknown(
              data['details_json']!, _detailsJsonMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DocumentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DocumentRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}category'])!,
      filePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_path']),
      mimeType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}mime_type']),
      expiryDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}expiry_date']),
      isGlobal: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_global'])!,
      isPinned: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_pinned'])!,
      detailsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}details_json'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $DocumentsTable createAlias(String alias) {
    return $DocumentsTable(attachedDatabase, alias);
  }
}

class DocumentRow extends DataClass implements Insertable<DocumentRow> {
  final String id;
  final String title;

  /// Index into DocumentCategory enum.
  final int category;

  /// Null for manual records (no file attached).
  final String? filePath;
  final String? mimeType;
  final DateTime? expiryDate;

  /// Global documents (passport, insurance) outlive trips.
  final bool isGlobal;
  final bool isPinned;

  /// Category-specific fields (flight number, confirmation code…) as JSON.
  final String detailsJson;
  final DateTime createdAt;
  const DocumentRow(
      {required this.id,
      required this.title,
      required this.category,
      this.filePath,
      this.mimeType,
      this.expiryDate,
      required this.isGlobal,
      required this.isPinned,
      required this.detailsJson,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['category'] = Variable<int>(category);
    if (!nullToAbsent || filePath != null) {
      map['file_path'] = Variable<String>(filePath);
    }
    if (!nullToAbsent || mimeType != null) {
      map['mime_type'] = Variable<String>(mimeType);
    }
    if (!nullToAbsent || expiryDate != null) {
      map['expiry_date'] = Variable<DateTime>(expiryDate);
    }
    map['is_global'] = Variable<bool>(isGlobal);
    map['is_pinned'] = Variable<bool>(isPinned);
    map['details_json'] = Variable<String>(detailsJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  DocumentsCompanion toCompanion(bool nullToAbsent) {
    return DocumentsCompanion(
      id: Value(id),
      title: Value(title),
      category: Value(category),
      filePath: filePath == null && nullToAbsent
          ? const Value.absent()
          : Value(filePath),
      mimeType: mimeType == null && nullToAbsent
          ? const Value.absent()
          : Value(mimeType),
      expiryDate: expiryDate == null && nullToAbsent
          ? const Value.absent()
          : Value(expiryDate),
      isGlobal: Value(isGlobal),
      isPinned: Value(isPinned),
      detailsJson: Value(detailsJson),
      createdAt: Value(createdAt),
    );
  }

  factory DocumentRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DocumentRow(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      category: serializer.fromJson<int>(json['category']),
      filePath: serializer.fromJson<String?>(json['filePath']),
      mimeType: serializer.fromJson<String?>(json['mimeType']),
      expiryDate: serializer.fromJson<DateTime?>(json['expiryDate']),
      isGlobal: serializer.fromJson<bool>(json['isGlobal']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      detailsJson: serializer.fromJson<String>(json['detailsJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'category': serializer.toJson<int>(category),
      'filePath': serializer.toJson<String?>(filePath),
      'mimeType': serializer.toJson<String?>(mimeType),
      'expiryDate': serializer.toJson<DateTime?>(expiryDate),
      'isGlobal': serializer.toJson<bool>(isGlobal),
      'isPinned': serializer.toJson<bool>(isPinned),
      'detailsJson': serializer.toJson<String>(detailsJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  DocumentRow copyWith(
          {String? id,
          String? title,
          int? category,
          Value<String?> filePath = const Value.absent(),
          Value<String?> mimeType = const Value.absent(),
          Value<DateTime?> expiryDate = const Value.absent(),
          bool? isGlobal,
          bool? isPinned,
          String? detailsJson,
          DateTime? createdAt}) =>
      DocumentRow(
        id: id ?? this.id,
        title: title ?? this.title,
        category: category ?? this.category,
        filePath: filePath.present ? filePath.value : this.filePath,
        mimeType: mimeType.present ? mimeType.value : this.mimeType,
        expiryDate: expiryDate.present ? expiryDate.value : this.expiryDate,
        isGlobal: isGlobal ?? this.isGlobal,
        isPinned: isPinned ?? this.isPinned,
        detailsJson: detailsJson ?? this.detailsJson,
        createdAt: createdAt ?? this.createdAt,
      );
  DocumentRow copyWithCompanion(DocumentsCompanion data) {
    return DocumentRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      category: data.category.present ? data.category.value : this.category,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      expiryDate:
          data.expiryDate.present ? data.expiryDate.value : this.expiryDate,
      isGlobal: data.isGlobal.present ? data.isGlobal.value : this.isGlobal,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      detailsJson:
          data.detailsJson.present ? data.detailsJson.value : this.detailsJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DocumentRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('category: $category, ')
          ..write('filePath: $filePath, ')
          ..write('mimeType: $mimeType, ')
          ..write('expiryDate: $expiryDate, ')
          ..write('isGlobal: $isGlobal, ')
          ..write('isPinned: $isPinned, ')
          ..write('detailsJson: $detailsJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, category, filePath, mimeType,
      expiryDate, isGlobal, isPinned, detailsJson, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DocumentRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.category == this.category &&
          other.filePath == this.filePath &&
          other.mimeType == this.mimeType &&
          other.expiryDate == this.expiryDate &&
          other.isGlobal == this.isGlobal &&
          other.isPinned == this.isPinned &&
          other.detailsJson == this.detailsJson &&
          other.createdAt == this.createdAt);
}

class DocumentsCompanion extends UpdateCompanion<DocumentRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<int> category;
  final Value<String?> filePath;
  final Value<String?> mimeType;
  final Value<DateTime?> expiryDate;
  final Value<bool> isGlobal;
  final Value<bool> isPinned;
  final Value<String> detailsJson;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const DocumentsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.category = const Value.absent(),
    this.filePath = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.expiryDate = const Value.absent(),
    this.isGlobal = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.detailsJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DocumentsCompanion.insert({
    required String id,
    required String title,
    required int category,
    this.filePath = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.expiryDate = const Value.absent(),
    this.isGlobal = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.detailsJson = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        title = Value(title),
        category = Value(category),
        createdAt = Value(createdAt);
  static Insertable<DocumentRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<int>? category,
    Expression<String>? filePath,
    Expression<String>? mimeType,
    Expression<DateTime>? expiryDate,
    Expression<bool>? isGlobal,
    Expression<bool>? isPinned,
    Expression<String>? detailsJson,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (category != null) 'category': category,
      if (filePath != null) 'file_path': filePath,
      if (mimeType != null) 'mime_type': mimeType,
      if (expiryDate != null) 'expiry_date': expiryDate,
      if (isGlobal != null) 'is_global': isGlobal,
      if (isPinned != null) 'is_pinned': isPinned,
      if (detailsJson != null) 'details_json': detailsJson,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DocumentsCompanion copyWith(
      {Value<String>? id,
      Value<String>? title,
      Value<int>? category,
      Value<String?>? filePath,
      Value<String?>? mimeType,
      Value<DateTime?>? expiryDate,
      Value<bool>? isGlobal,
      Value<bool>? isPinned,
      Value<String>? detailsJson,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return DocumentsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      filePath: filePath ?? this.filePath,
      mimeType: mimeType ?? this.mimeType,
      expiryDate: expiryDate ?? this.expiryDate,
      isGlobal: isGlobal ?? this.isGlobal,
      isPinned: isPinned ?? this.isPinned,
      detailsJson: detailsJson ?? this.detailsJson,
      createdAt: createdAt ?? this.createdAt,
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
    if (category.present) {
      map['category'] = Variable<int>(category.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (expiryDate.present) {
      map['expiry_date'] = Variable<DateTime>(expiryDate.value);
    }
    if (isGlobal.present) {
      map['is_global'] = Variable<bool>(isGlobal.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (detailsJson.present) {
      map['details_json'] = Variable<String>(detailsJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DocumentsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('category: $category, ')
          ..write('filePath: $filePath, ')
          ..write('mimeType: $mimeType, ')
          ..write('expiryDate: $expiryDate, ')
          ..write('isGlobal: $isGlobal, ')
          ..write('isPinned: $isPinned, ')
          ..write('detailsJson: $detailsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TripDocumentsTable extends TripDocuments
    with TableInfo<$TripDocumentsTable, TripDocumentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TripDocumentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _tripIdMeta = const VerificationMeta('tripId');
  @override
  late final GeneratedColumn<String> tripId = GeneratedColumn<String>(
      'trip_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES trips (id) ON DELETE CASCADE'));
  static const VerificationMeta _documentIdMeta =
      const VerificationMeta('documentId');
  @override
  late final GeneratedColumn<String> documentId = GeneratedColumn<String>(
      'document_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES documents (id) ON DELETE CASCADE'));
  @override
  List<GeneratedColumn> get $columns => [tripId, documentId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trip_documents';
  @override
  VerificationContext validateIntegrity(Insertable<TripDocumentRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('trip_id')) {
      context.handle(_tripIdMeta,
          tripId.isAcceptableOrUnknown(data['trip_id']!, _tripIdMeta));
    } else if (isInserting) {
      context.missing(_tripIdMeta);
    }
    if (data.containsKey('document_id')) {
      context.handle(
          _documentIdMeta,
          documentId.isAcceptableOrUnknown(
              data['document_id']!, _documentIdMeta));
    } else if (isInserting) {
      context.missing(_documentIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {tripId, documentId};
  @override
  TripDocumentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TripDocumentRow(
      tripId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}trip_id'])!,
      documentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}document_id'])!,
    );
  }

  @override
  $TripDocumentsTable createAlias(String alias) {
    return $TripDocumentsTable(attachedDatabase, alias);
  }
}

class TripDocumentRow extends DataClass implements Insertable<TripDocumentRow> {
  final String tripId;
  final String documentId;
  const TripDocumentRow({required this.tripId, required this.documentId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['trip_id'] = Variable<String>(tripId);
    map['document_id'] = Variable<String>(documentId);
    return map;
  }

  TripDocumentsCompanion toCompanion(bool nullToAbsent) {
    return TripDocumentsCompanion(
      tripId: Value(tripId),
      documentId: Value(documentId),
    );
  }

  factory TripDocumentRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TripDocumentRow(
      tripId: serializer.fromJson<String>(json['tripId']),
      documentId: serializer.fromJson<String>(json['documentId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'tripId': serializer.toJson<String>(tripId),
      'documentId': serializer.toJson<String>(documentId),
    };
  }

  TripDocumentRow copyWith({String? tripId, String? documentId}) =>
      TripDocumentRow(
        tripId: tripId ?? this.tripId,
        documentId: documentId ?? this.documentId,
      );
  TripDocumentRow copyWithCompanion(TripDocumentsCompanion data) {
    return TripDocumentRow(
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      documentId:
          data.documentId.present ? data.documentId.value : this.documentId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TripDocumentRow(')
          ..write('tripId: $tripId, ')
          ..write('documentId: $documentId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(tripId, documentId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TripDocumentRow &&
          other.tripId == this.tripId &&
          other.documentId == this.documentId);
}

class TripDocumentsCompanion extends UpdateCompanion<TripDocumentRow> {
  final Value<String> tripId;
  final Value<String> documentId;
  final Value<int> rowid;
  const TripDocumentsCompanion({
    this.tripId = const Value.absent(),
    this.documentId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TripDocumentsCompanion.insert({
    required String tripId,
    required String documentId,
    this.rowid = const Value.absent(),
  })  : tripId = Value(tripId),
        documentId = Value(documentId);
  static Insertable<TripDocumentRow> custom({
    Expression<String>? tripId,
    Expression<String>? documentId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (tripId != null) 'trip_id': tripId,
      if (documentId != null) 'document_id': documentId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TripDocumentsCompanion copyWith(
      {Value<String>? tripId, Value<String>? documentId, Value<int>? rowid}) {
    return TripDocumentsCompanion(
      tripId: tripId ?? this.tripId,
      documentId: documentId ?? this.documentId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (tripId.present) {
      map['trip_id'] = Variable<String>(tripId.value);
    }
    if (documentId.present) {
      map['document_id'] = Variable<String>(documentId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TripDocumentsCompanion(')
          ..write('tripId: $tripId, ')
          ..write('documentId: $documentId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlacesTable extends Places with TableInfo<$PlacesTable, PlaceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlacesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 120),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _latMeta = const VerificationMeta('lat');
  @override
  late final GeneratedColumn<double> lat = GeneratedColumn<double>(
      'lat', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _lngMeta = const VerificationMeta('lng');
  @override
  late final GeneratedColumn<double> lng = GeneratedColumn<double>(
      'lng', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _countryMeta =
      const VerificationMeta('country');
  @override
  late final GeneratedColumn<String> country = GeneratedColumn<String>(
      'country', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _cityMeta = const VerificationMeta('city');
  @override
  late final GeneratedColumn<String> city = GeneratedColumn<String>(
      'city', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
      'status', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _visitedAtMeta =
      const VerificationMeta('visitedAt');
  @override
  late final GeneratedColumn<DateTime> visitedAt = GeneratedColumn<DateTime>(
      'visited_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _tripIdMeta = const VerificationMeta('tripId');
  @override
  late final GeneratedColumn<String> tripId = GeneratedColumn<String>(
      'trip_id', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES trips (id) ON DELETE SET NULL'));
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<int> category = GeneratedColumn<int>(
      'category', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        lat,
        lng,
        country,
        city,
        status,
        visitedAt,
        tripId,
        notes,
        createdAt,
        category
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'places';
  @override
  VerificationContext validateIntegrity(Insertable<PlaceRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('lat')) {
      context.handle(
          _latMeta, lat.isAcceptableOrUnknown(data['lat']!, _latMeta));
    }
    if (data.containsKey('lng')) {
      context.handle(
          _lngMeta, lng.isAcceptableOrUnknown(data['lng']!, _lngMeta));
    }
    if (data.containsKey('country')) {
      context.handle(_countryMeta,
          country.isAcceptableOrUnknown(data['country']!, _countryMeta));
    }
    if (data.containsKey('city')) {
      context.handle(
          _cityMeta, city.isAcceptableOrUnknown(data['city']!, _cityMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('visited_at')) {
      context.handle(_visitedAtMeta,
          visitedAt.isAcceptableOrUnknown(data['visited_at']!, _visitedAtMeta));
    }
    if (data.containsKey('trip_id')) {
      context.handle(_tripIdMeta,
          tripId.isAcceptableOrUnknown(data['trip_id']!, _tripIdMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlaceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaceRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      lat: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}lat']),
      lng: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}lng']),
      country: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}country'])!,
      city: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}city'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}status'])!,
      visitedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}visited_at']),
      tripId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}trip_id']),
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}category']),
    );
  }

  @override
  $PlacesTable createAlias(String alias) {
    return $PlacesTable(attachedDatabase, alias);
  }
}

class PlaceRow extends DataClass implements Insertable<PlaceRow> {
  final String id;
  final String name;

  /// Nullable — a place can exist before it's located on the map (M3b).
  final double? lat;
  final double? lng;
  final String country;
  final String city;

  /// Index into PlaceStatus enum.
  final int status;
  final DateTime? visitedAt;

  /// Deleting a trip keeps its places (SET NULL — M3 plan decision).
  final String? tripId;
  final String notes;
  final DateTime createdAt;

  /// Index into PlaceCategory enum; null = uncategorized (existing rows,
  /// or a place the user hasn't categorized yet).
  final int? category;
  const PlaceRow(
      {required this.id,
      required this.name,
      this.lat,
      this.lng,
      required this.country,
      required this.city,
      required this.status,
      this.visitedAt,
      this.tripId,
      required this.notes,
      required this.createdAt,
      this.category});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || lat != null) {
      map['lat'] = Variable<double>(lat);
    }
    if (!nullToAbsent || lng != null) {
      map['lng'] = Variable<double>(lng);
    }
    map['country'] = Variable<String>(country);
    map['city'] = Variable<String>(city);
    map['status'] = Variable<int>(status);
    if (!nullToAbsent || visitedAt != null) {
      map['visited_at'] = Variable<DateTime>(visitedAt);
    }
    if (!nullToAbsent || tripId != null) {
      map['trip_id'] = Variable<String>(tripId);
    }
    map['notes'] = Variable<String>(notes);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<int>(category);
    }
    return map;
  }

  PlacesCompanion toCompanion(bool nullToAbsent) {
    return PlacesCompanion(
      id: Value(id),
      name: Value(name),
      lat: lat == null && nullToAbsent ? const Value.absent() : Value(lat),
      lng: lng == null && nullToAbsent ? const Value.absent() : Value(lng),
      country: Value(country),
      city: Value(city),
      status: Value(status),
      visitedAt: visitedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(visitedAt),
      tripId:
          tripId == null && nullToAbsent ? const Value.absent() : Value(tripId),
      notes: Value(notes),
      createdAt: Value(createdAt),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
    );
  }

  factory PlaceRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaceRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      lat: serializer.fromJson<double?>(json['lat']),
      lng: serializer.fromJson<double?>(json['lng']),
      country: serializer.fromJson<String>(json['country']),
      city: serializer.fromJson<String>(json['city']),
      status: serializer.fromJson<int>(json['status']),
      visitedAt: serializer.fromJson<DateTime?>(json['visitedAt']),
      tripId: serializer.fromJson<String?>(json['tripId']),
      notes: serializer.fromJson<String>(json['notes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      category: serializer.fromJson<int?>(json['category']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'lat': serializer.toJson<double?>(lat),
      'lng': serializer.toJson<double?>(lng),
      'country': serializer.toJson<String>(country),
      'city': serializer.toJson<String>(city),
      'status': serializer.toJson<int>(status),
      'visitedAt': serializer.toJson<DateTime?>(visitedAt),
      'tripId': serializer.toJson<String?>(tripId),
      'notes': serializer.toJson<String>(notes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'category': serializer.toJson<int?>(category),
    };
  }

  PlaceRow copyWith(
          {String? id,
          String? name,
          Value<double?> lat = const Value.absent(),
          Value<double?> lng = const Value.absent(),
          String? country,
          String? city,
          int? status,
          Value<DateTime?> visitedAt = const Value.absent(),
          Value<String?> tripId = const Value.absent(),
          String? notes,
          DateTime? createdAt,
          Value<int?> category = const Value.absent()}) =>
      PlaceRow(
        id: id ?? this.id,
        name: name ?? this.name,
        lat: lat.present ? lat.value : this.lat,
        lng: lng.present ? lng.value : this.lng,
        country: country ?? this.country,
        city: city ?? this.city,
        status: status ?? this.status,
        visitedAt: visitedAt.present ? visitedAt.value : this.visitedAt,
        tripId: tripId.present ? tripId.value : this.tripId,
        notes: notes ?? this.notes,
        createdAt: createdAt ?? this.createdAt,
        category: category.present ? category.value : this.category,
      );
  PlaceRow copyWithCompanion(PlacesCompanion data) {
    return PlaceRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      lat: data.lat.present ? data.lat.value : this.lat,
      lng: data.lng.present ? data.lng.value : this.lng,
      country: data.country.present ? data.country.value : this.country,
      city: data.city.present ? data.city.value : this.city,
      status: data.status.present ? data.status.value : this.status,
      visitedAt: data.visitedAt.present ? data.visitedAt.value : this.visitedAt,
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      category: data.category.present ? data.category.value : this.category,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaceRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('country: $country, ')
          ..write('city: $city, ')
          ..write('status: $status, ')
          ..write('visitedAt: $visitedAt, ')
          ..write('tripId: $tripId, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('category: $category')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, lat, lng, country, city, status,
      visitedAt, tripId, notes, createdAt, category);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaceRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.lat == this.lat &&
          other.lng == this.lng &&
          other.country == this.country &&
          other.city == this.city &&
          other.status == this.status &&
          other.visitedAt == this.visitedAt &&
          other.tripId == this.tripId &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt &&
          other.category == this.category);
}

class PlacesCompanion extends UpdateCompanion<PlaceRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<double?> lat;
  final Value<double?> lng;
  final Value<String> country;
  final Value<String> city;
  final Value<int> status;
  final Value<DateTime?> visitedAt;
  final Value<String?> tripId;
  final Value<String> notes;
  final Value<DateTime> createdAt;
  final Value<int?> category;
  final Value<int> rowid;
  const PlacesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
    this.country = const Value.absent(),
    this.city = const Value.absent(),
    this.status = const Value.absent(),
    this.visitedAt = const Value.absent(),
    this.tripId = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.category = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlacesCompanion.insert({
    required String id,
    required String name,
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
    this.country = const Value.absent(),
    this.city = const Value.absent(),
    required int status,
    this.visitedAt = const Value.absent(),
    this.tripId = const Value.absent(),
    this.notes = const Value.absent(),
    required DateTime createdAt,
    this.category = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        status = Value(status),
        createdAt = Value(createdAt);
  static Insertable<PlaceRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<double>? lat,
    Expression<double>? lng,
    Expression<String>? country,
    Expression<String>? city,
    Expression<int>? status,
    Expression<DateTime>? visitedAt,
    Expression<String>? tripId,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
    Expression<int>? category,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (country != null) 'country': country,
      if (city != null) 'city': city,
      if (status != null) 'status': status,
      if (visitedAt != null) 'visited_at': visitedAt,
      if (tripId != null) 'trip_id': tripId,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (category != null) 'category': category,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlacesCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<double?>? lat,
      Value<double?>? lng,
      Value<String>? country,
      Value<String>? city,
      Value<int>? status,
      Value<DateTime?>? visitedAt,
      Value<String?>? tripId,
      Value<String>? notes,
      Value<DateTime>? createdAt,
      Value<int?>? category,
      Value<int>? rowid}) {
    return PlacesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      country: country ?? this.country,
      city: city ?? this.city,
      status: status ?? this.status,
      visitedAt: visitedAt ?? this.visitedAt,
      tripId: tripId ?? this.tripId,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      category: category ?? this.category,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (lat.present) {
      map['lat'] = Variable<double>(lat.value);
    }
    if (lng.present) {
      map['lng'] = Variable<double>(lng.value);
    }
    if (country.present) {
      map['country'] = Variable<String>(country.value);
    }
    if (city.present) {
      map['city'] = Variable<String>(city.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (visitedAt.present) {
      map['visited_at'] = Variable<DateTime>(visitedAt.value);
    }
    if (tripId.present) {
      map['trip_id'] = Variable<String>(tripId.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (category.present) {
      map['category'] = Variable<int>(category.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlacesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('country: $country, ')
          ..write('city: $city, ')
          ..write('status: $status, ')
          ..write('visitedAt: $visitedAt, ')
          ..write('tripId: $tripId, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('category: $category, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExpensesTable extends Expenses
    with TableInfo<$ExpensesTable, ExpenseRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExpensesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tripIdMeta = const VerificationMeta('tripId');
  @override
  late final GeneratedColumn<String> tripId = GeneratedColumn<String>(
      'trip_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES trips (id) ON DELETE CASCADE'));
  static const VerificationMeta _amountMinorMeta =
      const VerificationMeta('amountMinor');
  @override
  late final GeneratedColumn<int> amountMinor = GeneratedColumn<int>(
      'amount_minor', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 3, maxTextLength: 3),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<int> category = GeneratedColumn<int>(
      'category', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
      'date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _convertedAmountMinorMeta =
      const VerificationMeta('convertedAmountMinor');
  @override
  late final GeneratedColumn<int> convertedAmountMinor = GeneratedColumn<int>(
      'converted_amount_minor', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _convertedCurrencyMeta =
      const VerificationMeta('convertedCurrency');
  @override
  late final GeneratedColumn<String> convertedCurrency =
      GeneratedColumn<String>('converted_currency', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _convertedRateAtMeta =
      const VerificationMeta('convertedRateAt');
  @override
  late final GeneratedColumn<DateTime> convertedRateAt =
      GeneratedColumn<DateTime>('converted_rate_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        tripId,
        amountMinor,
        currency,
        category,
        date,
        notes,
        createdAt,
        convertedAmountMinor,
        convertedCurrency,
        convertedRateAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'expenses';
  @override
  VerificationContext validateIntegrity(Insertable<ExpenseRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('trip_id')) {
      context.handle(_tripIdMeta,
          tripId.isAcceptableOrUnknown(data['trip_id']!, _tripIdMeta));
    } else if (isInserting) {
      context.missing(_tripIdMeta);
    }
    if (data.containsKey('amount_minor')) {
      context.handle(
          _amountMinorMeta,
          amountMinor.isAcceptableOrUnknown(
              data['amount_minor']!, _amountMinorMeta));
    } else if (isInserting) {
      context.missing(_amountMinorMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
          _dateMeta, date.isAcceptableOrUnknown(data['date']!, _dateMeta));
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('converted_amount_minor')) {
      context.handle(
          _convertedAmountMinorMeta,
          convertedAmountMinor.isAcceptableOrUnknown(
              data['converted_amount_minor']!, _convertedAmountMinorMeta));
    }
    if (data.containsKey('converted_currency')) {
      context.handle(
          _convertedCurrencyMeta,
          convertedCurrency.isAcceptableOrUnknown(
              data['converted_currency']!, _convertedCurrencyMeta));
    }
    if (data.containsKey('converted_rate_at')) {
      context.handle(
          _convertedRateAtMeta,
          convertedRateAt.isAcceptableOrUnknown(
              data['converted_rate_at']!, _convertedRateAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExpenseRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExpenseRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      tripId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}trip_id'])!,
      amountMinor: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}amount_minor'])!,
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}category'])!,
      date: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}date'])!,
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      convertedAmountMinor: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}converted_amount_minor']),
      convertedCurrency: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}converted_currency']),
      convertedRateAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}converted_rate_at']),
    );
  }

  @override
  $ExpensesTable createAlias(String alias) {
    return $ExpensesTable(attachedDatabase, alias);
  }
}

class ExpenseRow extends DataClass implements Insertable<ExpenseRow> {
  final String id;

  /// Expenses only exist within a trip — deleting the trip deletes them
  /// (CASCADE, unlike Places' SET NULL: a place outlives its trip as a
  /// wishlist entry, a spend record without its trip is meaningless).
  final String tripId;

  /// Minor units (agorot/cents) as an integer — never a float. 12.30 is
  /// 1230, so sums stay exact; binary floating point can't represent
  /// 0.1 and running totals would drift.
  final int amountMinor;

  /// ISO-4217, uppercase. v1 is single-currency per trip (SPEC §3.2.1 —
  /// no live conversion), but stored per row so a future multi-currency
  /// pass doesn't need a migration.
  final String currency;

  /// Index into ExpenseCategory enum.
  final int category;
  final DateTime date;
  final String notes;
  final DateTime createdAt;

  /// Conversion into the user's home currency, computed once when rates
  /// are available and then stored forever (M5.5b). All three are null
  /// together — an expense added offline simply stays unconverted until
  /// the next connection backfills it, which is why these are nullable
  /// rather than defaulted: null means "not yet", not "zero".
  ///
  /// Storing the converted figure (rather than converting on the fly)
  /// means the rate is the one that applied around the time of the
  /// spend, and the total keeps working with no network at all.
  final int? convertedAmountMinor;
  final String? convertedCurrency;

  /// When the rate used for [convertedAmountMinor] was fetched — shown
  /// in the UI so an approximate figure can be sanity-checked.
  final DateTime? convertedRateAt;
  const ExpenseRow(
      {required this.id,
      required this.tripId,
      required this.amountMinor,
      required this.currency,
      required this.category,
      required this.date,
      required this.notes,
      required this.createdAt,
      this.convertedAmountMinor,
      this.convertedCurrency,
      this.convertedRateAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['trip_id'] = Variable<String>(tripId);
    map['amount_minor'] = Variable<int>(amountMinor);
    map['currency'] = Variable<String>(currency);
    map['category'] = Variable<int>(category);
    map['date'] = Variable<DateTime>(date);
    map['notes'] = Variable<String>(notes);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || convertedAmountMinor != null) {
      map['converted_amount_minor'] = Variable<int>(convertedAmountMinor);
    }
    if (!nullToAbsent || convertedCurrency != null) {
      map['converted_currency'] = Variable<String>(convertedCurrency);
    }
    if (!nullToAbsent || convertedRateAt != null) {
      map['converted_rate_at'] = Variable<DateTime>(convertedRateAt);
    }
    return map;
  }

  ExpensesCompanion toCompanion(bool nullToAbsent) {
    return ExpensesCompanion(
      id: Value(id),
      tripId: Value(tripId),
      amountMinor: Value(amountMinor),
      currency: Value(currency),
      category: Value(category),
      date: Value(date),
      notes: Value(notes),
      createdAt: Value(createdAt),
      convertedAmountMinor: convertedAmountMinor == null && nullToAbsent
          ? const Value.absent()
          : Value(convertedAmountMinor),
      convertedCurrency: convertedCurrency == null && nullToAbsent
          ? const Value.absent()
          : Value(convertedCurrency),
      convertedRateAt: convertedRateAt == null && nullToAbsent
          ? const Value.absent()
          : Value(convertedRateAt),
    );
  }

  factory ExpenseRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExpenseRow(
      id: serializer.fromJson<String>(json['id']),
      tripId: serializer.fromJson<String>(json['tripId']),
      amountMinor: serializer.fromJson<int>(json['amountMinor']),
      currency: serializer.fromJson<String>(json['currency']),
      category: serializer.fromJson<int>(json['category']),
      date: serializer.fromJson<DateTime>(json['date']),
      notes: serializer.fromJson<String>(json['notes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      convertedAmountMinor:
          serializer.fromJson<int?>(json['convertedAmountMinor']),
      convertedCurrency:
          serializer.fromJson<String?>(json['convertedCurrency']),
      convertedRateAt: serializer.fromJson<DateTime?>(json['convertedRateAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tripId': serializer.toJson<String>(tripId),
      'amountMinor': serializer.toJson<int>(amountMinor),
      'currency': serializer.toJson<String>(currency),
      'category': serializer.toJson<int>(category),
      'date': serializer.toJson<DateTime>(date),
      'notes': serializer.toJson<String>(notes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'convertedAmountMinor': serializer.toJson<int?>(convertedAmountMinor),
      'convertedCurrency': serializer.toJson<String?>(convertedCurrency),
      'convertedRateAt': serializer.toJson<DateTime?>(convertedRateAt),
    };
  }

  ExpenseRow copyWith(
          {String? id,
          String? tripId,
          int? amountMinor,
          String? currency,
          int? category,
          DateTime? date,
          String? notes,
          DateTime? createdAt,
          Value<int?> convertedAmountMinor = const Value.absent(),
          Value<String?> convertedCurrency = const Value.absent(),
          Value<DateTime?> convertedRateAt = const Value.absent()}) =>
      ExpenseRow(
        id: id ?? this.id,
        tripId: tripId ?? this.tripId,
        amountMinor: amountMinor ?? this.amountMinor,
        currency: currency ?? this.currency,
        category: category ?? this.category,
        date: date ?? this.date,
        notes: notes ?? this.notes,
        createdAt: createdAt ?? this.createdAt,
        convertedAmountMinor: convertedAmountMinor.present
            ? convertedAmountMinor.value
            : this.convertedAmountMinor,
        convertedCurrency: convertedCurrency.present
            ? convertedCurrency.value
            : this.convertedCurrency,
        convertedRateAt: convertedRateAt.present
            ? convertedRateAt.value
            : this.convertedRateAt,
      );
  ExpenseRow copyWithCompanion(ExpensesCompanion data) {
    return ExpenseRow(
      id: data.id.present ? data.id.value : this.id,
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      amountMinor:
          data.amountMinor.present ? data.amountMinor.value : this.amountMinor,
      currency: data.currency.present ? data.currency.value : this.currency,
      category: data.category.present ? data.category.value : this.category,
      date: data.date.present ? data.date.value : this.date,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      convertedAmountMinor: data.convertedAmountMinor.present
          ? data.convertedAmountMinor.value
          : this.convertedAmountMinor,
      convertedCurrency: data.convertedCurrency.present
          ? data.convertedCurrency.value
          : this.convertedCurrency,
      convertedRateAt: data.convertedRateAt.present
          ? data.convertedRateAt.value
          : this.convertedRateAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExpenseRow(')
          ..write('id: $id, ')
          ..write('tripId: $tripId, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('currency: $currency, ')
          ..write('category: $category, ')
          ..write('date: $date, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('convertedAmountMinor: $convertedAmountMinor, ')
          ..write('convertedCurrency: $convertedCurrency, ')
          ..write('convertedRateAt: $convertedRateAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      tripId,
      amountMinor,
      currency,
      category,
      date,
      notes,
      createdAt,
      convertedAmountMinor,
      convertedCurrency,
      convertedRateAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExpenseRow &&
          other.id == this.id &&
          other.tripId == this.tripId &&
          other.amountMinor == this.amountMinor &&
          other.currency == this.currency &&
          other.category == this.category &&
          other.date == this.date &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt &&
          other.convertedAmountMinor == this.convertedAmountMinor &&
          other.convertedCurrency == this.convertedCurrency &&
          other.convertedRateAt == this.convertedRateAt);
}

class ExpensesCompanion extends UpdateCompanion<ExpenseRow> {
  final Value<String> id;
  final Value<String> tripId;
  final Value<int> amountMinor;
  final Value<String> currency;
  final Value<int> category;
  final Value<DateTime> date;
  final Value<String> notes;
  final Value<DateTime> createdAt;
  final Value<int?> convertedAmountMinor;
  final Value<String?> convertedCurrency;
  final Value<DateTime?> convertedRateAt;
  final Value<int> rowid;
  const ExpensesCompanion({
    this.id = const Value.absent(),
    this.tripId = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.currency = const Value.absent(),
    this.category = const Value.absent(),
    this.date = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.convertedAmountMinor = const Value.absent(),
    this.convertedCurrency = const Value.absent(),
    this.convertedRateAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExpensesCompanion.insert({
    required String id,
    required String tripId,
    required int amountMinor,
    required String currency,
    required int category,
    required DateTime date,
    this.notes = const Value.absent(),
    required DateTime createdAt,
    this.convertedAmountMinor = const Value.absent(),
    this.convertedCurrency = const Value.absent(),
    this.convertedRateAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        tripId = Value(tripId),
        amountMinor = Value(amountMinor),
        currency = Value(currency),
        category = Value(category),
        date = Value(date),
        createdAt = Value(createdAt);
  static Insertable<ExpenseRow> custom({
    Expression<String>? id,
    Expression<String>? tripId,
    Expression<int>? amountMinor,
    Expression<String>? currency,
    Expression<int>? category,
    Expression<DateTime>? date,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
    Expression<int>? convertedAmountMinor,
    Expression<String>? convertedCurrency,
    Expression<DateTime>? convertedRateAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tripId != null) 'trip_id': tripId,
      if (amountMinor != null) 'amount_minor': amountMinor,
      if (currency != null) 'currency': currency,
      if (category != null) 'category': category,
      if (date != null) 'date': date,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (convertedAmountMinor != null)
        'converted_amount_minor': convertedAmountMinor,
      if (convertedCurrency != null) 'converted_currency': convertedCurrency,
      if (convertedRateAt != null) 'converted_rate_at': convertedRateAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExpensesCompanion copyWith(
      {Value<String>? id,
      Value<String>? tripId,
      Value<int>? amountMinor,
      Value<String>? currency,
      Value<int>? category,
      Value<DateTime>? date,
      Value<String>? notes,
      Value<DateTime>? createdAt,
      Value<int?>? convertedAmountMinor,
      Value<String?>? convertedCurrency,
      Value<DateTime?>? convertedRateAt,
      Value<int>? rowid}) {
    return ExpensesCompanion(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      amountMinor: amountMinor ?? this.amountMinor,
      currency: currency ?? this.currency,
      category: category ?? this.category,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      convertedAmountMinor: convertedAmountMinor ?? this.convertedAmountMinor,
      convertedCurrency: convertedCurrency ?? this.convertedCurrency,
      convertedRateAt: convertedRateAt ?? this.convertedRateAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tripId.present) {
      map['trip_id'] = Variable<String>(tripId.value);
    }
    if (amountMinor.present) {
      map['amount_minor'] = Variable<int>(amountMinor.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (category.present) {
      map['category'] = Variable<int>(category.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (convertedAmountMinor.present) {
      map['converted_amount_minor'] = Variable<int>(convertedAmountMinor.value);
    }
    if (convertedCurrency.present) {
      map['converted_currency'] = Variable<String>(convertedCurrency.value);
    }
    if (convertedRateAt.present) {
      map['converted_rate_at'] = Variable<DateTime>(convertedRateAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExpensesCompanion(')
          ..write('id: $id, ')
          ..write('tripId: $tripId, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('currency: $currency, ')
          ..write('category: $category, ')
          ..write('date: $date, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('convertedAmountMinor: $convertedAmountMinor, ')
          ..write('convertedCurrency: $convertedCurrency, ')
          ..write('convertedRateAt: $convertedRateAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ItineraryItemsTable extends ItineraryItems
    with TableInfo<$ItineraryItemsTable, ItineraryItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ItineraryItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tripIdMeta = const VerificationMeta('tripId');
  @override
  late final GeneratedColumn<String> tripId = GeneratedColumn<String>(
      'trip_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES trips (id) ON DELETE CASCADE'));
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
      'date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _startMinutesMeta =
      const VerificationMeta('startMinutes');
  @override
  late final GeneratedColumn<int> startMinutes = GeneratedColumn<int>(
      'start_minutes', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 120),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _placeIdMeta =
      const VerificationMeta('placeId');
  @override
  late final GeneratedColumn<String> placeId = GeneratedColumn<String>(
      'place_id', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES places (id) ON DELETE SET NULL'));
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _orderIndexMeta =
      const VerificationMeta('orderIndex');
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
      'order_index', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        tripId,
        date,
        startMinutes,
        title,
        placeId,
        notes,
        orderIndex,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'itinerary_items';
  @override
  VerificationContext validateIntegrity(Insertable<ItineraryItemRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('trip_id')) {
      context.handle(_tripIdMeta,
          tripId.isAcceptableOrUnknown(data['trip_id']!, _tripIdMeta));
    } else if (isInserting) {
      context.missing(_tripIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
          _dateMeta, date.isAcceptableOrUnknown(data['date']!, _dateMeta));
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('start_minutes')) {
      context.handle(
          _startMinutesMeta,
          startMinutes.isAcceptableOrUnknown(
              data['start_minutes']!, _startMinutesMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('place_id')) {
      context.handle(_placeIdMeta,
          placeId.isAcceptableOrUnknown(data['place_id']!, _placeIdMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('order_index')) {
      context.handle(
          _orderIndexMeta,
          orderIndex.isAcceptableOrUnknown(
              data['order_index']!, _orderIndexMeta));
    } else if (isInserting) {
      context.missing(_orderIndexMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ItineraryItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ItineraryItemRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      tripId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}trip_id'])!,
      date: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}date'])!,
      startMinutes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}start_minutes']),
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      placeId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}place_id']),
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes'])!,
      orderIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}order_index'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $ItineraryItemsTable createAlias(String alias) {
    return $ItineraryItemsTable(attachedDatabase, alias);
  }
}

class ItineraryItemRow extends DataClass
    implements Insertable<ItineraryItemRow> {
  final String id;

  /// An itinerary only means anything inside its trip — CASCADE, same
  /// reasoning as Expenses.
  final String tripId;

  /// Date-only semantics (time lives in [startTime]) — matches how Trip
  /// dates are handled everywhere else.
  final DateTime date;

  /// Minutes from midnight, nullable — plenty of plans are "sometime on
  /// Tuesday". Stored as an int rather than a DateTime so it can't drift
  /// away from [date] or carry a bogus timezone.
  final int? startMinutes;
  final String title;

  /// Optional link to a saved place (M3). SET NULL, not CASCADE:
  /// deleting a wishlist place shouldn't silently delete the plan that
  /// referenced it.
  final String? placeId;
  final String notes;

  /// Position within its day. Only meaningful relative to siblings on the
  /// same date; gaps are fine and expected after deletes.
  final int orderIndex;
  final DateTime createdAt;
  const ItineraryItemRow(
      {required this.id,
      required this.tripId,
      required this.date,
      this.startMinutes,
      required this.title,
      this.placeId,
      required this.notes,
      required this.orderIndex,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['trip_id'] = Variable<String>(tripId);
    map['date'] = Variable<DateTime>(date);
    if (!nullToAbsent || startMinutes != null) {
      map['start_minutes'] = Variable<int>(startMinutes);
    }
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || placeId != null) {
      map['place_id'] = Variable<String>(placeId);
    }
    map['notes'] = Variable<String>(notes);
    map['order_index'] = Variable<int>(orderIndex);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ItineraryItemsCompanion toCompanion(bool nullToAbsent) {
    return ItineraryItemsCompanion(
      id: Value(id),
      tripId: Value(tripId),
      date: Value(date),
      startMinutes: startMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(startMinutes),
      title: Value(title),
      placeId: placeId == null && nullToAbsent
          ? const Value.absent()
          : Value(placeId),
      notes: Value(notes),
      orderIndex: Value(orderIndex),
      createdAt: Value(createdAt),
    );
  }

  factory ItineraryItemRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ItineraryItemRow(
      id: serializer.fromJson<String>(json['id']),
      tripId: serializer.fromJson<String>(json['tripId']),
      date: serializer.fromJson<DateTime>(json['date']),
      startMinutes: serializer.fromJson<int?>(json['startMinutes']),
      title: serializer.fromJson<String>(json['title']),
      placeId: serializer.fromJson<String?>(json['placeId']),
      notes: serializer.fromJson<String>(json['notes']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tripId': serializer.toJson<String>(tripId),
      'date': serializer.toJson<DateTime>(date),
      'startMinutes': serializer.toJson<int?>(startMinutes),
      'title': serializer.toJson<String>(title),
      'placeId': serializer.toJson<String?>(placeId),
      'notes': serializer.toJson<String>(notes),
      'orderIndex': serializer.toJson<int>(orderIndex),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ItineraryItemRow copyWith(
          {String? id,
          String? tripId,
          DateTime? date,
          Value<int?> startMinutes = const Value.absent(),
          String? title,
          Value<String?> placeId = const Value.absent(),
          String? notes,
          int? orderIndex,
          DateTime? createdAt}) =>
      ItineraryItemRow(
        id: id ?? this.id,
        tripId: tripId ?? this.tripId,
        date: date ?? this.date,
        startMinutes:
            startMinutes.present ? startMinutes.value : this.startMinutes,
        title: title ?? this.title,
        placeId: placeId.present ? placeId.value : this.placeId,
        notes: notes ?? this.notes,
        orderIndex: orderIndex ?? this.orderIndex,
        createdAt: createdAt ?? this.createdAt,
      );
  ItineraryItemRow copyWithCompanion(ItineraryItemsCompanion data) {
    return ItineraryItemRow(
      id: data.id.present ? data.id.value : this.id,
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      date: data.date.present ? data.date.value : this.date,
      startMinutes: data.startMinutes.present
          ? data.startMinutes.value
          : this.startMinutes,
      title: data.title.present ? data.title.value : this.title,
      placeId: data.placeId.present ? data.placeId.value : this.placeId,
      notes: data.notes.present ? data.notes.value : this.notes,
      orderIndex:
          data.orderIndex.present ? data.orderIndex.value : this.orderIndex,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ItineraryItemRow(')
          ..write('id: $id, ')
          ..write('tripId: $tripId, ')
          ..write('date: $date, ')
          ..write('startMinutes: $startMinutes, ')
          ..write('title: $title, ')
          ..write('placeId: $placeId, ')
          ..write('notes: $notes, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, tripId, date, startMinutes, title,
      placeId, notes, orderIndex, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ItineraryItemRow &&
          other.id == this.id &&
          other.tripId == this.tripId &&
          other.date == this.date &&
          other.startMinutes == this.startMinutes &&
          other.title == this.title &&
          other.placeId == this.placeId &&
          other.notes == this.notes &&
          other.orderIndex == this.orderIndex &&
          other.createdAt == this.createdAt);
}

class ItineraryItemsCompanion extends UpdateCompanion<ItineraryItemRow> {
  final Value<String> id;
  final Value<String> tripId;
  final Value<DateTime> date;
  final Value<int?> startMinutes;
  final Value<String> title;
  final Value<String?> placeId;
  final Value<String> notes;
  final Value<int> orderIndex;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ItineraryItemsCompanion({
    this.id = const Value.absent(),
    this.tripId = const Value.absent(),
    this.date = const Value.absent(),
    this.startMinutes = const Value.absent(),
    this.title = const Value.absent(),
    this.placeId = const Value.absent(),
    this.notes = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ItineraryItemsCompanion.insert({
    required String id,
    required String tripId,
    required DateTime date,
    this.startMinutes = const Value.absent(),
    required String title,
    this.placeId = const Value.absent(),
    this.notes = const Value.absent(),
    required int orderIndex,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        tripId = Value(tripId),
        date = Value(date),
        title = Value(title),
        orderIndex = Value(orderIndex),
        createdAt = Value(createdAt);
  static Insertable<ItineraryItemRow> custom({
    Expression<String>? id,
    Expression<String>? tripId,
    Expression<DateTime>? date,
    Expression<int>? startMinutes,
    Expression<String>? title,
    Expression<String>? placeId,
    Expression<String>? notes,
    Expression<int>? orderIndex,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tripId != null) 'trip_id': tripId,
      if (date != null) 'date': date,
      if (startMinutes != null) 'start_minutes': startMinutes,
      if (title != null) 'title': title,
      if (placeId != null) 'place_id': placeId,
      if (notes != null) 'notes': notes,
      if (orderIndex != null) 'order_index': orderIndex,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ItineraryItemsCompanion copyWith(
      {Value<String>? id,
      Value<String>? tripId,
      Value<DateTime>? date,
      Value<int?>? startMinutes,
      Value<String>? title,
      Value<String?>? placeId,
      Value<String>? notes,
      Value<int>? orderIndex,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return ItineraryItemsCompanion(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      date: date ?? this.date,
      startMinutes: startMinutes ?? this.startMinutes,
      title: title ?? this.title,
      placeId: placeId ?? this.placeId,
      notes: notes ?? this.notes,
      orderIndex: orderIndex ?? this.orderIndex,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tripId.present) {
      map['trip_id'] = Variable<String>(tripId.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (startMinutes.present) {
      map['start_minutes'] = Variable<int>(startMinutes.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (placeId.present) {
      map['place_id'] = Variable<String>(placeId.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ItineraryItemsCompanion(')
          ..write('id: $id, ')
          ..write('tripId: $tripId, ')
          ..write('date: $date, ')
          ..write('startMinutes: $startMinutes, ')
          ..write('title: $title, ')
          ..write('placeId: $placeId, ')
          ..write('notes: $notes, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $JournalEntriesTable extends JournalEntries
    with TableInfo<$JournalEntriesTable, JournalEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JournalEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tripIdMeta = const VerificationMeta('tripId');
  @override
  late final GeneratedColumn<String> tripId = GeneratedColumn<String>(
      'trip_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES trips (id) ON DELETE CASCADE'));
  static const VerificationMeta _summaryMeta =
      const VerificationMeta('summary');
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
      'summary', aliasedName, false,
      additionalChecks: GeneratedColumn.checkTextLength(
          minTextLength: 0, maxTextLength: 4000),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _loggedAtMeta =
      const VerificationMeta('loggedAt');
  @override
  late final GeneratedColumn<DateTime> loggedAt = GeneratedColumn<DateTime>(
      'logged_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _latMeta = const VerificationMeta('lat');
  @override
  late final GeneratedColumn<double> lat = GeneratedColumn<double>(
      'lat', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _lngMeta = const VerificationMeta('lng');
  @override
  late final GeneratedColumn<double> lng = GeneratedColumn<double>(
      'lng', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _placeNameMeta =
      const VerificationMeta('placeName');
  @override
  late final GeneratedColumn<String> placeName = GeneratedColumn<String>(
      'place_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _placeIdMeta =
      const VerificationMeta('placeId');
  @override
  late final GeneratedColumn<String> placeId = GeneratedColumn<String>(
      'place_id', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES places (id) ON DELETE SET NULL'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, tripId, summary, loggedAt, lat, lng, placeName, placeId, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'journal_entries';
  @override
  VerificationContext validateIntegrity(Insertable<JournalEntryRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('trip_id')) {
      context.handle(_tripIdMeta,
          tripId.isAcceptableOrUnknown(data['trip_id']!, _tripIdMeta));
    } else if (isInserting) {
      context.missing(_tripIdMeta);
    }
    if (data.containsKey('summary')) {
      context.handle(_summaryMeta,
          summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta));
    } else if (isInserting) {
      context.missing(_summaryMeta);
    }
    if (data.containsKey('logged_at')) {
      context.handle(_loggedAtMeta,
          loggedAt.isAcceptableOrUnknown(data['logged_at']!, _loggedAtMeta));
    } else if (isInserting) {
      context.missing(_loggedAtMeta);
    }
    if (data.containsKey('lat')) {
      context.handle(
          _latMeta, lat.isAcceptableOrUnknown(data['lat']!, _latMeta));
    }
    if (data.containsKey('lng')) {
      context.handle(
          _lngMeta, lng.isAcceptableOrUnknown(data['lng']!, _lngMeta));
    }
    if (data.containsKey('place_name')) {
      context.handle(_placeNameMeta,
          placeName.isAcceptableOrUnknown(data['place_name']!, _placeNameMeta));
    }
    if (data.containsKey('place_id')) {
      context.handle(_placeIdMeta,
          placeId.isAcceptableOrUnknown(data['place_id']!, _placeIdMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  JournalEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JournalEntryRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      tripId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}trip_id'])!,
      summary: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}summary'])!,
      loggedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}logged_at'])!,
      lat: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}lat']),
      lng: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}lng']),
      placeName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}place_name']),
      placeId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}place_id']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $JournalEntriesTable createAlias(String alias) {
    return $JournalEntriesTable(attachedDatabase, alias);
  }
}

class JournalEntryRow extends DataClass implements Insertable<JournalEntryRow> {
  final String id;
  final String tripId;

  /// min: 0, not 1 — entries auto-created by markPlaceVisited (a place
  /// marked visited outside the journal) start with an empty summary,
  /// shown as "Not written yet" until the user fills it in. The manual
  /// entry form enforces non-empty at the UI layer for user-typed entries.
  final String summary;

  /// User-editable log time — never `DateTime.now()`, defaults to
  /// `clockProvider` at creation (domain rule).
  final DateTime loggedAt;
  final double? lat;
  final double? lng;
  final String? placeName;

  /// Links this entry to the Place it corresponds to, if any — set when
  /// the entry's location was picked from (or created as) one of the
  /// trip's Places, or when the entry was auto-created because a Place
  /// was marked visited from the Places tab. SET NULL, not cascade:
  /// deleting the place must never delete the entry (entries are user
  /// content — text, photos — only ever removed by explicit user action).
  final String? placeId;

  /// Immutable audit stamp — never shown or edited.
  final DateTime createdAt;
  const JournalEntryRow(
      {required this.id,
      required this.tripId,
      required this.summary,
      required this.loggedAt,
      this.lat,
      this.lng,
      this.placeName,
      this.placeId,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['trip_id'] = Variable<String>(tripId);
    map['summary'] = Variable<String>(summary);
    map['logged_at'] = Variable<DateTime>(loggedAt);
    if (!nullToAbsent || lat != null) {
      map['lat'] = Variable<double>(lat);
    }
    if (!nullToAbsent || lng != null) {
      map['lng'] = Variable<double>(lng);
    }
    if (!nullToAbsent || placeName != null) {
      map['place_name'] = Variable<String>(placeName);
    }
    if (!nullToAbsent || placeId != null) {
      map['place_id'] = Variable<String>(placeId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  JournalEntriesCompanion toCompanion(bool nullToAbsent) {
    return JournalEntriesCompanion(
      id: Value(id),
      tripId: Value(tripId),
      summary: Value(summary),
      loggedAt: Value(loggedAt),
      lat: lat == null && nullToAbsent ? const Value.absent() : Value(lat),
      lng: lng == null && nullToAbsent ? const Value.absent() : Value(lng),
      placeName: placeName == null && nullToAbsent
          ? const Value.absent()
          : Value(placeName),
      placeId: placeId == null && nullToAbsent
          ? const Value.absent()
          : Value(placeId),
      createdAt: Value(createdAt),
    );
  }

  factory JournalEntryRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JournalEntryRow(
      id: serializer.fromJson<String>(json['id']),
      tripId: serializer.fromJson<String>(json['tripId']),
      summary: serializer.fromJson<String>(json['summary']),
      loggedAt: serializer.fromJson<DateTime>(json['loggedAt']),
      lat: serializer.fromJson<double?>(json['lat']),
      lng: serializer.fromJson<double?>(json['lng']),
      placeName: serializer.fromJson<String?>(json['placeName']),
      placeId: serializer.fromJson<String?>(json['placeId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tripId': serializer.toJson<String>(tripId),
      'summary': serializer.toJson<String>(summary),
      'loggedAt': serializer.toJson<DateTime>(loggedAt),
      'lat': serializer.toJson<double?>(lat),
      'lng': serializer.toJson<double?>(lng),
      'placeName': serializer.toJson<String?>(placeName),
      'placeId': serializer.toJson<String?>(placeId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  JournalEntryRow copyWith(
          {String? id,
          String? tripId,
          String? summary,
          DateTime? loggedAt,
          Value<double?> lat = const Value.absent(),
          Value<double?> lng = const Value.absent(),
          Value<String?> placeName = const Value.absent(),
          Value<String?> placeId = const Value.absent(),
          DateTime? createdAt}) =>
      JournalEntryRow(
        id: id ?? this.id,
        tripId: tripId ?? this.tripId,
        summary: summary ?? this.summary,
        loggedAt: loggedAt ?? this.loggedAt,
        lat: lat.present ? lat.value : this.lat,
        lng: lng.present ? lng.value : this.lng,
        placeName: placeName.present ? placeName.value : this.placeName,
        placeId: placeId.present ? placeId.value : this.placeId,
        createdAt: createdAt ?? this.createdAt,
      );
  JournalEntryRow copyWithCompanion(JournalEntriesCompanion data) {
    return JournalEntryRow(
      id: data.id.present ? data.id.value : this.id,
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      summary: data.summary.present ? data.summary.value : this.summary,
      loggedAt: data.loggedAt.present ? data.loggedAt.value : this.loggedAt,
      lat: data.lat.present ? data.lat.value : this.lat,
      lng: data.lng.present ? data.lng.value : this.lng,
      placeName: data.placeName.present ? data.placeName.value : this.placeName,
      placeId: data.placeId.present ? data.placeId.value : this.placeId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JournalEntryRow(')
          ..write('id: $id, ')
          ..write('tripId: $tripId, ')
          ..write('summary: $summary, ')
          ..write('loggedAt: $loggedAt, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('placeName: $placeName, ')
          ..write('placeId: $placeId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, tripId, summary, loggedAt, lat, lng, placeName, placeId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JournalEntryRow &&
          other.id == this.id &&
          other.tripId == this.tripId &&
          other.summary == this.summary &&
          other.loggedAt == this.loggedAt &&
          other.lat == this.lat &&
          other.lng == this.lng &&
          other.placeName == this.placeName &&
          other.placeId == this.placeId &&
          other.createdAt == this.createdAt);
}

class JournalEntriesCompanion extends UpdateCompanion<JournalEntryRow> {
  final Value<String> id;
  final Value<String> tripId;
  final Value<String> summary;
  final Value<DateTime> loggedAt;
  final Value<double?> lat;
  final Value<double?> lng;
  final Value<String?> placeName;
  final Value<String?> placeId;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const JournalEntriesCompanion({
    this.id = const Value.absent(),
    this.tripId = const Value.absent(),
    this.summary = const Value.absent(),
    this.loggedAt = const Value.absent(),
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
    this.placeName = const Value.absent(),
    this.placeId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  JournalEntriesCompanion.insert({
    required String id,
    required String tripId,
    required String summary,
    required DateTime loggedAt,
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
    this.placeName = const Value.absent(),
    this.placeId = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        tripId = Value(tripId),
        summary = Value(summary),
        loggedAt = Value(loggedAt),
        createdAt = Value(createdAt);
  static Insertable<JournalEntryRow> custom({
    Expression<String>? id,
    Expression<String>? tripId,
    Expression<String>? summary,
    Expression<DateTime>? loggedAt,
    Expression<double>? lat,
    Expression<double>? lng,
    Expression<String>? placeName,
    Expression<String>? placeId,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tripId != null) 'trip_id': tripId,
      if (summary != null) 'summary': summary,
      if (loggedAt != null) 'logged_at': loggedAt,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (placeName != null) 'place_name': placeName,
      if (placeId != null) 'place_id': placeId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  JournalEntriesCompanion copyWith(
      {Value<String>? id,
      Value<String>? tripId,
      Value<String>? summary,
      Value<DateTime>? loggedAt,
      Value<double?>? lat,
      Value<double?>? lng,
      Value<String?>? placeName,
      Value<String?>? placeId,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return JournalEntriesCompanion(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      summary: summary ?? this.summary,
      loggedAt: loggedAt ?? this.loggedAt,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      placeName: placeName ?? this.placeName,
      placeId: placeId ?? this.placeId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tripId.present) {
      map['trip_id'] = Variable<String>(tripId.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (loggedAt.present) {
      map['logged_at'] = Variable<DateTime>(loggedAt.value);
    }
    if (lat.present) {
      map['lat'] = Variable<double>(lat.value);
    }
    if (lng.present) {
      map['lng'] = Variable<double>(lng.value);
    }
    if (placeName.present) {
      map['place_name'] = Variable<String>(placeName.value);
    }
    if (placeId.present) {
      map['place_id'] = Variable<String>(placeId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('JournalEntriesCompanion(')
          ..write('id: $id, ')
          ..write('tripId: $tripId, ')
          ..write('summary: $summary, ')
          ..write('loggedAt: $loggedAt, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('placeName: $placeName, ')
          ..write('placeId: $placeId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $JournalPhotosTable extends JournalPhotos
    with TableInfo<$JournalPhotosTable, JournalPhotoRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JournalPhotosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _entryIdMeta =
      const VerificationMeta('entryId');
  @override
  late final GeneratedColumn<String> entryId = GeneratedColumn<String>(
      'entry_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES journal_entries (id) ON DELETE CASCADE'));
  static const VerificationMeta _filePathMeta =
      const VerificationMeta('filePath');
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
      'file_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _orderIndexMeta =
      const VerificationMeta('orderIndex');
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
      'order_index', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, entryId, filePath, orderIndex];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'journal_photos';
  @override
  VerificationContext validateIntegrity(Insertable<JournalPhotoRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('entry_id')) {
      context.handle(_entryIdMeta,
          entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta));
    } else if (isInserting) {
      context.missing(_entryIdMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(_filePathMeta,
          filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta));
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('order_index')) {
      context.handle(
          _orderIndexMeta,
          orderIndex.isAcceptableOrUnknown(
              data['order_index']!, _orderIndexMeta));
    } else if (isInserting) {
      context.missing(_orderIndexMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  JournalPhotoRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JournalPhotoRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      entryId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entry_id'])!,
      filePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_path'])!,
      orderIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}order_index'])!,
    );
  }

  @override
  $JournalPhotosTable createAlias(String alias) {
    return $JournalPhotosTable(attachedDatabase, alias);
  }
}

class JournalPhotoRow extends DataClass implements Insertable<JournalPhotoRow> {
  final String id;
  final String entryId;
  final String filePath;
  final int orderIndex;
  const JournalPhotoRow(
      {required this.id,
      required this.entryId,
      required this.filePath,
      required this.orderIndex});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['entry_id'] = Variable<String>(entryId);
    map['file_path'] = Variable<String>(filePath);
    map['order_index'] = Variable<int>(orderIndex);
    return map;
  }

  JournalPhotosCompanion toCompanion(bool nullToAbsent) {
    return JournalPhotosCompanion(
      id: Value(id),
      entryId: Value(entryId),
      filePath: Value(filePath),
      orderIndex: Value(orderIndex),
    );
  }

  factory JournalPhotoRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JournalPhotoRow(
      id: serializer.fromJson<String>(json['id']),
      entryId: serializer.fromJson<String>(json['entryId']),
      filePath: serializer.fromJson<String>(json['filePath']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'entryId': serializer.toJson<String>(entryId),
      'filePath': serializer.toJson<String>(filePath),
      'orderIndex': serializer.toJson<int>(orderIndex),
    };
  }

  JournalPhotoRow copyWith(
          {String? id, String? entryId, String? filePath, int? orderIndex}) =>
      JournalPhotoRow(
        id: id ?? this.id,
        entryId: entryId ?? this.entryId,
        filePath: filePath ?? this.filePath,
        orderIndex: orderIndex ?? this.orderIndex,
      );
  JournalPhotoRow copyWithCompanion(JournalPhotosCompanion data) {
    return JournalPhotoRow(
      id: data.id.present ? data.id.value : this.id,
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      orderIndex:
          data.orderIndex.present ? data.orderIndex.value : this.orderIndex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JournalPhotoRow(')
          ..write('id: $id, ')
          ..write('entryId: $entryId, ')
          ..write('filePath: $filePath, ')
          ..write('orderIndex: $orderIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, entryId, filePath, orderIndex);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JournalPhotoRow &&
          other.id == this.id &&
          other.entryId == this.entryId &&
          other.filePath == this.filePath &&
          other.orderIndex == this.orderIndex);
}

class JournalPhotosCompanion extends UpdateCompanion<JournalPhotoRow> {
  final Value<String> id;
  final Value<String> entryId;
  final Value<String> filePath;
  final Value<int> orderIndex;
  final Value<int> rowid;
  const JournalPhotosCompanion({
    this.id = const Value.absent(),
    this.entryId = const Value.absent(),
    this.filePath = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  JournalPhotosCompanion.insert({
    required String id,
    required String entryId,
    required String filePath,
    required int orderIndex,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        entryId = Value(entryId),
        filePath = Value(filePath),
        orderIndex = Value(orderIndex);
  static Insertable<JournalPhotoRow> custom({
    Expression<String>? id,
    Expression<String>? entryId,
    Expression<String>? filePath,
    Expression<int>? orderIndex,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entryId != null) 'entry_id': entryId,
      if (filePath != null) 'file_path': filePath,
      if (orderIndex != null) 'order_index': orderIndex,
      if (rowid != null) 'rowid': rowid,
    });
  }

  JournalPhotosCompanion copyWith(
      {Value<String>? id,
      Value<String>? entryId,
      Value<String>? filePath,
      Value<int>? orderIndex,
      Value<int>? rowid}) {
    return JournalPhotosCompanion(
      id: id ?? this.id,
      entryId: entryId ?? this.entryId,
      filePath: filePath ?? this.filePath,
      orderIndex: orderIndex ?? this.orderIndex,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (entryId.present) {
      map['entry_id'] = Variable<String>(entryId.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('JournalPhotosCompanion(')
          ..write('id: $id, ')
          ..write('entryId: $entryId, ')
          ..write('filePath: $filePath, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TripsTable trips = $TripsTable(this);
  late final $TripDestinationsTable tripDestinations =
      $TripDestinationsTable(this);
  late final $DocumentsTable documents = $DocumentsTable(this);
  late final $TripDocumentsTable tripDocuments = $TripDocumentsTable(this);
  late final $PlacesTable places = $PlacesTable(this);
  late final $ExpensesTable expenses = $ExpensesTable(this);
  late final $ItineraryItemsTable itineraryItems = $ItineraryItemsTable(this);
  late final $JournalEntriesTable journalEntries = $JournalEntriesTable(this);
  late final $JournalPhotosTable journalPhotos = $JournalPhotosTable(this);
  late final TripsDao tripsDao = TripsDao(this as AppDatabase);
  late final DocumentsDao documentsDao = DocumentsDao(this as AppDatabase);
  late final PlacesDao placesDao = PlacesDao(this as AppDatabase);
  late final ExpensesDao expensesDao = ExpensesDao(this as AppDatabase);
  late final JournalDao journalDao = JournalDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        trips,
        tripDestinations,
        documents,
        tripDocuments,
        places,
        expenses,
        itineraryItems,
        journalEntries,
        journalPhotos
      ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules(
        [
          WritePropagation(
            on: TableUpdateQuery.onTableName('trips',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('trip_destinations', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('trips',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('trip_documents', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('documents',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('trip_documents', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('trips',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('places', kind: UpdateKind.update),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('trips',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('expenses', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('trips',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('itinerary_items', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('places',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('itinerary_items', kind: UpdateKind.update),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('trips',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('journal_entries', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('places',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('journal_entries', kind: UpdateKind.update),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('journal_entries',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('journal_photos', kind: UpdateKind.delete),
            ],
          ),
        ],
      );
}

typedef $$TripsTableCreateCompanionBuilder = TripsCompanion Function({
  required String id,
  required String name,
  Value<DateTime?> startDate,
  Value<DateTime?> endDate,
  Value<int> colorTag,
  Value<bool> archived,
  Value<bool> completionPromptShown,
  Value<String?> coverPhotoPath,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$TripsTableUpdateCompanionBuilder = TripsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<DateTime?> startDate,
  Value<DateTime?> endDate,
  Value<int> colorTag,
  Value<bool> archived,
  Value<bool> completionPromptShown,
  Value<String?> coverPhotoPath,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$TripsTableReferences
    extends BaseReferences<_$AppDatabase, $TripsTable, TripRow> {
  $$TripsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TripDestinationsTable, List<TripDestinationRow>>
      _tripDestinationsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.tripDestinations,
              aliasName: 'trips__id__trip_destinations__trip_id');

  $$TripDestinationsTableProcessedTableManager get tripDestinationsRefs {
    final manager =
        $$TripDestinationsTableTableManager($_db, $_db.tripDestinations)
            .filter((f) => f.tripId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_tripDestinationsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$TripDocumentsTable, List<TripDocumentRow>>
      _tripDocumentsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.tripDocuments,
              aliasName: 'trips__id__trip_documents__trip_id');

  $$TripDocumentsTableProcessedTableManager get tripDocumentsRefs {
    final manager = $$TripDocumentsTableTableManager($_db, $_db.tripDocuments)
        .filter((f) => f.tripId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_tripDocumentsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$PlacesTable, List<PlaceRow>> _placesRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.places,
          aliasName: 'trips__id__places__trip_id');

  $$PlacesTableProcessedTableManager get placesRefs {
    final manager = $$PlacesTableTableManager($_db, $_db.places)
        .filter((f) => f.tripId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_placesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$ExpensesTable, List<ExpenseRow>>
      _expensesRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.expenses,
              aliasName: 'trips__id__expenses__trip_id');

  $$ExpensesTableProcessedTableManager get expensesRefs {
    final manager = $$ExpensesTableTableManager($_db, $_db.expenses)
        .filter((f) => f.tripId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_expensesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$ItineraryItemsTable, List<ItineraryItemRow>>
      _itineraryItemsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.itineraryItems,
              aliasName: 'trips__id__itinerary_items__trip_id');

  $$ItineraryItemsTableProcessedTableManager get itineraryItemsRefs {
    final manager = $$ItineraryItemsTableTableManager($_db, $_db.itineraryItems)
        .filter((f) => f.tripId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_itineraryItemsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$JournalEntriesTable, List<JournalEntryRow>>
      _journalEntriesRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.journalEntries,
              aliasName: 'trips__id__journal_entries__trip_id');

  $$JournalEntriesTableProcessedTableManager get journalEntriesRefs {
    final manager = $$JournalEntriesTableTableManager($_db, $_db.journalEntries)
        .filter((f) => f.tripId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_journalEntriesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$TripsTableFilterComposer extends Composer<_$AppDatabase, $TripsTable> {
  $$TripsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startDate => $composableBuilder(
      column: $table.startDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get endDate => $composableBuilder(
      column: $table.endDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get colorTag => $composableBuilder(
      column: $table.colorTag, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get archived => $composableBuilder(
      column: $table.archived, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get completionPromptShown => $composableBuilder(
      column: $table.completionPromptShown,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get coverPhotoPath => $composableBuilder(
      column: $table.coverPhotoPath,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  Expression<bool> tripDestinationsRefs(
      Expression<bool> Function($$TripDestinationsTableFilterComposer f) f) {
    final $$TripDestinationsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.tripDestinations,
        getReferencedColumn: (t) => t.tripId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TripDestinationsTableFilterComposer(
              $db: $db,
              $table: $db.tripDestinations,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> tripDocumentsRefs(
      Expression<bool> Function($$TripDocumentsTableFilterComposer f) f) {
    final $$TripDocumentsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.tripDocuments,
        getReferencedColumn: (t) => t.tripId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TripDocumentsTableFilterComposer(
              $db: $db,
              $table: $db.tripDocuments,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> placesRefs(
      Expression<bool> Function($$PlacesTableFilterComposer f) f) {
    final $$PlacesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.places,
        getReferencedColumn: (t) => t.tripId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlacesTableFilterComposer(
              $db: $db,
              $table: $db.places,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> expensesRefs(
      Expression<bool> Function($$ExpensesTableFilterComposer f) f) {
    final $$ExpensesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.expenses,
        getReferencedColumn: (t) => t.tripId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ExpensesTableFilterComposer(
              $db: $db,
              $table: $db.expenses,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> itineraryItemsRefs(
      Expression<bool> Function($$ItineraryItemsTableFilterComposer f) f) {
    final $$ItineraryItemsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.itineraryItems,
        getReferencedColumn: (t) => t.tripId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ItineraryItemsTableFilterComposer(
              $db: $db,
              $table: $db.itineraryItems,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> journalEntriesRefs(
      Expression<bool> Function($$JournalEntriesTableFilterComposer f) f) {
    final $$JournalEntriesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.journalEntries,
        getReferencedColumn: (t) => t.tripId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$JournalEntriesTableFilterComposer(
              $db: $db,
              $table: $db.journalEntries,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$TripsTableOrderingComposer
    extends Composer<_$AppDatabase, $TripsTable> {
  $$TripsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
      column: $table.startDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get endDate => $composableBuilder(
      column: $table.endDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get colorTag => $composableBuilder(
      column: $table.colorTag, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get archived => $composableBuilder(
      column: $table.archived, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get completionPromptShown => $composableBuilder(
      column: $table.completionPromptShown,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get coverPhotoPath => $composableBuilder(
      column: $table.coverPhotoPath,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$TripsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TripsTable> {
  $$TripsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<DateTime> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<int> get colorTag =>
      $composableBuilder(column: $table.colorTag, builder: (column) => column);

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  GeneratedColumn<bool> get completionPromptShown => $composableBuilder(
      column: $table.completionPromptShown, builder: (column) => column);

  GeneratedColumn<String> get coverPhotoPath => $composableBuilder(
      column: $table.coverPhotoPath, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> tripDestinationsRefs<T extends Object>(
      Expression<T> Function($$TripDestinationsTableAnnotationComposer a) f) {
    final $$TripDestinationsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.tripDestinations,
        getReferencedColumn: (t) => t.tripId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TripDestinationsTableAnnotationComposer(
              $db: $db,
              $table: $db.tripDestinations,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> tripDocumentsRefs<T extends Object>(
      Expression<T> Function($$TripDocumentsTableAnnotationComposer a) f) {
    final $$TripDocumentsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.tripDocuments,
        getReferencedColumn: (t) => t.tripId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TripDocumentsTableAnnotationComposer(
              $db: $db,
              $table: $db.tripDocuments,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> placesRefs<T extends Object>(
      Expression<T> Function($$PlacesTableAnnotationComposer a) f) {
    final $$PlacesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.places,
        getReferencedColumn: (t) => t.tripId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlacesTableAnnotationComposer(
              $db: $db,
              $table: $db.places,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> expensesRefs<T extends Object>(
      Expression<T> Function($$ExpensesTableAnnotationComposer a) f) {
    final $$ExpensesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.expenses,
        getReferencedColumn: (t) => t.tripId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ExpensesTableAnnotationComposer(
              $db: $db,
              $table: $db.expenses,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> itineraryItemsRefs<T extends Object>(
      Expression<T> Function($$ItineraryItemsTableAnnotationComposer a) f) {
    final $$ItineraryItemsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.itineraryItems,
        getReferencedColumn: (t) => t.tripId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ItineraryItemsTableAnnotationComposer(
              $db: $db,
              $table: $db.itineraryItems,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> journalEntriesRefs<T extends Object>(
      Expression<T> Function($$JournalEntriesTableAnnotationComposer a) f) {
    final $$JournalEntriesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.journalEntries,
        getReferencedColumn: (t) => t.tripId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$JournalEntriesTableAnnotationComposer(
              $db: $db,
              $table: $db.journalEntries,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$TripsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TripsTable,
    TripRow,
    $$TripsTableFilterComposer,
    $$TripsTableOrderingComposer,
    $$TripsTableAnnotationComposer,
    $$TripsTableCreateCompanionBuilder,
    $$TripsTableUpdateCompanionBuilder,
    (TripRow, $$TripsTableReferences),
    TripRow,
    PrefetchHooks Function(
        {bool tripDestinationsRefs,
        bool tripDocumentsRefs,
        bool placesRefs,
        bool expensesRefs,
        bool itineraryItemsRefs,
        bool journalEntriesRefs})> {
  $$TripsTableTableManager(_$AppDatabase db, $TripsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TripsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TripsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TripsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<DateTime?> startDate = const Value.absent(),
            Value<DateTime?> endDate = const Value.absent(),
            Value<int> colorTag = const Value.absent(),
            Value<bool> archived = const Value.absent(),
            Value<bool> completionPromptShown = const Value.absent(),
            Value<String?> coverPhotoPath = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TripsCompanion(
            id: id,
            name: name,
            startDate: startDate,
            endDate: endDate,
            colorTag: colorTag,
            archived: archived,
            completionPromptShown: completionPromptShown,
            coverPhotoPath: coverPhotoPath,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            Value<DateTime?> startDate = const Value.absent(),
            Value<DateTime?> endDate = const Value.absent(),
            Value<int> colorTag = const Value.absent(),
            Value<bool> archived = const Value.absent(),
            Value<bool> completionPromptShown = const Value.absent(),
            Value<String?> coverPhotoPath = const Value.absent(),
            required DateTime createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              TripsCompanion.insert(
            id: id,
            name: name,
            startDate: startDate,
            endDate: endDate,
            colorTag: colorTag,
            archived: archived,
            completionPromptShown: completionPromptShown,
            coverPhotoPath: coverPhotoPath,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$TripsTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: (
              {tripDestinationsRefs = false,
              tripDocumentsRefs = false,
              placesRefs = false,
              expensesRefs = false,
              itineraryItemsRefs = false,
              journalEntriesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (tripDestinationsRefs) db.tripDestinations,
                if (tripDocumentsRefs) db.tripDocuments,
                if (placesRefs) db.places,
                if (expensesRefs) db.expenses,
                if (itineraryItemsRefs) db.itineraryItems,
                if (journalEntriesRefs) db.journalEntries
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (tripDestinationsRefs)
                    await $_getPrefetchedData<TripRow, $TripsTable,
                            TripDestinationRow>(
                        currentTable: table,
                        referencedTable: $$TripsTableReferences
                            ._tripDestinationsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$TripsTableReferences(db, table, p0)
                                .tripDestinationsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.tripId == item.id),
                        typedResults: items),
                  if (tripDocumentsRefs)
                    await $_getPrefetchedData<TripRow, $TripsTable,
                            TripDocumentRow>(
                        currentTable: table,
                        referencedTable:
                            $$TripsTableReferences._tripDocumentsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$TripsTableReferences(db, table, p0)
                                .tripDocumentsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.tripId == item.id),
                        typedResults: items),
                  if (placesRefs)
                    await $_getPrefetchedData<TripRow, $TripsTable, PlaceRow>(
                        currentTable: table,
                        referencedTable:
                            $$TripsTableReferences._placesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$TripsTableReferences(db, table, p0).placesRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.tripId == item.id),
                        typedResults: items),
                  if (expensesRefs)
                    await $_getPrefetchedData<TripRow, $TripsTable, ExpenseRow>(
                        currentTable: table,
                        referencedTable:
                            $$TripsTableReferences._expensesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$TripsTableReferences(db, table, p0).expensesRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.tripId == item.id),
                        typedResults: items),
                  if (itineraryItemsRefs)
                    await $_getPrefetchedData<TripRow, $TripsTable,
                            ItineraryItemRow>(
                        currentTable: table,
                        referencedTable:
                            $$TripsTableReferences._itineraryItemsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$TripsTableReferences(db, table, p0)
                                .itineraryItemsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.tripId == item.id),
                        typedResults: items),
                  if (journalEntriesRefs)
                    await $_getPrefetchedData<TripRow, $TripsTable,
                            JournalEntryRow>(
                        currentTable: table,
                        referencedTable:
                            $$TripsTableReferences._journalEntriesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$TripsTableReferences(db, table, p0)
                                .journalEntriesRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.tripId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$TripsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TripsTable,
    TripRow,
    $$TripsTableFilterComposer,
    $$TripsTableOrderingComposer,
    $$TripsTableAnnotationComposer,
    $$TripsTableCreateCompanionBuilder,
    $$TripsTableUpdateCompanionBuilder,
    (TripRow, $$TripsTableReferences),
    TripRow,
    PrefetchHooks Function(
        {bool tripDestinationsRefs,
        bool tripDocumentsRefs,
        bool placesRefs,
        bool expensesRefs,
        bool itineraryItemsRefs,
        bool journalEntriesRefs})>;
typedef $$TripDestinationsTableCreateCompanionBuilder
    = TripDestinationsCompanion Function({
  required String id,
  required String tripId,
  required String name,
  required int orderIndex,
  Value<int> rowid,
});
typedef $$TripDestinationsTableUpdateCompanionBuilder
    = TripDestinationsCompanion Function({
  Value<String> id,
  Value<String> tripId,
  Value<String> name,
  Value<int> orderIndex,
  Value<int> rowid,
});

final class $$TripDestinationsTableReferences extends BaseReferences<
    _$AppDatabase, $TripDestinationsTable, TripDestinationRow> {
  $$TripDestinationsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $TripsTable _tripIdTable(_$AppDatabase db) =>
      db.trips.createAlias('trip_destinations__trip_id__trips__id');

  $$TripsTableProcessedTableManager get tripId {
    final $_column = $_itemColumn<String>('trip_id')!;

    final manager = $$TripsTableTableManager($_db, $_db.trips)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tripIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$TripDestinationsTableFilterComposer
    extends Composer<_$AppDatabase, $TripDestinationsTable> {
  $$TripDestinationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get orderIndex => $composableBuilder(
      column: $table.orderIndex, builder: (column) => ColumnFilters(column));

  $$TripsTableFilterComposer get tripId {
    final $$TripsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.tripId,
        referencedTable: $db.trips,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TripsTableFilterComposer(
              $db: $db,
              $table: $db.trips,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TripDestinationsTableOrderingComposer
    extends Composer<_$AppDatabase, $TripDestinationsTable> {
  $$TripDestinationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get orderIndex => $composableBuilder(
      column: $table.orderIndex, builder: (column) => ColumnOrderings(column));

  $$TripsTableOrderingComposer get tripId {
    final $$TripsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.tripId,
        referencedTable: $db.trips,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TripsTableOrderingComposer(
              $db: $db,
              $table: $db.trips,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TripDestinationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TripDestinationsTable> {
  $$TripDestinationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get orderIndex => $composableBuilder(
      column: $table.orderIndex, builder: (column) => column);

  $$TripsTableAnnotationComposer get tripId {
    final $$TripsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.tripId,
        referencedTable: $db.trips,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TripsTableAnnotationComposer(
              $db: $db,
              $table: $db.trips,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TripDestinationsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TripDestinationsTable,
    TripDestinationRow,
    $$TripDestinationsTableFilterComposer,
    $$TripDestinationsTableOrderingComposer,
    $$TripDestinationsTableAnnotationComposer,
    $$TripDestinationsTableCreateCompanionBuilder,
    $$TripDestinationsTableUpdateCompanionBuilder,
    (TripDestinationRow, $$TripDestinationsTableReferences),
    TripDestinationRow,
    PrefetchHooks Function({bool tripId})> {
  $$TripDestinationsTableTableManager(
      _$AppDatabase db, $TripDestinationsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TripDestinationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TripDestinationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TripDestinationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> tripId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<int> orderIndex = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TripDestinationsCompanion(
            id: id,
            tripId: tripId,
            name: name,
            orderIndex: orderIndex,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String tripId,
            required String name,
            required int orderIndex,
            Value<int> rowid = const Value.absent(),
          }) =>
              TripDestinationsCompanion.insert(
            id: id,
            tripId: tripId,
            name: name,
            orderIndex: orderIndex,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$TripDestinationsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({tripId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (tripId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.tripId,
                    referencedTable:
                        $$TripDestinationsTableReferences._tripIdTable(db),
                    referencedColumn:
                        $$TripDestinationsTableReferences._tripIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$TripDestinationsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TripDestinationsTable,
    TripDestinationRow,
    $$TripDestinationsTableFilterComposer,
    $$TripDestinationsTableOrderingComposer,
    $$TripDestinationsTableAnnotationComposer,
    $$TripDestinationsTableCreateCompanionBuilder,
    $$TripDestinationsTableUpdateCompanionBuilder,
    (TripDestinationRow, $$TripDestinationsTableReferences),
    TripDestinationRow,
    PrefetchHooks Function({bool tripId})>;
typedef $$DocumentsTableCreateCompanionBuilder = DocumentsCompanion Function({
  required String id,
  required String title,
  required int category,
  Value<String?> filePath,
  Value<String?> mimeType,
  Value<DateTime?> expiryDate,
  Value<bool> isGlobal,
  Value<bool> isPinned,
  Value<String> detailsJson,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$DocumentsTableUpdateCompanionBuilder = DocumentsCompanion Function({
  Value<String> id,
  Value<String> title,
  Value<int> category,
  Value<String?> filePath,
  Value<String?> mimeType,
  Value<DateTime?> expiryDate,
  Value<bool> isGlobal,
  Value<bool> isPinned,
  Value<String> detailsJson,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$DocumentsTableReferences
    extends BaseReferences<_$AppDatabase, $DocumentsTable, DocumentRow> {
  $$DocumentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TripDocumentsTable, List<TripDocumentRow>>
      _tripDocumentsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.tripDocuments,
              aliasName: 'documents__id__trip_documents__document_id');

  $$TripDocumentsTableProcessedTableManager get tripDocumentsRefs {
    final manager = $$TripDocumentsTableTableManager($_db, $_db.tripDocuments)
        .filter((f) => f.documentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_tripDocumentsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$DocumentsTableFilterComposer
    extends Composer<_$AppDatabase, $DocumentsTable> {
  $$DocumentsTableFilterComposer({
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

  ColumnFilters<int> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mimeType => $composableBuilder(
      column: $table.mimeType, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get expiryDate => $composableBuilder(
      column: $table.expiryDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isGlobal => $composableBuilder(
      column: $table.isGlobal, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isPinned => $composableBuilder(
      column: $table.isPinned, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get detailsJson => $composableBuilder(
      column: $table.detailsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  Expression<bool> tripDocumentsRefs(
      Expression<bool> Function($$TripDocumentsTableFilterComposer f) f) {
    final $$TripDocumentsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.tripDocuments,
        getReferencedColumn: (t) => t.documentId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TripDocumentsTableFilterComposer(
              $db: $db,
              $table: $db.tripDocuments,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$DocumentsTableOrderingComposer
    extends Composer<_$AppDatabase, $DocumentsTable> {
  $$DocumentsTableOrderingComposer({
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

  ColumnOrderings<int> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mimeType => $composableBuilder(
      column: $table.mimeType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get expiryDate => $composableBuilder(
      column: $table.expiryDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isGlobal => $composableBuilder(
      column: $table.isGlobal, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isPinned => $composableBuilder(
      column: $table.isPinned, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get detailsJson => $composableBuilder(
      column: $table.detailsJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$DocumentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DocumentsTable> {
  $$DocumentsTableAnnotationComposer({
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

  GeneratedColumn<int> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<DateTime> get expiryDate => $composableBuilder(
      column: $table.expiryDate, builder: (column) => column);

  GeneratedColumn<bool> get isGlobal =>
      $composableBuilder(column: $table.isGlobal, builder: (column) => column);

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<String> get detailsJson => $composableBuilder(
      column: $table.detailsJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> tripDocumentsRefs<T extends Object>(
      Expression<T> Function($$TripDocumentsTableAnnotationComposer a) f) {
    final $$TripDocumentsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.tripDocuments,
        getReferencedColumn: (t) => t.documentId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TripDocumentsTableAnnotationComposer(
              $db: $db,
              $table: $db.tripDocuments,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$DocumentsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DocumentsTable,
    DocumentRow,
    $$DocumentsTableFilterComposer,
    $$DocumentsTableOrderingComposer,
    $$DocumentsTableAnnotationComposer,
    $$DocumentsTableCreateCompanionBuilder,
    $$DocumentsTableUpdateCompanionBuilder,
    (DocumentRow, $$DocumentsTableReferences),
    DocumentRow,
    PrefetchHooks Function({bool tripDocumentsRefs})> {
  $$DocumentsTableTableManager(_$AppDatabase db, $DocumentsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DocumentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DocumentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DocumentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<int> category = const Value.absent(),
            Value<String?> filePath = const Value.absent(),
            Value<String?> mimeType = const Value.absent(),
            Value<DateTime?> expiryDate = const Value.absent(),
            Value<bool> isGlobal = const Value.absent(),
            Value<bool> isPinned = const Value.absent(),
            Value<String> detailsJson = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DocumentsCompanion(
            id: id,
            title: title,
            category: category,
            filePath: filePath,
            mimeType: mimeType,
            expiryDate: expiryDate,
            isGlobal: isGlobal,
            isPinned: isPinned,
            detailsJson: detailsJson,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String title,
            required int category,
            Value<String?> filePath = const Value.absent(),
            Value<String?> mimeType = const Value.absent(),
            Value<DateTime?> expiryDate = const Value.absent(),
            Value<bool> isGlobal = const Value.absent(),
            Value<bool> isPinned = const Value.absent(),
            Value<String> detailsJson = const Value.absent(),
            required DateTime createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              DocumentsCompanion.insert(
            id: id,
            title: title,
            category: category,
            filePath: filePath,
            mimeType: mimeType,
            expiryDate: expiryDate,
            isGlobal: isGlobal,
            isPinned: isPinned,
            detailsJson: detailsJson,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$DocumentsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({tripDocumentsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (tripDocumentsRefs) db.tripDocuments
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (tripDocumentsRefs)
                    await $_getPrefetchedData<DocumentRow, $DocumentsTable,
                            TripDocumentRow>(
                        currentTable: table,
                        referencedTable: $$DocumentsTableReferences
                            ._tripDocumentsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$DocumentsTableReferences(db, table, p0)
                                .tripDocumentsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.documentId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$DocumentsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DocumentsTable,
    DocumentRow,
    $$DocumentsTableFilterComposer,
    $$DocumentsTableOrderingComposer,
    $$DocumentsTableAnnotationComposer,
    $$DocumentsTableCreateCompanionBuilder,
    $$DocumentsTableUpdateCompanionBuilder,
    (DocumentRow, $$DocumentsTableReferences),
    DocumentRow,
    PrefetchHooks Function({bool tripDocumentsRefs})>;
typedef $$TripDocumentsTableCreateCompanionBuilder = TripDocumentsCompanion
    Function({
  required String tripId,
  required String documentId,
  Value<int> rowid,
});
typedef $$TripDocumentsTableUpdateCompanionBuilder = TripDocumentsCompanion
    Function({
  Value<String> tripId,
  Value<String> documentId,
  Value<int> rowid,
});

final class $$TripDocumentsTableReferences extends BaseReferences<_$AppDatabase,
    $TripDocumentsTable, TripDocumentRow> {
  $$TripDocumentsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $TripsTable _tripIdTable(_$AppDatabase db) =>
      db.trips.createAlias('trip_documents__trip_id__trips__id');

  $$TripsTableProcessedTableManager get tripId {
    final $_column = $_itemColumn<String>('trip_id')!;

    final manager = $$TripsTableTableManager($_db, $_db.trips)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tripIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $DocumentsTable _documentIdTable(_$AppDatabase db) =>
      db.documents.createAlias('trip_documents__document_id__documents__id');

  $$DocumentsTableProcessedTableManager get documentId {
    final $_column = $_itemColumn<String>('document_id')!;

    final manager = $$DocumentsTableTableManager($_db, $_db.documents)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_documentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$TripDocumentsTableFilterComposer
    extends Composer<_$AppDatabase, $TripDocumentsTable> {
  $$TripDocumentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$TripsTableFilterComposer get tripId {
    final $$TripsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.tripId,
        referencedTable: $db.trips,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TripsTableFilterComposer(
              $db: $db,
              $table: $db.trips,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$DocumentsTableFilterComposer get documentId {
    final $$DocumentsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.documentId,
        referencedTable: $db.documents,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$DocumentsTableFilterComposer(
              $db: $db,
              $table: $db.documents,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TripDocumentsTableOrderingComposer
    extends Composer<_$AppDatabase, $TripDocumentsTable> {
  $$TripDocumentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$TripsTableOrderingComposer get tripId {
    final $$TripsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.tripId,
        referencedTable: $db.trips,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TripsTableOrderingComposer(
              $db: $db,
              $table: $db.trips,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$DocumentsTableOrderingComposer get documentId {
    final $$DocumentsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.documentId,
        referencedTable: $db.documents,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$DocumentsTableOrderingComposer(
              $db: $db,
              $table: $db.documents,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TripDocumentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TripDocumentsTable> {
  $$TripDocumentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$TripsTableAnnotationComposer get tripId {
    final $$TripsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.tripId,
        referencedTable: $db.trips,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TripsTableAnnotationComposer(
              $db: $db,
              $table: $db.trips,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$DocumentsTableAnnotationComposer get documentId {
    final $$DocumentsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.documentId,
        referencedTable: $db.documents,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$DocumentsTableAnnotationComposer(
              $db: $db,
              $table: $db.documents,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TripDocumentsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TripDocumentsTable,
    TripDocumentRow,
    $$TripDocumentsTableFilterComposer,
    $$TripDocumentsTableOrderingComposer,
    $$TripDocumentsTableAnnotationComposer,
    $$TripDocumentsTableCreateCompanionBuilder,
    $$TripDocumentsTableUpdateCompanionBuilder,
    (TripDocumentRow, $$TripDocumentsTableReferences),
    TripDocumentRow,
    PrefetchHooks Function({bool tripId, bool documentId})> {
  $$TripDocumentsTableTableManager(_$AppDatabase db, $TripDocumentsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TripDocumentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TripDocumentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TripDocumentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> tripId = const Value.absent(),
            Value<String> documentId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TripDocumentsCompanion(
            tripId: tripId,
            documentId: documentId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String tripId,
            required String documentId,
            Value<int> rowid = const Value.absent(),
          }) =>
              TripDocumentsCompanion.insert(
            tripId: tripId,
            documentId: documentId,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$TripDocumentsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({tripId = false, documentId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (tripId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.tripId,
                    referencedTable:
                        $$TripDocumentsTableReferences._tripIdTable(db),
                    referencedColumn:
                        $$TripDocumentsTableReferences._tripIdTable(db).id,
                  ) as T;
                }
                if (documentId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.documentId,
                    referencedTable:
                        $$TripDocumentsTableReferences._documentIdTable(db),
                    referencedColumn:
                        $$TripDocumentsTableReferences._documentIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$TripDocumentsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TripDocumentsTable,
    TripDocumentRow,
    $$TripDocumentsTableFilterComposer,
    $$TripDocumentsTableOrderingComposer,
    $$TripDocumentsTableAnnotationComposer,
    $$TripDocumentsTableCreateCompanionBuilder,
    $$TripDocumentsTableUpdateCompanionBuilder,
    (TripDocumentRow, $$TripDocumentsTableReferences),
    TripDocumentRow,
    PrefetchHooks Function({bool tripId, bool documentId})>;
typedef $$PlacesTableCreateCompanionBuilder = PlacesCompanion Function({
  required String id,
  required String name,
  Value<double?> lat,
  Value<double?> lng,
  Value<String> country,
  Value<String> city,
  required int status,
  Value<DateTime?> visitedAt,
  Value<String?> tripId,
  Value<String> notes,
  required DateTime createdAt,
  Value<int?> category,
  Value<int> rowid,
});
typedef $$PlacesTableUpdateCompanionBuilder = PlacesCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<double?> lat,
  Value<double?> lng,
  Value<String> country,
  Value<String> city,
  Value<int> status,
  Value<DateTime?> visitedAt,
  Value<String?> tripId,
  Value<String> notes,
  Value<DateTime> createdAt,
  Value<int?> category,
  Value<int> rowid,
});

final class $$PlacesTableReferences
    extends BaseReferences<_$AppDatabase, $PlacesTable, PlaceRow> {
  $$PlacesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TripsTable _tripIdTable(_$AppDatabase db) =>
      db.trips.createAlias('places__trip_id__trips__id');

  $$TripsTableProcessedTableManager? get tripId {
    final $_column = $_itemColumn<String>('trip_id');
    if ($_column == null) return null;
    final manager = $$TripsTableTableManager($_db, $_db.trips)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tripIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$ItineraryItemsTable, List<ItineraryItemRow>>
      _itineraryItemsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.itineraryItems,
              aliasName: 'places__id__itinerary_items__place_id');

  $$ItineraryItemsTableProcessedTableManager get itineraryItemsRefs {
    final manager = $$ItineraryItemsTableTableManager($_db, $_db.itineraryItems)
        .filter((f) => f.placeId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_itineraryItemsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$JournalEntriesTable, List<JournalEntryRow>>
      _journalEntriesRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.journalEntries,
              aliasName: 'places__id__journal_entries__place_id');

  $$JournalEntriesTableProcessedTableManager get journalEntriesRefs {
    final manager = $$JournalEntriesTableTableManager($_db, $_db.journalEntries)
        .filter((f) => f.placeId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_journalEntriesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$PlacesTableFilterComposer
    extends Composer<_$AppDatabase, $PlacesTable> {
  $$PlacesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get lat => $composableBuilder(
      column: $table.lat, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get lng => $composableBuilder(
      column: $table.lng, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get country => $composableBuilder(
      column: $table.country, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get city => $composableBuilder(
      column: $table.city, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get visitedAt => $composableBuilder(
      column: $table.visitedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));

  $$TripsTableFilterComposer get tripId {
    final $$TripsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.tripId,
        referencedTable: $db.trips,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TripsTableFilterComposer(
              $db: $db,
              $table: $db.trips,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> itineraryItemsRefs(
      Expression<bool> Function($$ItineraryItemsTableFilterComposer f) f) {
    final $$ItineraryItemsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.itineraryItems,
        getReferencedColumn: (t) => t.placeId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ItineraryItemsTableFilterComposer(
              $db: $db,
              $table: $db.itineraryItems,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> journalEntriesRefs(
      Expression<bool> Function($$JournalEntriesTableFilterComposer f) f) {
    final $$JournalEntriesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.journalEntries,
        getReferencedColumn: (t) => t.placeId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$JournalEntriesTableFilterComposer(
              $db: $db,
              $table: $db.journalEntries,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$PlacesTableOrderingComposer
    extends Composer<_$AppDatabase, $PlacesTable> {
  $$PlacesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get lat => $composableBuilder(
      column: $table.lat, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get lng => $composableBuilder(
      column: $table.lng, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get country => $composableBuilder(
      column: $table.country, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get city => $composableBuilder(
      column: $table.city, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get visitedAt => $composableBuilder(
      column: $table.visitedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));

  $$TripsTableOrderingComposer get tripId {
    final $$TripsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.tripId,
        referencedTable: $db.trips,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TripsTableOrderingComposer(
              $db: $db,
              $table: $db.trips,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PlacesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlacesTable> {
  $$PlacesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get lat =>
      $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lng =>
      $composableBuilder(column: $table.lng, builder: (column) => column);

  GeneratedColumn<String> get country =>
      $composableBuilder(column: $table.country, builder: (column) => column);

  GeneratedColumn<String> get city =>
      $composableBuilder(column: $table.city, builder: (column) => column);

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get visitedAt =>
      $composableBuilder(column: $table.visitedAt, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  $$TripsTableAnnotationComposer get tripId {
    final $$TripsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.tripId,
        referencedTable: $db.trips,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TripsTableAnnotationComposer(
              $db: $db,
              $table: $db.trips,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> itineraryItemsRefs<T extends Object>(
      Expression<T> Function($$ItineraryItemsTableAnnotationComposer a) f) {
    final $$ItineraryItemsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.itineraryItems,
        getReferencedColumn: (t) => t.placeId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ItineraryItemsTableAnnotationComposer(
              $db: $db,
              $table: $db.itineraryItems,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> journalEntriesRefs<T extends Object>(
      Expression<T> Function($$JournalEntriesTableAnnotationComposer a) f) {
    final $$JournalEntriesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.journalEntries,
        getReferencedColumn: (t) => t.placeId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$JournalEntriesTableAnnotationComposer(
              $db: $db,
              $table: $db.journalEntries,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$PlacesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PlacesTable,
    PlaceRow,
    $$PlacesTableFilterComposer,
    $$PlacesTableOrderingComposer,
    $$PlacesTableAnnotationComposer,
    $$PlacesTableCreateCompanionBuilder,
    $$PlacesTableUpdateCompanionBuilder,
    (PlaceRow, $$PlacesTableReferences),
    PlaceRow,
    PrefetchHooks Function(
        {bool tripId, bool itineraryItemsRefs, bool journalEntriesRefs})> {
  $$PlacesTableTableManager(_$AppDatabase db, $PlacesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlacesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlacesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlacesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<double?> lat = const Value.absent(),
            Value<double?> lng = const Value.absent(),
            Value<String> country = const Value.absent(),
            Value<String> city = const Value.absent(),
            Value<int> status = const Value.absent(),
            Value<DateTime?> visitedAt = const Value.absent(),
            Value<String?> tripId = const Value.absent(),
            Value<String> notes = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int?> category = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PlacesCompanion(
            id: id,
            name: name,
            lat: lat,
            lng: lng,
            country: country,
            city: city,
            status: status,
            visitedAt: visitedAt,
            tripId: tripId,
            notes: notes,
            createdAt: createdAt,
            category: category,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            Value<double?> lat = const Value.absent(),
            Value<double?> lng = const Value.absent(),
            Value<String> country = const Value.absent(),
            Value<String> city = const Value.absent(),
            required int status,
            Value<DateTime?> visitedAt = const Value.absent(),
            Value<String?> tripId = const Value.absent(),
            Value<String> notes = const Value.absent(),
            required DateTime createdAt,
            Value<int?> category = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PlacesCompanion.insert(
            id: id,
            name: name,
            lat: lat,
            lng: lng,
            country: country,
            city: city,
            status: status,
            visitedAt: visitedAt,
            tripId: tripId,
            notes: notes,
            createdAt: createdAt,
            category: category,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$PlacesTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: (
              {tripId = false,
              itineraryItemsRefs = false,
              journalEntriesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (itineraryItemsRefs) db.itineraryItems,
                if (journalEntriesRefs) db.journalEntries
              ],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (tripId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.tripId,
                    referencedTable: $$PlacesTableReferences._tripIdTable(db),
                    referencedColumn:
                        $$PlacesTableReferences._tripIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (itineraryItemsRefs)
                    await $_getPrefetchedData<PlaceRow, $PlacesTable,
                            ItineraryItemRow>(
                        currentTable: table,
                        referencedTable: $$PlacesTableReferences
                            ._itineraryItemsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$PlacesTableReferences(db, table, p0)
                                .itineraryItemsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.placeId == item.id),
                        typedResults: items),
                  if (journalEntriesRefs)
                    await $_getPrefetchedData<PlaceRow, $PlacesTable,
                            JournalEntryRow>(
                        currentTable: table,
                        referencedTable: $$PlacesTableReferences
                            ._journalEntriesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$PlacesTableReferences(db, table, p0)
                                .journalEntriesRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.placeId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$PlacesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PlacesTable,
    PlaceRow,
    $$PlacesTableFilterComposer,
    $$PlacesTableOrderingComposer,
    $$PlacesTableAnnotationComposer,
    $$PlacesTableCreateCompanionBuilder,
    $$PlacesTableUpdateCompanionBuilder,
    (PlaceRow, $$PlacesTableReferences),
    PlaceRow,
    PrefetchHooks Function(
        {bool tripId, bool itineraryItemsRefs, bool journalEntriesRefs})>;
typedef $$ExpensesTableCreateCompanionBuilder = ExpensesCompanion Function({
  required String id,
  required String tripId,
  required int amountMinor,
  required String currency,
  required int category,
  required DateTime date,
  Value<String> notes,
  required DateTime createdAt,
  Value<int?> convertedAmountMinor,
  Value<String?> convertedCurrency,
  Value<DateTime?> convertedRateAt,
  Value<int> rowid,
});
typedef $$ExpensesTableUpdateCompanionBuilder = ExpensesCompanion Function({
  Value<String> id,
  Value<String> tripId,
  Value<int> amountMinor,
  Value<String> currency,
  Value<int> category,
  Value<DateTime> date,
  Value<String> notes,
  Value<DateTime> createdAt,
  Value<int?> convertedAmountMinor,
  Value<String?> convertedCurrency,
  Value<DateTime?> convertedRateAt,
  Value<int> rowid,
});

final class $$ExpensesTableReferences
    extends BaseReferences<_$AppDatabase, $ExpensesTable, ExpenseRow> {
  $$ExpensesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TripsTable _tripIdTable(_$AppDatabase db) =>
      db.trips.createAlias('expenses__trip_id__trips__id');

  $$TripsTableProcessedTableManager get tripId {
    final $_column = $_itemColumn<String>('trip_id')!;

    final manager = $$TripsTableTableManager($_db, $_db.trips)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tripIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$ExpensesTableFilterComposer
    extends Composer<_$AppDatabase, $ExpensesTable> {
  $$ExpensesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get amountMinor => $composableBuilder(
      column: $table.amountMinor, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get convertedAmountMinor => $composableBuilder(
      column: $table.convertedAmountMinor,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get convertedCurrency => $composableBuilder(
      column: $table.convertedCurrency,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get convertedRateAt => $composableBuilder(
      column: $table.convertedRateAt,
      builder: (column) => ColumnFilters(column));

  $$TripsTableFilterComposer get tripId {
    final $$TripsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.tripId,
        referencedTable: $db.trips,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TripsTableFilterComposer(
              $db: $db,
              $table: $db.trips,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ExpensesTableOrderingComposer
    extends Composer<_$AppDatabase, $ExpensesTable> {
  $$ExpensesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get amountMinor => $composableBuilder(
      column: $table.amountMinor, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get convertedAmountMinor => $composableBuilder(
      column: $table.convertedAmountMinor,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get convertedCurrency => $composableBuilder(
      column: $table.convertedCurrency,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get convertedRateAt => $composableBuilder(
      column: $table.convertedRateAt,
      builder: (column) => ColumnOrderings(column));

  $$TripsTableOrderingComposer get tripId {
    final $$TripsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.tripId,
        referencedTable: $db.trips,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TripsTableOrderingComposer(
              $db: $db,
              $table: $db.trips,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ExpensesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExpensesTable> {
  $$ExpensesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get amountMinor => $composableBuilder(
      column: $table.amountMinor, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<int> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get convertedAmountMinor => $composableBuilder(
      column: $table.convertedAmountMinor, builder: (column) => column);

  GeneratedColumn<String> get convertedCurrency => $composableBuilder(
      column: $table.convertedCurrency, builder: (column) => column);

  GeneratedColumn<DateTime> get convertedRateAt => $composableBuilder(
      column: $table.convertedRateAt, builder: (column) => column);

  $$TripsTableAnnotationComposer get tripId {
    final $$TripsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.tripId,
        referencedTable: $db.trips,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TripsTableAnnotationComposer(
              $db: $db,
              $table: $db.trips,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ExpensesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ExpensesTable,
    ExpenseRow,
    $$ExpensesTableFilterComposer,
    $$ExpensesTableOrderingComposer,
    $$ExpensesTableAnnotationComposer,
    $$ExpensesTableCreateCompanionBuilder,
    $$ExpensesTableUpdateCompanionBuilder,
    (ExpenseRow, $$ExpensesTableReferences),
    ExpenseRow,
    PrefetchHooks Function({bool tripId})> {
  $$ExpensesTableTableManager(_$AppDatabase db, $ExpensesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExpensesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExpensesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExpensesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> tripId = const Value.absent(),
            Value<int> amountMinor = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<int> category = const Value.absent(),
            Value<DateTime> date = const Value.absent(),
            Value<String> notes = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int?> convertedAmountMinor = const Value.absent(),
            Value<String?> convertedCurrency = const Value.absent(),
            Value<DateTime?> convertedRateAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ExpensesCompanion(
            id: id,
            tripId: tripId,
            amountMinor: amountMinor,
            currency: currency,
            category: category,
            date: date,
            notes: notes,
            createdAt: createdAt,
            convertedAmountMinor: convertedAmountMinor,
            convertedCurrency: convertedCurrency,
            convertedRateAt: convertedRateAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String tripId,
            required int amountMinor,
            required String currency,
            required int category,
            required DateTime date,
            Value<String> notes = const Value.absent(),
            required DateTime createdAt,
            Value<int?> convertedAmountMinor = const Value.absent(),
            Value<String?> convertedCurrency = const Value.absent(),
            Value<DateTime?> convertedRateAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ExpensesCompanion.insert(
            id: id,
            tripId: tripId,
            amountMinor: amountMinor,
            currency: currency,
            category: category,
            date: date,
            notes: notes,
            createdAt: createdAt,
            convertedAmountMinor: convertedAmountMinor,
            convertedCurrency: convertedCurrency,
            convertedRateAt: convertedRateAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$ExpensesTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({tripId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (tripId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.tripId,
                    referencedTable: $$ExpensesTableReferences._tripIdTable(db),
                    referencedColumn:
                        $$ExpensesTableReferences._tripIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$ExpensesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ExpensesTable,
    ExpenseRow,
    $$ExpensesTableFilterComposer,
    $$ExpensesTableOrderingComposer,
    $$ExpensesTableAnnotationComposer,
    $$ExpensesTableCreateCompanionBuilder,
    $$ExpensesTableUpdateCompanionBuilder,
    (ExpenseRow, $$ExpensesTableReferences),
    ExpenseRow,
    PrefetchHooks Function({bool tripId})>;
typedef $$ItineraryItemsTableCreateCompanionBuilder = ItineraryItemsCompanion
    Function({
  required String id,
  required String tripId,
  required DateTime date,
  Value<int?> startMinutes,
  required String title,
  Value<String?> placeId,
  Value<String> notes,
  required int orderIndex,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$ItineraryItemsTableUpdateCompanionBuilder = ItineraryItemsCompanion
    Function({
  Value<String> id,
  Value<String> tripId,
  Value<DateTime> date,
  Value<int?> startMinutes,
  Value<String> title,
  Value<String?> placeId,
  Value<String> notes,
  Value<int> orderIndex,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$ItineraryItemsTableReferences extends BaseReferences<
    _$AppDatabase, $ItineraryItemsTable, ItineraryItemRow> {
  $$ItineraryItemsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $TripsTable _tripIdTable(_$AppDatabase db) =>
      db.trips.createAlias('itinerary_items__trip_id__trips__id');

  $$TripsTableProcessedTableManager get tripId {
    final $_column = $_itemColumn<String>('trip_id')!;

    final manager = $$TripsTableTableManager($_db, $_db.trips)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tripIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $PlacesTable _placeIdTable(_$AppDatabase db) =>
      db.places.createAlias('itinerary_items__place_id__places__id');

  $$PlacesTableProcessedTableManager? get placeId {
    final $_column = $_itemColumn<String>('place_id');
    if ($_column == null) return null;
    final manager = $$PlacesTableTableManager($_db, $_db.places)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_placeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$ItineraryItemsTableFilterComposer
    extends Composer<_$AppDatabase, $ItineraryItemsTable> {
  $$ItineraryItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get startMinutes => $composableBuilder(
      column: $table.startMinutes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get orderIndex => $composableBuilder(
      column: $table.orderIndex, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  $$TripsTableFilterComposer get tripId {
    final $$TripsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.tripId,
        referencedTable: $db.trips,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TripsTableFilterComposer(
              $db: $db,
              $table: $db.trips,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$PlacesTableFilterComposer get placeId {
    final $$PlacesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.placeId,
        referencedTable: $db.places,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlacesTableFilterComposer(
              $db: $db,
              $table: $db.places,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ItineraryItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $ItineraryItemsTable> {
  $$ItineraryItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get startMinutes => $composableBuilder(
      column: $table.startMinutes,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get orderIndex => $composableBuilder(
      column: $table.orderIndex, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  $$TripsTableOrderingComposer get tripId {
    final $$TripsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.tripId,
        referencedTable: $db.trips,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TripsTableOrderingComposer(
              $db: $db,
              $table: $db.trips,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$PlacesTableOrderingComposer get placeId {
    final $$PlacesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.placeId,
        referencedTable: $db.places,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlacesTableOrderingComposer(
              $db: $db,
              $table: $db.places,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ItineraryItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ItineraryItemsTable> {
  $$ItineraryItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get startMinutes => $composableBuilder(
      column: $table.startMinutes, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<int> get orderIndex => $composableBuilder(
      column: $table.orderIndex, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$TripsTableAnnotationComposer get tripId {
    final $$TripsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.tripId,
        referencedTable: $db.trips,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TripsTableAnnotationComposer(
              $db: $db,
              $table: $db.trips,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$PlacesTableAnnotationComposer get placeId {
    final $$PlacesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.placeId,
        referencedTable: $db.places,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlacesTableAnnotationComposer(
              $db: $db,
              $table: $db.places,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ItineraryItemsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ItineraryItemsTable,
    ItineraryItemRow,
    $$ItineraryItemsTableFilterComposer,
    $$ItineraryItemsTableOrderingComposer,
    $$ItineraryItemsTableAnnotationComposer,
    $$ItineraryItemsTableCreateCompanionBuilder,
    $$ItineraryItemsTableUpdateCompanionBuilder,
    (ItineraryItemRow, $$ItineraryItemsTableReferences),
    ItineraryItemRow,
    PrefetchHooks Function({bool tripId, bool placeId})> {
  $$ItineraryItemsTableTableManager(
      _$AppDatabase db, $ItineraryItemsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ItineraryItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ItineraryItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ItineraryItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> tripId = const Value.absent(),
            Value<DateTime> date = const Value.absent(),
            Value<int?> startMinutes = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> placeId = const Value.absent(),
            Value<String> notes = const Value.absent(),
            Value<int> orderIndex = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ItineraryItemsCompanion(
            id: id,
            tripId: tripId,
            date: date,
            startMinutes: startMinutes,
            title: title,
            placeId: placeId,
            notes: notes,
            orderIndex: orderIndex,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String tripId,
            required DateTime date,
            Value<int?> startMinutes = const Value.absent(),
            required String title,
            Value<String?> placeId = const Value.absent(),
            Value<String> notes = const Value.absent(),
            required int orderIndex,
            required DateTime createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              ItineraryItemsCompanion.insert(
            id: id,
            tripId: tripId,
            date: date,
            startMinutes: startMinutes,
            title: title,
            placeId: placeId,
            notes: notes,
            orderIndex: orderIndex,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$ItineraryItemsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({tripId = false, placeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (tripId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.tripId,
                    referencedTable:
                        $$ItineraryItemsTableReferences._tripIdTable(db),
                    referencedColumn:
                        $$ItineraryItemsTableReferences._tripIdTable(db).id,
                  ) as T;
                }
                if (placeId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.placeId,
                    referencedTable:
                        $$ItineraryItemsTableReferences._placeIdTable(db),
                    referencedColumn:
                        $$ItineraryItemsTableReferences._placeIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$ItineraryItemsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ItineraryItemsTable,
    ItineraryItemRow,
    $$ItineraryItemsTableFilterComposer,
    $$ItineraryItemsTableOrderingComposer,
    $$ItineraryItemsTableAnnotationComposer,
    $$ItineraryItemsTableCreateCompanionBuilder,
    $$ItineraryItemsTableUpdateCompanionBuilder,
    (ItineraryItemRow, $$ItineraryItemsTableReferences),
    ItineraryItemRow,
    PrefetchHooks Function({bool tripId, bool placeId})>;
typedef $$JournalEntriesTableCreateCompanionBuilder = JournalEntriesCompanion
    Function({
  required String id,
  required String tripId,
  required String summary,
  required DateTime loggedAt,
  Value<double?> lat,
  Value<double?> lng,
  Value<String?> placeName,
  Value<String?> placeId,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$JournalEntriesTableUpdateCompanionBuilder = JournalEntriesCompanion
    Function({
  Value<String> id,
  Value<String> tripId,
  Value<String> summary,
  Value<DateTime> loggedAt,
  Value<double?> lat,
  Value<double?> lng,
  Value<String?> placeName,
  Value<String?> placeId,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$JournalEntriesTableReferences extends BaseReferences<
    _$AppDatabase, $JournalEntriesTable, JournalEntryRow> {
  $$JournalEntriesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $TripsTable _tripIdTable(_$AppDatabase db) =>
      db.trips.createAlias('journal_entries__trip_id__trips__id');

  $$TripsTableProcessedTableManager get tripId {
    final $_column = $_itemColumn<String>('trip_id')!;

    final manager = $$TripsTableTableManager($_db, $_db.trips)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tripIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $PlacesTable _placeIdTable(_$AppDatabase db) =>
      db.places.createAlias('journal_entries__place_id__places__id');

  $$PlacesTableProcessedTableManager? get placeId {
    final $_column = $_itemColumn<String>('place_id');
    if ($_column == null) return null;
    final manager = $$PlacesTableTableManager($_db, $_db.places)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_placeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$JournalPhotosTable, List<JournalPhotoRow>>
      _journalPhotosRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.journalPhotos,
              aliasName: 'journal_entries__id__journal_photos__entry_id');

  $$JournalPhotosTableProcessedTableManager get journalPhotosRefs {
    final manager = $$JournalPhotosTableTableManager($_db, $_db.journalPhotos)
        .filter((f) => f.entryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_journalPhotosRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$JournalEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $JournalEntriesTable> {
  $$JournalEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get summary => $composableBuilder(
      column: $table.summary, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get loggedAt => $composableBuilder(
      column: $table.loggedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get lat => $composableBuilder(
      column: $table.lat, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get lng => $composableBuilder(
      column: $table.lng, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get placeName => $composableBuilder(
      column: $table.placeName, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  $$TripsTableFilterComposer get tripId {
    final $$TripsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.tripId,
        referencedTable: $db.trips,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TripsTableFilterComposer(
              $db: $db,
              $table: $db.trips,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$PlacesTableFilterComposer get placeId {
    final $$PlacesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.placeId,
        referencedTable: $db.places,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlacesTableFilterComposer(
              $db: $db,
              $table: $db.places,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> journalPhotosRefs(
      Expression<bool> Function($$JournalPhotosTableFilterComposer f) f) {
    final $$JournalPhotosTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.journalPhotos,
        getReferencedColumn: (t) => t.entryId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$JournalPhotosTableFilterComposer(
              $db: $db,
              $table: $db.journalPhotos,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$JournalEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $JournalEntriesTable> {
  $$JournalEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get summary => $composableBuilder(
      column: $table.summary, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get loggedAt => $composableBuilder(
      column: $table.loggedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get lat => $composableBuilder(
      column: $table.lat, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get lng => $composableBuilder(
      column: $table.lng, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get placeName => $composableBuilder(
      column: $table.placeName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  $$TripsTableOrderingComposer get tripId {
    final $$TripsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.tripId,
        referencedTable: $db.trips,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TripsTableOrderingComposer(
              $db: $db,
              $table: $db.trips,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$PlacesTableOrderingComposer get placeId {
    final $$PlacesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.placeId,
        referencedTable: $db.places,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlacesTableOrderingComposer(
              $db: $db,
              $table: $db.places,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$JournalEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $JournalEntriesTable> {
  $$JournalEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<DateTime> get loggedAt =>
      $composableBuilder(column: $table.loggedAt, builder: (column) => column);

  GeneratedColumn<double> get lat =>
      $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lng =>
      $composableBuilder(column: $table.lng, builder: (column) => column);

  GeneratedColumn<String> get placeName =>
      $composableBuilder(column: $table.placeName, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$TripsTableAnnotationComposer get tripId {
    final $$TripsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.tripId,
        referencedTable: $db.trips,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TripsTableAnnotationComposer(
              $db: $db,
              $table: $db.trips,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$PlacesTableAnnotationComposer get placeId {
    final $$PlacesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.placeId,
        referencedTable: $db.places,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlacesTableAnnotationComposer(
              $db: $db,
              $table: $db.places,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> journalPhotosRefs<T extends Object>(
      Expression<T> Function($$JournalPhotosTableAnnotationComposer a) f) {
    final $$JournalPhotosTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.journalPhotos,
        getReferencedColumn: (t) => t.entryId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$JournalPhotosTableAnnotationComposer(
              $db: $db,
              $table: $db.journalPhotos,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$JournalEntriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $JournalEntriesTable,
    JournalEntryRow,
    $$JournalEntriesTableFilterComposer,
    $$JournalEntriesTableOrderingComposer,
    $$JournalEntriesTableAnnotationComposer,
    $$JournalEntriesTableCreateCompanionBuilder,
    $$JournalEntriesTableUpdateCompanionBuilder,
    (JournalEntryRow, $$JournalEntriesTableReferences),
    JournalEntryRow,
    PrefetchHooks Function(
        {bool tripId, bool placeId, bool journalPhotosRefs})> {
  $$JournalEntriesTableTableManager(
      _$AppDatabase db, $JournalEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$JournalEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$JournalEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$JournalEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> tripId = const Value.absent(),
            Value<String> summary = const Value.absent(),
            Value<DateTime> loggedAt = const Value.absent(),
            Value<double?> lat = const Value.absent(),
            Value<double?> lng = const Value.absent(),
            Value<String?> placeName = const Value.absent(),
            Value<String?> placeId = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              JournalEntriesCompanion(
            id: id,
            tripId: tripId,
            summary: summary,
            loggedAt: loggedAt,
            lat: lat,
            lng: lng,
            placeName: placeName,
            placeId: placeId,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String tripId,
            required String summary,
            required DateTime loggedAt,
            Value<double?> lat = const Value.absent(),
            Value<double?> lng = const Value.absent(),
            Value<String?> placeName = const Value.absent(),
            Value<String?> placeId = const Value.absent(),
            required DateTime createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              JournalEntriesCompanion.insert(
            id: id,
            tripId: tripId,
            summary: summary,
            loggedAt: loggedAt,
            lat: lat,
            lng: lng,
            placeName: placeName,
            placeId: placeId,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$JournalEntriesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {tripId = false, placeId = false, journalPhotosRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (journalPhotosRefs) db.journalPhotos
              ],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (tripId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.tripId,
                    referencedTable:
                        $$JournalEntriesTableReferences._tripIdTable(db),
                    referencedColumn:
                        $$JournalEntriesTableReferences._tripIdTable(db).id,
                  ) as T;
                }
                if (placeId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.placeId,
                    referencedTable:
                        $$JournalEntriesTableReferences._placeIdTable(db),
                    referencedColumn:
                        $$JournalEntriesTableReferences._placeIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (journalPhotosRefs)
                    await $_getPrefetchedData<JournalEntryRow,
                            $JournalEntriesTable, JournalPhotoRow>(
                        currentTable: table,
                        referencedTable: $$JournalEntriesTableReferences
                            ._journalPhotosRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$JournalEntriesTableReferences(db, table, p0)
                                .journalPhotosRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.entryId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$JournalEntriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $JournalEntriesTable,
    JournalEntryRow,
    $$JournalEntriesTableFilterComposer,
    $$JournalEntriesTableOrderingComposer,
    $$JournalEntriesTableAnnotationComposer,
    $$JournalEntriesTableCreateCompanionBuilder,
    $$JournalEntriesTableUpdateCompanionBuilder,
    (JournalEntryRow, $$JournalEntriesTableReferences),
    JournalEntryRow,
    PrefetchHooks Function(
        {bool tripId, bool placeId, bool journalPhotosRefs})>;
typedef $$JournalPhotosTableCreateCompanionBuilder = JournalPhotosCompanion
    Function({
  required String id,
  required String entryId,
  required String filePath,
  required int orderIndex,
  Value<int> rowid,
});
typedef $$JournalPhotosTableUpdateCompanionBuilder = JournalPhotosCompanion
    Function({
  Value<String> id,
  Value<String> entryId,
  Value<String> filePath,
  Value<int> orderIndex,
  Value<int> rowid,
});

final class $$JournalPhotosTableReferences extends BaseReferences<_$AppDatabase,
    $JournalPhotosTable, JournalPhotoRow> {
  $$JournalPhotosTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $JournalEntriesTable _entryIdTable(_$AppDatabase db) =>
      db.journalEntries
          .createAlias('journal_photos__entry_id__journal_entries__id');

  $$JournalEntriesTableProcessedTableManager get entryId {
    final $_column = $_itemColumn<String>('entry_id')!;

    final manager = $$JournalEntriesTableTableManager($_db, $_db.journalEntries)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_entryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$JournalPhotosTableFilterComposer
    extends Composer<_$AppDatabase, $JournalPhotosTable> {
  $$JournalPhotosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get orderIndex => $composableBuilder(
      column: $table.orderIndex, builder: (column) => ColumnFilters(column));

  $$JournalEntriesTableFilterComposer get entryId {
    final $$JournalEntriesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.entryId,
        referencedTable: $db.journalEntries,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$JournalEntriesTableFilterComposer(
              $db: $db,
              $table: $db.journalEntries,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$JournalPhotosTableOrderingComposer
    extends Composer<_$AppDatabase, $JournalPhotosTable> {
  $$JournalPhotosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get orderIndex => $composableBuilder(
      column: $table.orderIndex, builder: (column) => ColumnOrderings(column));

  $$JournalEntriesTableOrderingComposer get entryId {
    final $$JournalEntriesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.entryId,
        referencedTable: $db.journalEntries,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$JournalEntriesTableOrderingComposer(
              $db: $db,
              $table: $db.journalEntries,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$JournalPhotosTableAnnotationComposer
    extends Composer<_$AppDatabase, $JournalPhotosTable> {
  $$JournalPhotosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<int> get orderIndex => $composableBuilder(
      column: $table.orderIndex, builder: (column) => column);

  $$JournalEntriesTableAnnotationComposer get entryId {
    final $$JournalEntriesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.entryId,
        referencedTable: $db.journalEntries,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$JournalEntriesTableAnnotationComposer(
              $db: $db,
              $table: $db.journalEntries,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$JournalPhotosTableTableManager extends RootTableManager<
    _$AppDatabase,
    $JournalPhotosTable,
    JournalPhotoRow,
    $$JournalPhotosTableFilterComposer,
    $$JournalPhotosTableOrderingComposer,
    $$JournalPhotosTableAnnotationComposer,
    $$JournalPhotosTableCreateCompanionBuilder,
    $$JournalPhotosTableUpdateCompanionBuilder,
    (JournalPhotoRow, $$JournalPhotosTableReferences),
    JournalPhotoRow,
    PrefetchHooks Function({bool entryId})> {
  $$JournalPhotosTableTableManager(_$AppDatabase db, $JournalPhotosTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$JournalPhotosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$JournalPhotosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$JournalPhotosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> entryId = const Value.absent(),
            Value<String> filePath = const Value.absent(),
            Value<int> orderIndex = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              JournalPhotosCompanion(
            id: id,
            entryId: entryId,
            filePath: filePath,
            orderIndex: orderIndex,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String entryId,
            required String filePath,
            required int orderIndex,
            Value<int> rowid = const Value.absent(),
          }) =>
              JournalPhotosCompanion.insert(
            id: id,
            entryId: entryId,
            filePath: filePath,
            orderIndex: orderIndex,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$JournalPhotosTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({entryId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (entryId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.entryId,
                    referencedTable:
                        $$JournalPhotosTableReferences._entryIdTable(db),
                    referencedColumn:
                        $$JournalPhotosTableReferences._entryIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$JournalPhotosTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $JournalPhotosTable,
    JournalPhotoRow,
    $$JournalPhotosTableFilterComposer,
    $$JournalPhotosTableOrderingComposer,
    $$JournalPhotosTableAnnotationComposer,
    $$JournalPhotosTableCreateCompanionBuilder,
    $$JournalPhotosTableUpdateCompanionBuilder,
    (JournalPhotoRow, $$JournalPhotosTableReferences),
    JournalPhotoRow,
    PrefetchHooks Function({bool entryId})>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TripsTableTableManager get trips =>
      $$TripsTableTableManager(_db, _db.trips);
  $$TripDestinationsTableTableManager get tripDestinations =>
      $$TripDestinationsTableTableManager(_db, _db.tripDestinations);
  $$DocumentsTableTableManager get documents =>
      $$DocumentsTableTableManager(_db, _db.documents);
  $$TripDocumentsTableTableManager get tripDocuments =>
      $$TripDocumentsTableTableManager(_db, _db.tripDocuments);
  $$PlacesTableTableManager get places =>
      $$PlacesTableTableManager(_db, _db.places);
  $$ExpensesTableTableManager get expenses =>
      $$ExpensesTableTableManager(_db, _db.expenses);
  $$ItineraryItemsTableTableManager get itineraryItems =>
      $$ItineraryItemsTableTableManager(_db, _db.itineraryItems);
  $$JournalEntriesTableTableManager get journalEntries =>
      $$JournalEntriesTableTableManager(_db, _db.journalEntries);
  $$JournalPhotosTableTableManager get journalPhotos =>
      $$JournalPhotosTableTableManager(_db, _db.journalPhotos);
}

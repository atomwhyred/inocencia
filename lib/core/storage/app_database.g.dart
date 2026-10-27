// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $GuardiansTable extends Guardians
    with TableInfo<$GuardiansTable, GuardianRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GuardiansTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 60,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pinHashMeta = const VerificationMeta(
    'pinHash',
  );
  @override
  late final GeneratedColumn<String> pinHash = GeneratedColumn<String>(
    'pin_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pinLengthMeta = const VerificationMeta(
    'pinLength',
  );
  @override
  late final GeneratedColumn<int> pinLength = GeneratedColumn<int>(
    'pin_length',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, pinHash, pinLength];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'guardians';
  @override
  VerificationContext validateIntegrity(
    Insertable<GuardianRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('pin_hash')) {
      context.handle(
        _pinHashMeta,
        pinHash.isAcceptableOrUnknown(data['pin_hash']!, _pinHashMeta),
      );
    } else if (isInserting) {
      context.missing(_pinHashMeta);
    }
    if (data.containsKey('pin_length')) {
      context.handle(
        _pinLengthMeta,
        pinLength.isAcceptableOrUnknown(data['pin_length']!, _pinLengthMeta),
      );
    } else if (isInserting) {
      context.missing(_pinLengthMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GuardianRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GuardianRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      pinHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pin_hash'],
      )!,
      pinLength: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pin_length'],
      )!,
    );
  }

  @override
  $GuardiansTable createAlias(String alias) {
    return $GuardiansTable(attachedDatabase, alias);
  }
}

class GuardianRow extends DataClass implements Insertable<GuardianRow> {
  final int id;
  final String name;
  final String pinHash;
  final int pinLength;
  const GuardianRow({
    required this.id,
    required this.name,
    required this.pinHash,
    required this.pinLength,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['pin_hash'] = Variable<String>(pinHash);
    map['pin_length'] = Variable<int>(pinLength);
    return map;
  }

  GuardiansCompanion toCompanion(bool nullToAbsent) {
    return GuardiansCompanion(
      id: Value(id),
      name: Value(name),
      pinHash: Value(pinHash),
      pinLength: Value(pinLength),
    );
  }

  factory GuardianRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GuardianRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      pinHash: serializer.fromJson<String>(json['pinHash']),
      pinLength: serializer.fromJson<int>(json['pinLength']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'pinHash': serializer.toJson<String>(pinHash),
      'pinLength': serializer.toJson<int>(pinLength),
    };
  }

  GuardianRow copyWith({
    int? id,
    String? name,
    String? pinHash,
    int? pinLength,
  }) => GuardianRow(
    id: id ?? this.id,
    name: name ?? this.name,
    pinHash: pinHash ?? this.pinHash,
    pinLength: pinLength ?? this.pinLength,
  );
  GuardianRow copyWithCompanion(GuardiansCompanion data) {
    return GuardianRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      pinHash: data.pinHash.present ? data.pinHash.value : this.pinHash,
      pinLength: data.pinLength.present ? data.pinLength.value : this.pinLength,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GuardianRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('pinHash: $pinHash, ')
          ..write('pinLength: $pinLength')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, pinHash, pinLength);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GuardianRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.pinHash == this.pinHash &&
          other.pinLength == this.pinLength);
}

class GuardiansCompanion extends UpdateCompanion<GuardianRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> pinHash;
  final Value<int> pinLength;
  const GuardiansCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.pinHash = const Value.absent(),
    this.pinLength = const Value.absent(),
  });
  GuardiansCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String pinHash,
    required int pinLength,
  }) : name = Value(name),
       pinHash = Value(pinHash),
       pinLength = Value(pinLength);
  static Insertable<GuardianRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? pinHash,
    Expression<int>? pinLength,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (pinHash != null) 'pin_hash': pinHash,
      if (pinLength != null) 'pin_length': pinLength,
    });
  }

  GuardiansCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? pinHash,
    Value<int>? pinLength,
  }) {
    return GuardiansCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      pinHash: pinHash ?? this.pinHash,
      pinLength: pinLength ?? this.pinLength,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (pinHash.present) {
      map['pin_hash'] = Variable<String>(pinHash.value);
    }
    if (pinLength.present) {
      map['pin_length'] = Variable<int>(pinLength.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GuardiansCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('pinHash: $pinHash, ')
          ..write('pinLength: $pinLength')
          ..write(')'))
        .toString();
  }
}

class $ChildProfilesTable extends ChildProfiles
    with TableInfo<$ChildProfilesTable, ChildProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChildProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 40,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _avatarMeta = const VerificationMeta('avatar');
  @override
  late final GeneratedColumn<String> avatar = GeneratedColumn<String>(
    'avatar',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _birthDateMeta = const VerificationMeta(
    'birthDate',
  );
  @override
  late final GeneratedColumn<DateTime> birthDate = GeneratedColumn<DateTime>(
    'birth_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gradeOverrideMeta = const VerificationMeta(
    'gradeOverride',
  );
  @override
  late final GeneratedColumn<int> gradeOverride = GeneratedColumn<int>(
    'grade_override',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pinHashMeta = const VerificationMeta(
    'pinHash',
  );
  @override
  late final GeneratedColumn<String> pinHash = GeneratedColumn<String>(
    'pin_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pinLengthMeta = const VerificationMeta(
    'pinLength',
  );
  @override
  late final GeneratedColumn<int> pinLength = GeneratedColumn<int>(
    'pin_length',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    avatar,
    birthDate,
    gradeOverride,
    pinHash,
    pinLength,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'child_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChildProfileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('avatar')) {
      context.handle(
        _avatarMeta,
        avatar.isAcceptableOrUnknown(data['avatar']!, _avatarMeta),
      );
    } else if (isInserting) {
      context.missing(_avatarMeta);
    }
    if (data.containsKey('birth_date')) {
      context.handle(
        _birthDateMeta,
        birthDate.isAcceptableOrUnknown(data['birth_date']!, _birthDateMeta),
      );
    } else if (isInserting) {
      context.missing(_birthDateMeta);
    }
    if (data.containsKey('grade_override')) {
      context.handle(
        _gradeOverrideMeta,
        gradeOverride.isAcceptableOrUnknown(
          data['grade_override']!,
          _gradeOverrideMeta,
        ),
      );
    }
    if (data.containsKey('pin_hash')) {
      context.handle(
        _pinHashMeta,
        pinHash.isAcceptableOrUnknown(data['pin_hash']!, _pinHashMeta),
      );
    }
    if (data.containsKey('pin_length')) {
      context.handle(
        _pinLengthMeta,
        pinLength.isAcceptableOrUnknown(data['pin_length']!, _pinLengthMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChildProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChildProfileRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      avatar: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}avatar'],
      )!,
      birthDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}birth_date'],
      )!,
      gradeOverride: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}grade_override'],
      ),
      pinHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pin_hash'],
      ),
      pinLength: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pin_length'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ChildProfilesTable createAlias(String alias) {
    return $ChildProfilesTable(attachedDatabase, alias);
  }
}

class ChildProfileRow extends DataClass implements Insertable<ChildProfileRow> {
  final int id;
  final String name;

  /// `emoji:<caracter>` o `photo:<ruta absoluta>`.
  final String avatar;
  final DateTime birthDate;

  /// Grado fijado a mano por el padre; null = calcular desde la fecha.
  final int? gradeOverride;
  final String? pinHash;
  final int? pinLength;
  final DateTime createdAt;
  const ChildProfileRow({
    required this.id,
    required this.name,
    required this.avatar,
    required this.birthDate,
    this.gradeOverride,
    this.pinHash,
    this.pinLength,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['avatar'] = Variable<String>(avatar);
    map['birth_date'] = Variable<DateTime>(birthDate);
    if (!nullToAbsent || gradeOverride != null) {
      map['grade_override'] = Variable<int>(gradeOverride);
    }
    if (!nullToAbsent || pinHash != null) {
      map['pin_hash'] = Variable<String>(pinHash);
    }
    if (!nullToAbsent || pinLength != null) {
      map['pin_length'] = Variable<int>(pinLength);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ChildProfilesCompanion toCompanion(bool nullToAbsent) {
    return ChildProfilesCompanion(
      id: Value(id),
      name: Value(name),
      avatar: Value(avatar),
      birthDate: Value(birthDate),
      gradeOverride: gradeOverride == null && nullToAbsent
          ? const Value.absent()
          : Value(gradeOverride),
      pinHash: pinHash == null && nullToAbsent
          ? const Value.absent()
          : Value(pinHash),
      pinLength: pinLength == null && nullToAbsent
          ? const Value.absent()
          : Value(pinLength),
      createdAt: Value(createdAt),
    );
  }

  factory ChildProfileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChildProfileRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      avatar: serializer.fromJson<String>(json['avatar']),
      birthDate: serializer.fromJson<DateTime>(json['birthDate']),
      gradeOverride: serializer.fromJson<int?>(json['gradeOverride']),
      pinHash: serializer.fromJson<String?>(json['pinHash']),
      pinLength: serializer.fromJson<int?>(json['pinLength']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'avatar': serializer.toJson<String>(avatar),
      'birthDate': serializer.toJson<DateTime>(birthDate),
      'gradeOverride': serializer.toJson<int?>(gradeOverride),
      'pinHash': serializer.toJson<String?>(pinHash),
      'pinLength': serializer.toJson<int?>(pinLength),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ChildProfileRow copyWith({
    int? id,
    String? name,
    String? avatar,
    DateTime? birthDate,
    Value<int?> gradeOverride = const Value.absent(),
    Value<String?> pinHash = const Value.absent(),
    Value<int?> pinLength = const Value.absent(),
    DateTime? createdAt,
  }) => ChildProfileRow(
    id: id ?? this.id,
    name: name ?? this.name,
    avatar: avatar ?? this.avatar,
    birthDate: birthDate ?? this.birthDate,
    gradeOverride: gradeOverride.present
        ? gradeOverride.value
        : this.gradeOverride,
    pinHash: pinHash.present ? pinHash.value : this.pinHash,
    pinLength: pinLength.present ? pinLength.value : this.pinLength,
    createdAt: createdAt ?? this.createdAt,
  );
  ChildProfileRow copyWithCompanion(ChildProfilesCompanion data) {
    return ChildProfileRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      avatar: data.avatar.present ? data.avatar.value : this.avatar,
      birthDate: data.birthDate.present ? data.birthDate.value : this.birthDate,
      gradeOverride: data.gradeOverride.present
          ? data.gradeOverride.value
          : this.gradeOverride,
      pinHash: data.pinHash.present ? data.pinHash.value : this.pinHash,
      pinLength: data.pinLength.present ? data.pinLength.value : this.pinLength,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChildProfileRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('avatar: $avatar, ')
          ..write('birthDate: $birthDate, ')
          ..write('gradeOverride: $gradeOverride, ')
          ..write('pinHash: $pinHash, ')
          ..write('pinLength: $pinLength, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    avatar,
    birthDate,
    gradeOverride,
    pinHash,
    pinLength,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChildProfileRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.avatar == this.avatar &&
          other.birthDate == this.birthDate &&
          other.gradeOverride == this.gradeOverride &&
          other.pinHash == this.pinHash &&
          other.pinLength == this.pinLength &&
          other.createdAt == this.createdAt);
}

class ChildProfilesCompanion extends UpdateCompanion<ChildProfileRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> avatar;
  final Value<DateTime> birthDate;
  final Value<int?> gradeOverride;
  final Value<String?> pinHash;
  final Value<int?> pinLength;
  final Value<DateTime> createdAt;
  const ChildProfilesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.avatar = const Value.absent(),
    this.birthDate = const Value.absent(),
    this.gradeOverride = const Value.absent(),
    this.pinHash = const Value.absent(),
    this.pinLength = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ChildProfilesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String avatar,
    required DateTime birthDate,
    this.gradeOverride = const Value.absent(),
    this.pinHash = const Value.absent(),
    this.pinLength = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name),
       avatar = Value(avatar),
       birthDate = Value(birthDate);
  static Insertable<ChildProfileRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? avatar,
    Expression<DateTime>? birthDate,
    Expression<int>? gradeOverride,
    Expression<String>? pinHash,
    Expression<int>? pinLength,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (avatar != null) 'avatar': avatar,
      if (birthDate != null) 'birth_date': birthDate,
      if (gradeOverride != null) 'grade_override': gradeOverride,
      if (pinHash != null) 'pin_hash': pinHash,
      if (pinLength != null) 'pin_length': pinLength,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ChildProfilesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? avatar,
    Value<DateTime>? birthDate,
    Value<int?>? gradeOverride,
    Value<String?>? pinHash,
    Value<int?>? pinLength,
    Value<DateTime>? createdAt,
  }) {
    return ChildProfilesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      birthDate: birthDate ?? this.birthDate,
      gradeOverride: gradeOverride ?? this.gradeOverride,
      pinHash: pinHash ?? this.pinHash,
      pinLength: pinLength ?? this.pinLength,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (avatar.present) {
      map['avatar'] = Variable<String>(avatar.value);
    }
    if (birthDate.present) {
      map['birth_date'] = Variable<DateTime>(birthDate.value);
    }
    if (gradeOverride.present) {
      map['grade_override'] = Variable<int>(gradeOverride.value);
    }
    if (pinHash.present) {
      map['pin_hash'] = Variable<String>(pinHash.value);
    }
    if (pinLength.present) {
      map['pin_length'] = Variable<int>(pinLength.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChildProfilesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('avatar: $avatar, ')
          ..write('birthDate: $birthDate, ')
          ..write('gradeOverride: $gradeOverride, ')
          ..write('pinHash: $pinHash, ')
          ..write('pinLength: $pinLength, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $GuardiansTable guardians = $GuardiansTable(this);
  late final $ChildProfilesTable childProfiles = $ChildProfilesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    guardians,
    childProfiles,
  ];
}

typedef $$GuardiansTableCreateCompanionBuilder = GuardiansCompanion Function({
  Value<int> id,
  required String name,
  required String pinHash,
  required int pinLength,
});
typedef $$GuardiansTableUpdateCompanionBuilder = GuardiansCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String> pinHash,
  Value<int> pinLength,
});

class $$GuardiansTableFilterComposer
    extends Composer<_$AppDatabase, $GuardiansTable> {
  $$GuardiansTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pinHash => $composableBuilder(
    column: $table.pinHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pinLength => $composableBuilder(
    column: $table.pinLength,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GuardiansTableOrderingComposer
    extends Composer<_$AppDatabase, $GuardiansTable> {
  $$GuardiansTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pinHash => $composableBuilder(
    column: $table.pinHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pinLength => $composableBuilder(
    column: $table.pinLength,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GuardiansTableAnnotationComposer
    extends Composer<_$AppDatabase, $GuardiansTable> {
  $$GuardiansTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get pinHash =>
      $composableBuilder(column: $table.pinHash, builder: (column) => column);

  GeneratedColumn<int> get pinLength =>
      $composableBuilder(column: $table.pinLength, builder: (column) => column);
}

class $$GuardiansTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GuardiansTable,
          GuardianRow,
          $$GuardiansTableFilterComposer,
          $$GuardiansTableOrderingComposer,
          $$GuardiansTableAnnotationComposer,
          $$GuardiansTableCreateCompanionBuilder,
          $$GuardiansTableUpdateCompanionBuilder,
          (
            GuardianRow,
            BaseReferences<_$AppDatabase, $GuardiansTable, GuardianRow>,
          ),
          GuardianRow,
          PrefetchHooks Function()
        > {
  $$GuardiansTableTableManager(_$AppDatabase db, $GuardiansTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GuardiansTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GuardiansTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GuardiansTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> pinHash = const Value.absent(),
                Value<int> pinLength = const Value.absent(),
              }) => GuardiansCompanion(
                id: id,
                name: name,
                pinHash: pinHash,
                pinLength: pinLength,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String pinHash,
                required int pinLength,
              }) => GuardiansCompanion.insert(
                id: id,
                name: name,
                pinHash: pinHash,
                pinLength: pinLength,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GuardiansTable, GuardianRow>(table),
                  BaseReferences<_$AppDatabase, $GuardiansTable, GuardianRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GuardiansTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GuardiansTable,
      GuardianRow,
      $$GuardiansTableFilterComposer,
      $$GuardiansTableOrderingComposer,
      $$GuardiansTableAnnotationComposer,
      $$GuardiansTableCreateCompanionBuilder,
      $$GuardiansTableUpdateCompanionBuilder,
      (
        GuardianRow,
        BaseReferences<_$AppDatabase, $GuardiansTable, GuardianRow>,
      ),
      GuardianRow,
      PrefetchHooks Function()
    >;
typedef $$ChildProfilesTableCreateCompanionBuilder =
    ChildProfilesCompanion Function({
      Value<int> id,
      required String name,
      required String avatar,
      required DateTime birthDate,
      Value<int?> gradeOverride,
      Value<String?> pinHash,
      Value<int?> pinLength,
      Value<DateTime> createdAt,
    });
typedef $$ChildProfilesTableUpdateCompanionBuilder =
    ChildProfilesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> avatar,
      Value<DateTime> birthDate,
      Value<int?> gradeOverride,
      Value<String?> pinHash,
      Value<int?> pinLength,
      Value<DateTime> createdAt,
    });

class $$ChildProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $ChildProfilesTable> {
  $$ChildProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get avatar => $composableBuilder(
    column: $table.avatar,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get birthDate => $composableBuilder(
    column: $table.birthDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get gradeOverride => $composableBuilder(
    column: $table.gradeOverride,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pinHash => $composableBuilder(
    column: $table.pinHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pinLength => $composableBuilder(
    column: $table.pinLength,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChildProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $ChildProfilesTable> {
  $$ChildProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get avatar => $composableBuilder(
    column: $table.avatar,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get birthDate => $composableBuilder(
    column: $table.birthDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get gradeOverride => $composableBuilder(
    column: $table.gradeOverride,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pinHash => $composableBuilder(
    column: $table.pinHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pinLength => $composableBuilder(
    column: $table.pinLength,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChildProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChildProfilesTable> {
  $$ChildProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get avatar =>
      $composableBuilder(column: $table.avatar, builder: (column) => column);

  GeneratedColumn<DateTime> get birthDate =>
      $composableBuilder(column: $table.birthDate, builder: (column) => column);

  GeneratedColumn<int> get gradeOverride => $composableBuilder(
    column: $table.gradeOverride,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pinHash =>
      $composableBuilder(column: $table.pinHash, builder: (column) => column);

  GeneratedColumn<int> get pinLength =>
      $composableBuilder(column: $table.pinLength, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ChildProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChildProfilesTable,
          ChildProfileRow,
          $$ChildProfilesTableFilterComposer,
          $$ChildProfilesTableOrderingComposer,
          $$ChildProfilesTableAnnotationComposer,
          $$ChildProfilesTableCreateCompanionBuilder,
          $$ChildProfilesTableUpdateCompanionBuilder,
          (
            ChildProfileRow,
            BaseReferences<_$AppDatabase, $ChildProfilesTable, ChildProfileRow>,
          ),
          ChildProfileRow,
          PrefetchHooks Function()
        > {
  $$ChildProfilesTableTableManager(_$AppDatabase db, $ChildProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChildProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChildProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChildProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> avatar = const Value.absent(),
                Value<DateTime> birthDate = const Value.absent(),
                Value<int?> gradeOverride = const Value.absent(),
                Value<String?> pinHash = const Value.absent(),
                Value<int?> pinLength = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ChildProfilesCompanion(
                id: id,
                name: name,
                avatar: avatar,
                birthDate: birthDate,
                gradeOverride: gradeOverride,
                pinHash: pinHash,
                pinLength: pinLength,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String avatar,
                required DateTime birthDate,
                Value<int?> gradeOverride = const Value.absent(),
                Value<String?> pinHash = const Value.absent(),
                Value<int?> pinLength = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ChildProfilesCompanion.insert(
                id: id,
                name: name,
                avatar: avatar,
                birthDate: birthDate,
                gradeOverride: gradeOverride,
                pinHash: pinHash,
                pinLength: pinLength,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ChildProfilesTable, ChildProfileRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ChildProfilesTable,
                    ChildProfileRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChildProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChildProfilesTable,
      ChildProfileRow,
      $$ChildProfilesTableFilterComposer,
      $$ChildProfilesTableOrderingComposer,
      $$ChildProfilesTableAnnotationComposer,
      $$ChildProfilesTableCreateCompanionBuilder,
      $$ChildProfilesTableUpdateCompanionBuilder,
      (
        ChildProfileRow,
        BaseReferences<_$AppDatabase, $ChildProfilesTable, ChildProfileRow>,
      ),
      ChildProfileRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$GuardiansTableTableManager get guardians =>
      $$GuardiansTableTableManager(_db, _db.guardians);
  $$ChildProfilesTableTableManager get childProfiles =>
      $$ChildProfilesTableTableManager(_db, _db.childProfiles);
}

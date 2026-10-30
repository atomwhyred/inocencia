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

class $TutorMessagesTable extends TutorMessages
    with TableInfo<$TutorMessagesTable, TutorMessageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TutorMessagesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _childIdMeta = const VerificationMeta(
    'childId',
  );
  @override
  late final GeneratedColumn<int> childId = GeneratedColumn<int>(
    'child_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES child_profiles (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _fromUserMeta = const VerificationMeta(
    'fromUser',
  );
  @override
  late final GeneratedColumn<bool> fromUser = GeneratedColumn<bool>(
    'from_user',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("from_user" IN (0, 1))',
    ),
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourcesMeta = const VerificationMeta(
    'sources',
  );
  @override
  late final GeneratedColumn<String> sources = GeneratedColumn<String>(
    'sources',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
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
    childId,
    fromUser,
    content,
    sources,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tutor_messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<TutorMessageRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('child_id')) {
      context.handle(
        _childIdMeta,
        childId.isAcceptableOrUnknown(data['child_id']!, _childIdMeta),
      );
    } else if (isInserting) {
      context.missing(_childIdMeta);
    }
    if (data.containsKey('from_user')) {
      context.handle(
        _fromUserMeta,
        fromUser.isAcceptableOrUnknown(data['from_user']!, _fromUserMeta),
      );
    } else if (isInserting) {
      context.missing(_fromUserMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('sources')) {
      context.handle(
        _sourcesMeta,
        sources.isAcceptableOrUnknown(data['sources']!, _sourcesMeta),
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
  TutorMessageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TutorMessageRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      childId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}child_id'],
      )!,
      fromUser: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}from_user'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      sources: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sources'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TutorMessagesTable createAlias(String alias) {
    return $TutorMessagesTable(attachedDatabase, alias);
  }
}

class TutorMessageRow extends DataClass implements Insertable<TutorMessageRow> {
  final int id;
  final int childId;
  final bool fromUser;

  /// No se llama `text`: ese getter taparia al constructor `text()` de Drift.
  final String content;

  /// JSON `[{"subject":..,"book":..,"page":..}]` con los libros citados.
  final String sources;
  final DateTime createdAt;
  const TutorMessageRow({
    required this.id,
    required this.childId,
    required this.fromUser,
    required this.content,
    required this.sources,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['child_id'] = Variable<int>(childId);
    map['from_user'] = Variable<bool>(fromUser);
    map['content'] = Variable<String>(content);
    map['sources'] = Variable<String>(sources);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TutorMessagesCompanion toCompanion(bool nullToAbsent) {
    return TutorMessagesCompanion(
      id: Value(id),
      childId: Value(childId),
      fromUser: Value(fromUser),
      content: Value(content),
      sources: Value(sources),
      createdAt: Value(createdAt),
    );
  }

  factory TutorMessageRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TutorMessageRow(
      id: serializer.fromJson<int>(json['id']),
      childId: serializer.fromJson<int>(json['childId']),
      fromUser: serializer.fromJson<bool>(json['fromUser']),
      content: serializer.fromJson<String>(json['content']),
      sources: serializer.fromJson<String>(json['sources']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'childId': serializer.toJson<int>(childId),
      'fromUser': serializer.toJson<bool>(fromUser),
      'content': serializer.toJson<String>(content),
      'sources': serializer.toJson<String>(sources),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TutorMessageRow copyWith({
    int? id,
    int? childId,
    bool? fromUser,
    String? content,
    String? sources,
    DateTime? createdAt,
  }) => TutorMessageRow(
    id: id ?? this.id,
    childId: childId ?? this.childId,
    fromUser: fromUser ?? this.fromUser,
    content: content ?? this.content,
    sources: sources ?? this.sources,
    createdAt: createdAt ?? this.createdAt,
  );
  TutorMessageRow copyWithCompanion(TutorMessagesCompanion data) {
    return TutorMessageRow(
      id: data.id.present ? data.id.value : this.id,
      childId: data.childId.present ? data.childId.value : this.childId,
      fromUser: data.fromUser.present ? data.fromUser.value : this.fromUser,
      content: data.content.present ? data.content.value : this.content,
      sources: data.sources.present ? data.sources.value : this.sources,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TutorMessageRow(')
          ..write('id: $id, ')
          ..write('childId: $childId, ')
          ..write('fromUser: $fromUser, ')
          ..write('content: $content, ')
          ..write('sources: $sources, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, childId, fromUser, content, sources, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TutorMessageRow &&
          other.id == this.id &&
          other.childId == this.childId &&
          other.fromUser == this.fromUser &&
          other.content == this.content &&
          other.sources == this.sources &&
          other.createdAt == this.createdAt);
}

class TutorMessagesCompanion extends UpdateCompanion<TutorMessageRow> {
  final Value<int> id;
  final Value<int> childId;
  final Value<bool> fromUser;
  final Value<String> content;
  final Value<String> sources;
  final Value<DateTime> createdAt;
  const TutorMessagesCompanion({
    this.id = const Value.absent(),
    this.childId = const Value.absent(),
    this.fromUser = const Value.absent(),
    this.content = const Value.absent(),
    this.sources = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  TutorMessagesCompanion.insert({
    this.id = const Value.absent(),
    required int childId,
    required bool fromUser,
    required String content,
    this.sources = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : childId = Value(childId),
       fromUser = Value(fromUser),
       content = Value(content);
  static Insertable<TutorMessageRow> custom({
    Expression<int>? id,
    Expression<int>? childId,
    Expression<bool>? fromUser,
    Expression<String>? content,
    Expression<String>? sources,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (childId != null) 'child_id': childId,
      if (fromUser != null) 'from_user': fromUser,
      if (content != null) 'content': content,
      if (sources != null) 'sources': sources,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  TutorMessagesCompanion copyWith({
    Value<int>? id,
    Value<int>? childId,
    Value<bool>? fromUser,
    Value<String>? content,
    Value<String>? sources,
    Value<DateTime>? createdAt,
  }) {
    return TutorMessagesCompanion(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      fromUser: fromUser ?? this.fromUser,
      content: content ?? this.content,
      sources: sources ?? this.sources,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (childId.present) {
      map['child_id'] = Variable<int>(childId.value);
    }
    if (fromUser.present) {
      map['from_user'] = Variable<bool>(fromUser.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (sources.present) {
      map['sources'] = Variable<String>(sources.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TutorMessagesCompanion(')
          ..write('id: $id, ')
          ..write('childId: $childId, ')
          ..write('fromUser: $fromUser, ')
          ..write('content: $content, ')
          ..write('sources: $sources, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $ReadingProgressTable extends ReadingProgress
    with TableInfo<$ReadingProgressTable, ReadingProgressRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadingProgressTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _childIdMeta = const VerificationMeta(
    'childId',
  );
  @override
  late final GeneratedColumn<int> childId = GeneratedColumn<int>(
    'child_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES child_profiles (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _bookMeta = const VerificationMeta('book');
  @override
  late final GeneratedColumn<String> book = GeneratedColumn<String>(
    'book',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pageMeta = const VerificationMeta('page');
  @override
  late final GeneratedColumn<int> page = GeneratedColumn<int>(
    'page',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, childId, book, page, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reading_progress';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReadingProgressRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('child_id')) {
      context.handle(
        _childIdMeta,
        childId.isAcceptableOrUnknown(data['child_id']!, _childIdMeta),
      );
    } else if (isInserting) {
      context.missing(_childIdMeta);
    }
    if (data.containsKey('book')) {
      context.handle(
        _bookMeta,
        book.isAcceptableOrUnknown(data['book']!, _bookMeta),
      );
    } else if (isInserting) {
      context.missing(_bookMeta);
    }
    if (data.containsKey('page')) {
      context.handle(
        _pageMeta,
        page.isAcceptableOrUnknown(data['page']!, _pageMeta),
      );
    } else if (isInserting) {
      context.missing(_pageMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {childId, book},
  ];
  @override
  ReadingProgressRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReadingProgressRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      childId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}child_id'],
      )!,
      book: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book'],
      )!,
      page: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ReadingProgressTable createAlias(String alias) {
    return $ReadingProgressTable(attachedDatabase, alias);
  }
}

class ReadingProgressRow extends DataClass
    implements Insertable<ReadingProgressRow> {
  final int id;
  final int childId;

  /// Nombre del PDF sin extension, igual que `chunks.book` (`6to_matematica`).
  final String book;

  /// Pagina del PDF contando desde 1, igual que `chunks.page`.
  final int page;
  final DateTime updatedAt;
  const ReadingProgressRow({
    required this.id,
    required this.childId,
    required this.book,
    required this.page,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['child_id'] = Variable<int>(childId);
    map['book'] = Variable<String>(book);
    map['page'] = Variable<int>(page);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ReadingProgressCompanion toCompanion(bool nullToAbsent) {
    return ReadingProgressCompanion(
      id: Value(id),
      childId: Value(childId),
      book: Value(book),
      page: Value(page),
      updatedAt: Value(updatedAt),
    );
  }

  factory ReadingProgressRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReadingProgressRow(
      id: serializer.fromJson<int>(json['id']),
      childId: serializer.fromJson<int>(json['childId']),
      book: serializer.fromJson<String>(json['book']),
      page: serializer.fromJson<int>(json['page']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'childId': serializer.toJson<int>(childId),
      'book': serializer.toJson<String>(book),
      'page': serializer.toJson<int>(page),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ReadingProgressRow copyWith({
    int? id,
    int? childId,
    String? book,
    int? page,
    DateTime? updatedAt,
  }) => ReadingProgressRow(
    id: id ?? this.id,
    childId: childId ?? this.childId,
    book: book ?? this.book,
    page: page ?? this.page,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ReadingProgressRow copyWithCompanion(ReadingProgressCompanion data) {
    return ReadingProgressRow(
      id: data.id.present ? data.id.value : this.id,
      childId: data.childId.present ? data.childId.value : this.childId,
      book: data.book.present ? data.book.value : this.book,
      page: data.page.present ? data.page.value : this.page,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReadingProgressRow(')
          ..write('id: $id, ')
          ..write('childId: $childId, ')
          ..write('book: $book, ')
          ..write('page: $page, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, childId, book, page, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadingProgressRow &&
          other.id == this.id &&
          other.childId == this.childId &&
          other.book == this.book &&
          other.page == this.page &&
          other.updatedAt == this.updatedAt);
}

class ReadingProgressCompanion extends UpdateCompanion<ReadingProgressRow> {
  final Value<int> id;
  final Value<int> childId;
  final Value<String> book;
  final Value<int> page;
  final Value<DateTime> updatedAt;
  const ReadingProgressCompanion({
    this.id = const Value.absent(),
    this.childId = const Value.absent(),
    this.book = const Value.absent(),
    this.page = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ReadingProgressCompanion.insert({
    this.id = const Value.absent(),
    required int childId,
    required String book,
    required int page,
    this.updatedAt = const Value.absent(),
  }) : childId = Value(childId),
       book = Value(book),
       page = Value(page);
  static Insertable<ReadingProgressRow> custom({
    Expression<int>? id,
    Expression<int>? childId,
    Expression<String>? book,
    Expression<int>? page,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (childId != null) 'child_id': childId,
      if (book != null) 'book': book,
      if (page != null) 'page': page,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ReadingProgressCompanion copyWith({
    Value<int>? id,
    Value<int>? childId,
    Value<String>? book,
    Value<int>? page,
    Value<DateTime>? updatedAt,
  }) {
    return ReadingProgressCompanion(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      book: book ?? this.book,
      page: page ?? this.page,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (childId.present) {
      map['child_id'] = Variable<int>(childId.value);
    }
    if (book.present) {
      map['book'] = Variable<String>(book.value);
    }
    if (page.present) {
      map['page'] = Variable<int>(page.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReadingProgressCompanion(')
          ..write('id: $id, ')
          ..write('childId: $childId, ')
          ..write('book: $book, ')
          ..write('page: $page, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $AchievementsTable extends Achievements
    with TableInfo<$AchievementsTable, AchievementRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AchievementsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _childIdMeta = const VerificationMeta(
    'childId',
  );
  @override
  late final GeneratedColumn<int> childId = GeneratedColumn<int>(
    'child_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES child_profiles (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _earnedAtMeta = const VerificationMeta(
    'earnedAt',
  );
  @override
  late final GeneratedColumn<DateTime> earnedAt = GeneratedColumn<DateTime>(
    'earned_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, childId, code, earnedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'achievements';
  @override
  VerificationContext validateIntegrity(
    Insertable<AchievementRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('child_id')) {
      context.handle(
        _childIdMeta,
        childId.isAcceptableOrUnknown(data['child_id']!, _childIdMeta),
      );
    } else if (isInserting) {
      context.missing(_childIdMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('earned_at')) {
      context.handle(
        _earnedAtMeta,
        earnedAt.isAcceptableOrUnknown(data['earned_at']!, _earnedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {childId, code},
  ];
  @override
  AchievementRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AchievementRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      childId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}child_id'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      earnedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}earned_at'],
      )!,
    );
  }

  @override
  $AchievementsTable createAlias(String alias) {
    return $AchievementsTable(attachedDatabase, alias);
  }
}

class AchievementRow extends DataClass implements Insertable<AchievementRow> {
  final int id;
  final int childId;
  final String code;
  final DateTime earnedAt;
  const AchievementRow({
    required this.id,
    required this.childId,
    required this.code,
    required this.earnedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['child_id'] = Variable<int>(childId);
    map['code'] = Variable<String>(code);
    map['earned_at'] = Variable<DateTime>(earnedAt);
    return map;
  }

  AchievementsCompanion toCompanion(bool nullToAbsent) {
    return AchievementsCompanion(
      id: Value(id),
      childId: Value(childId),
      code: Value(code),
      earnedAt: Value(earnedAt),
    );
  }

  factory AchievementRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AchievementRow(
      id: serializer.fromJson<int>(json['id']),
      childId: serializer.fromJson<int>(json['childId']),
      code: serializer.fromJson<String>(json['code']),
      earnedAt: serializer.fromJson<DateTime>(json['earnedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'childId': serializer.toJson<int>(childId),
      'code': serializer.toJson<String>(code),
      'earnedAt': serializer.toJson<DateTime>(earnedAt),
    };
  }

  AchievementRow copyWith({
    int? id,
    int? childId,
    String? code,
    DateTime? earnedAt,
  }) => AchievementRow(
    id: id ?? this.id,
    childId: childId ?? this.childId,
    code: code ?? this.code,
    earnedAt: earnedAt ?? this.earnedAt,
  );
  AchievementRow copyWithCompanion(AchievementsCompanion data) {
    return AchievementRow(
      id: data.id.present ? data.id.value : this.id,
      childId: data.childId.present ? data.childId.value : this.childId,
      code: data.code.present ? data.code.value : this.code,
      earnedAt: data.earnedAt.present ? data.earnedAt.value : this.earnedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AchievementRow(')
          ..write('id: $id, ')
          ..write('childId: $childId, ')
          ..write('code: $code, ')
          ..write('earnedAt: $earnedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, childId, code, earnedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AchievementRow &&
          other.id == this.id &&
          other.childId == this.childId &&
          other.code == this.code &&
          other.earnedAt == this.earnedAt);
}

class AchievementsCompanion extends UpdateCompanion<AchievementRow> {
  final Value<int> id;
  final Value<int> childId;
  final Value<String> code;
  final Value<DateTime> earnedAt;
  const AchievementsCompanion({
    this.id = const Value.absent(),
    this.childId = const Value.absent(),
    this.code = const Value.absent(),
    this.earnedAt = const Value.absent(),
  });
  AchievementsCompanion.insert({
    this.id = const Value.absent(),
    required int childId,
    required String code,
    this.earnedAt = const Value.absent(),
  }) : childId = Value(childId),
       code = Value(code);
  static Insertable<AchievementRow> custom({
    Expression<int>? id,
    Expression<int>? childId,
    Expression<String>? code,
    Expression<DateTime>? earnedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (childId != null) 'child_id': childId,
      if (code != null) 'code': code,
      if (earnedAt != null) 'earned_at': earnedAt,
    });
  }

  AchievementsCompanion copyWith({
    Value<int>? id,
    Value<int>? childId,
    Value<String>? code,
    Value<DateTime>? earnedAt,
  }) {
    return AchievementsCompanion(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      code: code ?? this.code,
      earnedAt: earnedAt ?? this.earnedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (childId.present) {
      map['child_id'] = Variable<int>(childId.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (earnedAt.present) {
      map['earned_at'] = Variable<DateTime>(earnedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AchievementsCompanion(')
          ..write('id: $id, ')
          ..write('childId: $childId, ')
          ..write('code: $code, ')
          ..write('earnedAt: $earnedAt')
          ..write(')'))
        .toString();
  }
}

class $ChildCountersTable extends ChildCounters
    with TableInfo<$ChildCountersTable, ChildCounterRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChildCountersTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _childIdMeta = const VerificationMeta(
    'childId',
  );
  @override
  late final GeneratedColumn<int> childId = GeneratedColumn<int>(
    'child_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES child_profiles (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _counterMeta = const VerificationMeta(
    'counter',
  );
  @override
  late final GeneratedColumn<String> counter = GeneratedColumn<String>(
    'counter',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<int> amount = GeneratedColumn<int>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [id, childId, counter, amount];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'child_counters';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChildCounterRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('child_id')) {
      context.handle(
        _childIdMeta,
        childId.isAcceptableOrUnknown(data['child_id']!, _childIdMeta),
      );
    } else if (isInserting) {
      context.missing(_childIdMeta);
    }
    if (data.containsKey('counter')) {
      context.handle(
        _counterMeta,
        counter.isAcceptableOrUnknown(data['counter']!, _counterMeta),
      );
    } else if (isInserting) {
      context.missing(_counterMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {childId, counter},
  ];
  @override
  ChildCounterRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChildCounterRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      childId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}child_id'],
      )!,
      counter: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}counter'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount'],
      )!,
    );
  }

  @override
  $ChildCountersTable createAlias(String alias) {
    return $ChildCountersTable(attachedDatabase, alias);
  }
}

class ChildCounterRow extends DataClass implements Insertable<ChildCounterRow> {
  final int id;
  final int childId;
  final String counter;
  final int amount;
  const ChildCounterRow({
    required this.id,
    required this.childId,
    required this.counter,
    required this.amount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['child_id'] = Variable<int>(childId);
    map['counter'] = Variable<String>(counter);
    map['amount'] = Variable<int>(amount);
    return map;
  }

  ChildCountersCompanion toCompanion(bool nullToAbsent) {
    return ChildCountersCompanion(
      id: Value(id),
      childId: Value(childId),
      counter: Value(counter),
      amount: Value(amount),
    );
  }

  factory ChildCounterRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChildCounterRow(
      id: serializer.fromJson<int>(json['id']),
      childId: serializer.fromJson<int>(json['childId']),
      counter: serializer.fromJson<String>(json['counter']),
      amount: serializer.fromJson<int>(json['amount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'childId': serializer.toJson<int>(childId),
      'counter': serializer.toJson<String>(counter),
      'amount': serializer.toJson<int>(amount),
    };
  }

  ChildCounterRow copyWith({
    int? id,
    int? childId,
    String? counter,
    int? amount,
  }) => ChildCounterRow(
    id: id ?? this.id,
    childId: childId ?? this.childId,
    counter: counter ?? this.counter,
    amount: amount ?? this.amount,
  );
  ChildCounterRow copyWithCompanion(ChildCountersCompanion data) {
    return ChildCounterRow(
      id: data.id.present ? data.id.value : this.id,
      childId: data.childId.present ? data.childId.value : this.childId,
      counter: data.counter.present ? data.counter.value : this.counter,
      amount: data.amount.present ? data.amount.value : this.amount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChildCounterRow(')
          ..write('id: $id, ')
          ..write('childId: $childId, ')
          ..write('counter: $counter, ')
          ..write('amount: $amount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, childId, counter, amount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChildCounterRow &&
          other.id == this.id &&
          other.childId == this.childId &&
          other.counter == this.counter &&
          other.amount == this.amount);
}

class ChildCountersCompanion extends UpdateCompanion<ChildCounterRow> {
  final Value<int> id;
  final Value<int> childId;
  final Value<String> counter;
  final Value<int> amount;
  const ChildCountersCompanion({
    this.id = const Value.absent(),
    this.childId = const Value.absent(),
    this.counter = const Value.absent(),
    this.amount = const Value.absent(),
  });
  ChildCountersCompanion.insert({
    this.id = const Value.absent(),
    required int childId,
    required String counter,
    this.amount = const Value.absent(),
  }) : childId = Value(childId),
       counter = Value(counter);
  static Insertable<ChildCounterRow> custom({
    Expression<int>? id,
    Expression<int>? childId,
    Expression<String>? counter,
    Expression<int>? amount,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (childId != null) 'child_id': childId,
      if (counter != null) 'counter': counter,
      if (amount != null) 'amount': amount,
    });
  }

  ChildCountersCompanion copyWith({
    Value<int>? id,
    Value<int>? childId,
    Value<String>? counter,
    Value<int>? amount,
  }) {
    return ChildCountersCompanion(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      counter: counter ?? this.counter,
      amount: amount ?? this.amount,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (childId.present) {
      map['child_id'] = Variable<int>(childId.value);
    }
    if (counter.present) {
      map['counter'] = Variable<String>(counter.value);
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChildCountersCompanion(')
          ..write('id: $id, ')
          ..write('childId: $childId, ')
          ..write('counter: $counter, ')
          ..write('amount: $amount')
          ..write(')'))
        .toString();
  }
}

class $FlashcardsTable extends Flashcards
    with TableInfo<$FlashcardsTable, FlashcardRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FlashcardsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _childIdMeta = const VerificationMeta(
    'childId',
  );
  @override
  late final GeneratedColumn<int> childId = GeneratedColumn<int>(
    'child_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES child_profiles (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _frontMeta = const VerificationMeta('front');
  @override
  late final GeneratedColumn<String> front = GeneratedColumn<String>(
    'front',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _backMeta = const VerificationMeta('back');
  @override
  late final GeneratedColumn<String> back = GeneratedColumn<String>(
    'back',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
  static const VerificationMeta _timesKnownMeta = const VerificationMeta(
    'timesKnown',
  );
  @override
  late final GeneratedColumn<int> timesKnown = GeneratedColumn<int>(
    'times_known',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _timesReviewedMeta = const VerificationMeta(
    'timesReviewed',
  );
  @override
  late final GeneratedColumn<int> timesReviewed = GeneratedColumn<int>(
    'times_reviewed',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastReviewedAtMeta = const VerificationMeta(
    'lastReviewedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastReviewedAt =
      GeneratedColumn<DateTime>(
        'last_reviewed_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    childId,
    front,
    back,
    source,
    createdAt,
    timesKnown,
    timesReviewed,
    lastReviewedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'flashcards';
  @override
  VerificationContext validateIntegrity(
    Insertable<FlashcardRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('child_id')) {
      context.handle(
        _childIdMeta,
        childId.isAcceptableOrUnknown(data['child_id']!, _childIdMeta),
      );
    } else if (isInserting) {
      context.missing(_childIdMeta);
    }
    if (data.containsKey('front')) {
      context.handle(
        _frontMeta,
        front.isAcceptableOrUnknown(data['front']!, _frontMeta),
      );
    } else if (isInserting) {
      context.missing(_frontMeta);
    }
    if (data.containsKey('back')) {
      context.handle(
        _backMeta,
        back.isAcceptableOrUnknown(data['back']!, _backMeta),
      );
    } else if (isInserting) {
      context.missing(_backMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('times_known')) {
      context.handle(
        _timesKnownMeta,
        timesKnown.isAcceptableOrUnknown(data['times_known']!, _timesKnownMeta),
      );
    }
    if (data.containsKey('times_reviewed')) {
      context.handle(
        _timesReviewedMeta,
        timesReviewed.isAcceptableOrUnknown(
          data['times_reviewed']!,
          _timesReviewedMeta,
        ),
      );
    }
    if (data.containsKey('last_reviewed_at')) {
      context.handle(
        _lastReviewedAtMeta,
        lastReviewedAt.isAcceptableOrUnknown(
          data['last_reviewed_at']!,
          _lastReviewedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {childId, front},
  ];
  @override
  FlashcardRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FlashcardRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      childId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}child_id'],
      )!,
      front: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}front'],
      )!,
      back: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}back'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      timesKnown: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}times_known'],
      )!,
      timesReviewed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}times_reviewed'],
      )!,
      lastReviewedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_reviewed_at'],
      ),
    );
  }

  @override
  $FlashcardsTable createAlias(String alias) {
    return $FlashcardsTable(attachedDatabase, alias);
  }
}

class FlashcardRow extends DataClass implements Insertable<FlashcardRow> {
  final int id;
  final int childId;
  final String front;
  final String back;

  /// Libro y pagina de donde sale (`Español · 2do_lengua · pág. 138`).
  final String? source;
  final DateTime createdAt;
  final int timesKnown;
  final int timesReviewed;
  final DateTime? lastReviewedAt;
  const FlashcardRow({
    required this.id,
    required this.childId,
    required this.front,
    required this.back,
    this.source,
    required this.createdAt,
    required this.timesKnown,
    required this.timesReviewed,
    this.lastReviewedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['child_id'] = Variable<int>(childId);
    map['front'] = Variable<String>(front);
    map['back'] = Variable<String>(back);
    if (!nullToAbsent || source != null) {
      map['source'] = Variable<String>(source);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['times_known'] = Variable<int>(timesKnown);
    map['times_reviewed'] = Variable<int>(timesReviewed);
    if (!nullToAbsent || lastReviewedAt != null) {
      map['last_reviewed_at'] = Variable<DateTime>(lastReviewedAt);
    }
    return map;
  }

  FlashcardsCompanion toCompanion(bool nullToAbsent) {
    return FlashcardsCompanion(
      id: Value(id),
      childId: Value(childId),
      front: Value(front),
      back: Value(back),
      source: source == null && nullToAbsent
          ? const Value.absent()
          : Value(source),
      createdAt: Value(createdAt),
      timesKnown: Value(timesKnown),
      timesReviewed: Value(timesReviewed),
      lastReviewedAt: lastReviewedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastReviewedAt),
    );
  }

  factory FlashcardRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FlashcardRow(
      id: serializer.fromJson<int>(json['id']),
      childId: serializer.fromJson<int>(json['childId']),
      front: serializer.fromJson<String>(json['front']),
      back: serializer.fromJson<String>(json['back']),
      source: serializer.fromJson<String?>(json['source']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      timesKnown: serializer.fromJson<int>(json['timesKnown']),
      timesReviewed: serializer.fromJson<int>(json['timesReviewed']),
      lastReviewedAt: serializer.fromJson<DateTime?>(json['lastReviewedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'childId': serializer.toJson<int>(childId),
      'front': serializer.toJson<String>(front),
      'back': serializer.toJson<String>(back),
      'source': serializer.toJson<String?>(source),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'timesKnown': serializer.toJson<int>(timesKnown),
      'timesReviewed': serializer.toJson<int>(timesReviewed),
      'lastReviewedAt': serializer.toJson<DateTime?>(lastReviewedAt),
    };
  }

  FlashcardRow copyWith({
    int? id,
    int? childId,
    String? front,
    String? back,
    Value<String?> source = const Value.absent(),
    DateTime? createdAt,
    int? timesKnown,
    int? timesReviewed,
    Value<DateTime?> lastReviewedAt = const Value.absent(),
  }) => FlashcardRow(
    id: id ?? this.id,
    childId: childId ?? this.childId,
    front: front ?? this.front,
    back: back ?? this.back,
    source: source.present ? source.value : this.source,
    createdAt: createdAt ?? this.createdAt,
    timesKnown: timesKnown ?? this.timesKnown,
    timesReviewed: timesReviewed ?? this.timesReviewed,
    lastReviewedAt: lastReviewedAt.present
        ? lastReviewedAt.value
        : this.lastReviewedAt,
  );
  FlashcardRow copyWithCompanion(FlashcardsCompanion data) {
    return FlashcardRow(
      id: data.id.present ? data.id.value : this.id,
      childId: data.childId.present ? data.childId.value : this.childId,
      front: data.front.present ? data.front.value : this.front,
      back: data.back.present ? data.back.value : this.back,
      source: data.source.present ? data.source.value : this.source,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      timesKnown: data.timesKnown.present
          ? data.timesKnown.value
          : this.timesKnown,
      timesReviewed: data.timesReviewed.present
          ? data.timesReviewed.value
          : this.timesReviewed,
      lastReviewedAt: data.lastReviewedAt.present
          ? data.lastReviewedAt.value
          : this.lastReviewedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FlashcardRow(')
          ..write('id: $id, ')
          ..write('childId: $childId, ')
          ..write('front: $front, ')
          ..write('back: $back, ')
          ..write('source: $source, ')
          ..write('createdAt: $createdAt, ')
          ..write('timesKnown: $timesKnown, ')
          ..write('timesReviewed: $timesReviewed, ')
          ..write('lastReviewedAt: $lastReviewedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    childId,
    front,
    back,
    source,
    createdAt,
    timesKnown,
    timesReviewed,
    lastReviewedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FlashcardRow &&
          other.id == this.id &&
          other.childId == this.childId &&
          other.front == this.front &&
          other.back == this.back &&
          other.source == this.source &&
          other.createdAt == this.createdAt &&
          other.timesKnown == this.timesKnown &&
          other.timesReviewed == this.timesReviewed &&
          other.lastReviewedAt == this.lastReviewedAt);
}

class FlashcardsCompanion extends UpdateCompanion<FlashcardRow> {
  final Value<int> id;
  final Value<int> childId;
  final Value<String> front;
  final Value<String> back;
  final Value<String?> source;
  final Value<DateTime> createdAt;
  final Value<int> timesKnown;
  final Value<int> timesReviewed;
  final Value<DateTime?> lastReviewedAt;
  const FlashcardsCompanion({
    this.id = const Value.absent(),
    this.childId = const Value.absent(),
    this.front = const Value.absent(),
    this.back = const Value.absent(),
    this.source = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.timesKnown = const Value.absent(),
    this.timesReviewed = const Value.absent(),
    this.lastReviewedAt = const Value.absent(),
  });
  FlashcardsCompanion.insert({
    this.id = const Value.absent(),
    required int childId,
    required String front,
    required String back,
    this.source = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.timesKnown = const Value.absent(),
    this.timesReviewed = const Value.absent(),
    this.lastReviewedAt = const Value.absent(),
  }) : childId = Value(childId),
       front = Value(front),
       back = Value(back);
  static Insertable<FlashcardRow> custom({
    Expression<int>? id,
    Expression<int>? childId,
    Expression<String>? front,
    Expression<String>? back,
    Expression<String>? source,
    Expression<DateTime>? createdAt,
    Expression<int>? timesKnown,
    Expression<int>? timesReviewed,
    Expression<DateTime>? lastReviewedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (childId != null) 'child_id': childId,
      if (front != null) 'front': front,
      if (back != null) 'back': back,
      if (source != null) 'source': source,
      if (createdAt != null) 'created_at': createdAt,
      if (timesKnown != null) 'times_known': timesKnown,
      if (timesReviewed != null) 'times_reviewed': timesReviewed,
      if (lastReviewedAt != null) 'last_reviewed_at': lastReviewedAt,
    });
  }

  FlashcardsCompanion copyWith({
    Value<int>? id,
    Value<int>? childId,
    Value<String>? front,
    Value<String>? back,
    Value<String?>? source,
    Value<DateTime>? createdAt,
    Value<int>? timesKnown,
    Value<int>? timesReviewed,
    Value<DateTime?>? lastReviewedAt,
  }) {
    return FlashcardsCompanion(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      front: front ?? this.front,
      back: back ?? this.back,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      timesKnown: timesKnown ?? this.timesKnown,
      timesReviewed: timesReviewed ?? this.timesReviewed,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (childId.present) {
      map['child_id'] = Variable<int>(childId.value);
    }
    if (front.present) {
      map['front'] = Variable<String>(front.value);
    }
    if (back.present) {
      map['back'] = Variable<String>(back.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (timesKnown.present) {
      map['times_known'] = Variable<int>(timesKnown.value);
    }
    if (timesReviewed.present) {
      map['times_reviewed'] = Variable<int>(timesReviewed.value);
    }
    if (lastReviewedAt.present) {
      map['last_reviewed_at'] = Variable<DateTime>(lastReviewedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FlashcardsCompanion(')
          ..write('id: $id, ')
          ..write('childId: $childId, ')
          ..write('front: $front, ')
          ..write('back: $back, ')
          ..write('source: $source, ')
          ..write('createdAt: $createdAt, ')
          ..write('timesKnown: $timesKnown, ')
          ..write('timesReviewed: $timesReviewed, ')
          ..write('lastReviewedAt: $lastReviewedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $GuardiansTable guardians = $GuardiansTable(this);
  late final $ChildProfilesTable childProfiles = $ChildProfilesTable(this);
  late final $TutorMessagesTable tutorMessages = $TutorMessagesTable(this);
  late final $ReadingProgressTable readingProgress = $ReadingProgressTable(
    this,
  );
  late final $AchievementsTable achievements = $AchievementsTable(this);
  late final $ChildCountersTable childCounters = $ChildCountersTable(this);
  late final $FlashcardsTable flashcards = $FlashcardsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    guardians,
    childProfiles,
    tutorMessages,
    readingProgress,
    achievements,
    childCounters,
    flashcards,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'child_profiles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('tutor_messages', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'child_profiles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('reading_progress', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'child_profiles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('achievements', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'child_profiles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('child_counters', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'child_profiles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('flashcards', kind: UpdateKind.delete)],
    ),
  ]);
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

final class $$ChildProfilesTableReferences
    extends
        BaseReferences<_$AppDatabase, $ChildProfilesTable, ChildProfileRow> {
  $$ChildProfilesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$TutorMessagesTable, List<TutorMessageRow>>
  _tutorMessagesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.tutorMessages,
    aliasName: 'child_profiles__id__tutor_messages__child_id',
  );

  $$TutorMessagesTableProcessedTableManager get tutorMessagesRefs {
    final manager = $$TutorMessagesTableTableManager(
      $_db,
      $_db.tutorMessages,
    ).filter((f) => f.childId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_tutorMessagesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ReadingProgressTable, List<ReadingProgressRow>>
  _readingProgressRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.readingProgress,
    aliasName: 'child_profiles__id__reading_progress__child_id',
  );

  $$ReadingProgressTableProcessedTableManager get readingProgressRefs {
    final manager = $$ReadingProgressTableTableManager(
      $_db,
      $_db.readingProgress,
    ).filter((f) => f.childId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _readingProgressRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AchievementsTable, List<AchievementRow>>
  _achievementsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.achievements,
    aliasName: 'child_profiles__id__achievements__child_id',
  );

  $$AchievementsTableProcessedTableManager get achievementsRefs {
    final manager = $$AchievementsTableTableManager(
      $_db,
      $_db.achievements,
    ).filter((f) => f.childId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_achievementsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ChildCountersTable, List<ChildCounterRow>>
  _childCountersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.childCounters,
    aliasName: 'child_profiles__id__child_counters__child_id',
  );

  $$ChildCountersTableProcessedTableManager get childCountersRefs {
    final manager = $$ChildCountersTableTableManager(
      $_db,
      $_db.childCounters,
    ).filter((f) => f.childId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_childCountersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$FlashcardsTable, List<FlashcardRow>>
  _flashcardsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.flashcards,
    aliasName: 'child_profiles__id__flashcards__child_id',
  );

  $$FlashcardsTableProcessedTableManager get flashcardsRefs {
    final manager = $$FlashcardsTableTableManager(
      $_db,
      $_db.flashcards,
    ).filter((f) => f.childId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_flashcardsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

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

  Expression<bool> tutorMessagesRefs(
    Expression<bool> Function($$TutorMessagesTableFilterComposer f) f,
  ) {
    final $$TutorMessagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tutorMessages,
      getReferencedColumn: (t) => t.childId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TutorMessagesTableFilterComposer(
            $db: $db,
            $table: $db.tutorMessages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> readingProgressRefs(
    Expression<bool> Function($$ReadingProgressTableFilterComposer f) f,
  ) {
    final $$ReadingProgressTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.readingProgress,
      getReferencedColumn: (t) => t.childId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReadingProgressTableFilterComposer(
            $db: $db,
            $table: $db.readingProgress,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> achievementsRefs(
    Expression<bool> Function($$AchievementsTableFilterComposer f) f,
  ) {
    final $$AchievementsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.achievements,
      getReferencedColumn: (t) => t.childId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AchievementsTableFilterComposer(
            $db: $db,
            $table: $db.achievements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> childCountersRefs(
    Expression<bool> Function($$ChildCountersTableFilterComposer f) f,
  ) {
    final $$ChildCountersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.childCounters,
      getReferencedColumn: (t) => t.childId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChildCountersTableFilterComposer(
            $db: $db,
            $table: $db.childCounters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> flashcardsRefs(
    Expression<bool> Function($$FlashcardsTableFilterComposer f) f,
  ) {
    final $$FlashcardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.flashcards,
      getReferencedColumn: (t) => t.childId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FlashcardsTableFilterComposer(
            $db: $db,
            $table: $db.flashcards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
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

  Expression<T> tutorMessagesRefs<T extends Object>(
    Expression<T> Function($$TutorMessagesTableAnnotationComposer a) f,
  ) {
    final $$TutorMessagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tutorMessages,
      getReferencedColumn: (t) => t.childId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TutorMessagesTableAnnotationComposer(
            $db: $db,
            $table: $db.tutorMessages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> readingProgressRefs<T extends Object>(
    Expression<T> Function($$ReadingProgressTableAnnotationComposer a) f,
  ) {
    final $$ReadingProgressTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.readingProgress,
      getReferencedColumn: (t) => t.childId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReadingProgressTableAnnotationComposer(
            $db: $db,
            $table: $db.readingProgress,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> achievementsRefs<T extends Object>(
    Expression<T> Function($$AchievementsTableAnnotationComposer a) f,
  ) {
    final $$AchievementsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.achievements,
      getReferencedColumn: (t) => t.childId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AchievementsTableAnnotationComposer(
            $db: $db,
            $table: $db.achievements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> childCountersRefs<T extends Object>(
    Expression<T> Function($$ChildCountersTableAnnotationComposer a) f,
  ) {
    final $$ChildCountersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.childCounters,
      getReferencedColumn: (t) => t.childId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChildCountersTableAnnotationComposer(
            $db: $db,
            $table: $db.childCounters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> flashcardsRefs<T extends Object>(
    Expression<T> Function($$FlashcardsTableAnnotationComposer a) f,
  ) {
    final $$FlashcardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.flashcards,
      getReferencedColumn: (t) => t.childId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FlashcardsTableAnnotationComposer(
            $db: $db,
            $table: $db.flashcards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
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
          (ChildProfileRow, $$ChildProfilesTableReferences),
          ChildProfileRow,
          PrefetchHooks Function({
            bool tutorMessagesRefs,
            bool readingProgressRefs,
            bool achievementsRefs,
            bool childCountersRefs,
            bool flashcardsRefs,
          })
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
                  $$ChildProfilesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                tutorMessagesRefs = false,
                readingProgressRefs = false,
                achievementsRefs = false,
                childCountersRefs = false,
                flashcardsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (tutorMessagesRefs) db.tutorMessages,
                    if (readingProgressRefs) db.readingProgress,
                    if (achievementsRefs) db.achievements,
                    if (childCountersRefs) db.childCounters,
                    if (flashcardsRefs) db.flashcards,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (tutorMessagesRefs)
                        await $_getPrefetchedDataByColumns<
                          ChildProfileRow,
                          $ChildProfilesTable,
                          TutorMessageRow,
                          $TutorMessagesTable
                        >(
                          currentTable: table,
                          referencedTable: $$ChildProfilesTableReferences
                              ._tutorMessagesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ChildProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).tutorMessagesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'child_id',
                          typedResults: items,
                        ),
                      if (readingProgressRefs)
                        await $_getPrefetchedDataByColumns<
                          ChildProfileRow,
                          $ChildProfilesTable,
                          ReadingProgressRow,
                          $ReadingProgressTable
                        >(
                          currentTable: table,
                          referencedTable: $$ChildProfilesTableReferences
                              ._readingProgressRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ChildProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).readingProgressRefs,
                          currentColumn: 'id',
                          referencedColumn: 'child_id',
                          typedResults: items,
                        ),
                      if (achievementsRefs)
                        await $_getPrefetchedDataByColumns<
                          ChildProfileRow,
                          $ChildProfilesTable,
                          AchievementRow,
                          $AchievementsTable
                        >(
                          currentTable: table,
                          referencedTable: $$ChildProfilesTableReferences
                              ._achievementsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ChildProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).achievementsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'child_id',
                          typedResults: items,
                        ),
                      if (childCountersRefs)
                        await $_getPrefetchedDataByColumns<
                          ChildProfileRow,
                          $ChildProfilesTable,
                          ChildCounterRow,
                          $ChildCountersTable
                        >(
                          currentTable: table,
                          referencedTable: $$ChildProfilesTableReferences
                              ._childCountersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ChildProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).childCountersRefs,
                          currentColumn: 'id',
                          referencedColumn: 'child_id',
                          typedResults: items,
                        ),
                      if (flashcardsRefs)
                        await $_getPrefetchedDataByColumns<
                          ChildProfileRow,
                          $ChildProfilesTable,
                          FlashcardRow,
                          $FlashcardsTable
                        >(
                          currentTable: table,
                          referencedTable: $$ChildProfilesTableReferences
                              ._flashcardsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ChildProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).flashcardsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'child_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
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
      (ChildProfileRow, $$ChildProfilesTableReferences),
      ChildProfileRow,
      PrefetchHooks Function({
        bool tutorMessagesRefs,
        bool readingProgressRefs,
        bool achievementsRefs,
        bool childCountersRefs,
        bool flashcardsRefs,
      })
    >;
typedef $$TutorMessagesTableCreateCompanionBuilder =
    TutorMessagesCompanion Function({
      Value<int> id,
      required int childId,
      required bool fromUser,
      required String content,
      Value<String> sources,
      Value<DateTime> createdAt,
    });
typedef $$TutorMessagesTableUpdateCompanionBuilder =
    TutorMessagesCompanion Function({
      Value<int> id,
      Value<int> childId,
      Value<bool> fromUser,
      Value<String> content,
      Value<String> sources,
      Value<DateTime> createdAt,
    });

final class $$TutorMessagesTableReferences
    extends
        BaseReferences<_$AppDatabase, $TutorMessagesTable, TutorMessageRow> {
  $$TutorMessagesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ChildProfilesTable _childIdTable(_$AppDatabase db) => db.childProfiles
      .createAlias('tutor_messages__child_id__child_profiles__id');

  $$ChildProfilesTableProcessedTableManager get childId {
    final $_column = $_itemColumn<int>('child_id')!;

    final manager = $$ChildProfilesTableTableManager(
      $_db,
      $_db.childProfiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_childIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TutorMessagesTableFilterComposer
    extends Composer<_$AppDatabase, $TutorMessagesTable> {
  $$TutorMessagesTableFilterComposer({
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

  ColumnFilters<bool> get fromUser => $composableBuilder(
    column: $table.fromUser,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sources => $composableBuilder(
    column: $table.sources,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ChildProfilesTableFilterComposer get childId {
    final $$ChildProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childId,
      referencedTable: $db.childProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChildProfilesTableFilterComposer(
            $db: $db,
            $table: $db.childProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TutorMessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $TutorMessagesTable> {
  $$TutorMessagesTableOrderingComposer({
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

  ColumnOrderings<bool> get fromUser => $composableBuilder(
    column: $table.fromUser,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sources => $composableBuilder(
    column: $table.sources,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ChildProfilesTableOrderingComposer get childId {
    final $$ChildProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childId,
      referencedTable: $db.childProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChildProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.childProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TutorMessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TutorMessagesTable> {
  $$TutorMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get fromUser =>
      $composableBuilder(column: $table.fromUser, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get sources =>
      $composableBuilder(column: $table.sources, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ChildProfilesTableAnnotationComposer get childId {
    final $$ChildProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childId,
      referencedTable: $db.childProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChildProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.childProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TutorMessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TutorMessagesTable,
          TutorMessageRow,
          $$TutorMessagesTableFilterComposer,
          $$TutorMessagesTableOrderingComposer,
          $$TutorMessagesTableAnnotationComposer,
          $$TutorMessagesTableCreateCompanionBuilder,
          $$TutorMessagesTableUpdateCompanionBuilder,
          (TutorMessageRow, $$TutorMessagesTableReferences),
          TutorMessageRow,
          PrefetchHooks Function({bool childId})
        > {
  $$TutorMessagesTableTableManager(_$AppDatabase db, $TutorMessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TutorMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TutorMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TutorMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> childId = const Value.absent(),
                Value<bool> fromUser = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> sources = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => TutorMessagesCompanion(
                id: id,
                childId: childId,
                fromUser: fromUser,
                content: content,
                sources: sources,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int childId,
                required bool fromUser,
                required String content,
                Value<String> sources = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => TutorMessagesCompanion.insert(
                id: id,
                childId: childId,
                fromUser: fromUser,
                content: content,
                sources: sources,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TutorMessagesTable, TutorMessageRow>(table),
                  $$TutorMessagesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({childId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
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
                      dynamic
                    >
                  >(state) {
                    if (childId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.childId,
                        referencedTable: $$TutorMessagesTableReferences
                            ._childIdTable(db),
                        referencedColumn: $$TutorMessagesTableReferences
                            ._childIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TutorMessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TutorMessagesTable,
      TutorMessageRow,
      $$TutorMessagesTableFilterComposer,
      $$TutorMessagesTableOrderingComposer,
      $$TutorMessagesTableAnnotationComposer,
      $$TutorMessagesTableCreateCompanionBuilder,
      $$TutorMessagesTableUpdateCompanionBuilder,
      (TutorMessageRow, $$TutorMessagesTableReferences),
      TutorMessageRow,
      PrefetchHooks Function({bool childId})
    >;
typedef $$ReadingProgressTableCreateCompanionBuilder =
    ReadingProgressCompanion Function({
      Value<int> id,
      required int childId,
      required String book,
      required int page,
      Value<DateTime> updatedAt,
    });
typedef $$ReadingProgressTableUpdateCompanionBuilder =
    ReadingProgressCompanion Function({
      Value<int> id,
      Value<int> childId,
      Value<String> book,
      Value<int> page,
      Value<DateTime> updatedAt,
    });

final class $$ReadingProgressTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ReadingProgressTable,
          ReadingProgressRow
        > {
  $$ReadingProgressTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ChildProfilesTable _childIdTable(_$AppDatabase db) => db.childProfiles
      .createAlias('reading_progress__child_id__child_profiles__id');

  $$ChildProfilesTableProcessedTableManager get childId {
    final $_column = $_itemColumn<int>('child_id')!;

    final manager = $$ChildProfilesTableTableManager(
      $_db,
      $_db.childProfiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_childIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ReadingProgressTableFilterComposer
    extends Composer<_$AppDatabase, $ReadingProgressTable> {
  $$ReadingProgressTableFilterComposer({
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

  ColumnFilters<String> get book => $composableBuilder(
    column: $table.book,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get page => $composableBuilder(
    column: $table.page,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ChildProfilesTableFilterComposer get childId {
    final $$ChildProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childId,
      referencedTable: $db.childProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChildProfilesTableFilterComposer(
            $db: $db,
            $table: $db.childProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReadingProgressTableOrderingComposer
    extends Composer<_$AppDatabase, $ReadingProgressTable> {
  $$ReadingProgressTableOrderingComposer({
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

  ColumnOrderings<String> get book => $composableBuilder(
    column: $table.book,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get page => $composableBuilder(
    column: $table.page,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ChildProfilesTableOrderingComposer get childId {
    final $$ChildProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childId,
      referencedTable: $db.childProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChildProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.childProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReadingProgressTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReadingProgressTable> {
  $$ReadingProgressTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get book =>
      $composableBuilder(column: $table.book, builder: (column) => column);

  GeneratedColumn<int> get page =>
      $composableBuilder(column: $table.page, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ChildProfilesTableAnnotationComposer get childId {
    final $$ChildProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childId,
      referencedTable: $db.childProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChildProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.childProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReadingProgressTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReadingProgressTable,
          ReadingProgressRow,
          $$ReadingProgressTableFilterComposer,
          $$ReadingProgressTableOrderingComposer,
          $$ReadingProgressTableAnnotationComposer,
          $$ReadingProgressTableCreateCompanionBuilder,
          $$ReadingProgressTableUpdateCompanionBuilder,
          (ReadingProgressRow, $$ReadingProgressTableReferences),
          ReadingProgressRow,
          PrefetchHooks Function({bool childId})
        > {
  $$ReadingProgressTableTableManager(
    _$AppDatabase db,
    $ReadingProgressTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReadingProgressTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReadingProgressTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReadingProgressTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> childId = const Value.absent(),
                Value<String> book = const Value.absent(),
                Value<int> page = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ReadingProgressCompanion(
                id: id,
                childId: childId,
                book: book,
                page: page,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int childId,
                required String book,
                required int page,
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ReadingProgressCompanion.insert(
                id: id,
                childId: childId,
                book: book,
                page: page,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReadingProgressTable, ReadingProgressRow>(table),
                  $$ReadingProgressTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({childId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
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
                      dynamic
                    >
                  >(state) {
                    if (childId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.childId,
                        referencedTable: $$ReadingProgressTableReferences
                            ._childIdTable(db),
                        referencedColumn: $$ReadingProgressTableReferences
                            ._childIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ReadingProgressTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReadingProgressTable,
      ReadingProgressRow,
      $$ReadingProgressTableFilterComposer,
      $$ReadingProgressTableOrderingComposer,
      $$ReadingProgressTableAnnotationComposer,
      $$ReadingProgressTableCreateCompanionBuilder,
      $$ReadingProgressTableUpdateCompanionBuilder,
      (ReadingProgressRow, $$ReadingProgressTableReferences),
      ReadingProgressRow,
      PrefetchHooks Function({bool childId})
    >;
typedef $$AchievementsTableCreateCompanionBuilder =
    AchievementsCompanion Function({
      Value<int> id,
      required int childId,
      required String code,
      Value<DateTime> earnedAt,
    });
typedef $$AchievementsTableUpdateCompanionBuilder =
    AchievementsCompanion Function({
      Value<int> id,
      Value<int> childId,
      Value<String> code,
      Value<DateTime> earnedAt,
    });

final class $$AchievementsTableReferences
    extends BaseReferences<_$AppDatabase, $AchievementsTable, AchievementRow> {
  $$AchievementsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ChildProfilesTable _childIdTable(_$AppDatabase db) => db.childProfiles
      .createAlias('achievements__child_id__child_profiles__id');

  $$ChildProfilesTableProcessedTableManager get childId {
    final $_column = $_itemColumn<int>('child_id')!;

    final manager = $$ChildProfilesTableTableManager(
      $_db,
      $_db.childProfiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_childIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AchievementsTableFilterComposer
    extends Composer<_$AppDatabase, $AchievementsTable> {
  $$AchievementsTableFilterComposer({
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

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get earnedAt => $composableBuilder(
    column: $table.earnedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ChildProfilesTableFilterComposer get childId {
    final $$ChildProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childId,
      referencedTable: $db.childProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChildProfilesTableFilterComposer(
            $db: $db,
            $table: $db.childProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AchievementsTableOrderingComposer
    extends Composer<_$AppDatabase, $AchievementsTable> {
  $$AchievementsTableOrderingComposer({
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

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get earnedAt => $composableBuilder(
    column: $table.earnedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ChildProfilesTableOrderingComposer get childId {
    final $$ChildProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childId,
      referencedTable: $db.childProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChildProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.childProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AchievementsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AchievementsTable> {
  $$AchievementsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<DateTime> get earnedAt =>
      $composableBuilder(column: $table.earnedAt, builder: (column) => column);

  $$ChildProfilesTableAnnotationComposer get childId {
    final $$ChildProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childId,
      referencedTable: $db.childProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChildProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.childProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AchievementsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AchievementsTable,
          AchievementRow,
          $$AchievementsTableFilterComposer,
          $$AchievementsTableOrderingComposer,
          $$AchievementsTableAnnotationComposer,
          $$AchievementsTableCreateCompanionBuilder,
          $$AchievementsTableUpdateCompanionBuilder,
          (AchievementRow, $$AchievementsTableReferences),
          AchievementRow,
          PrefetchHooks Function({bool childId})
        > {
  $$AchievementsTableTableManager(_$AppDatabase db, $AchievementsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AchievementsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AchievementsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AchievementsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> childId = const Value.absent(),
                Value<String> code = const Value.absent(),
                Value<DateTime> earnedAt = const Value.absent(),
              }) => AchievementsCompanion(
                id: id,
                childId: childId,
                code: code,
                earnedAt: earnedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int childId,
                required String code,
                Value<DateTime> earnedAt = const Value.absent(),
              }) => AchievementsCompanion.insert(
                id: id,
                childId: childId,
                code: code,
                earnedAt: earnedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AchievementsTable, AchievementRow>(table),
                  $$AchievementsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({childId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
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
                      dynamic
                    >
                  >(state) {
                    if (childId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.childId,
                        referencedTable: $$AchievementsTableReferences
                            ._childIdTable(db),
                        referencedColumn: $$AchievementsTableReferences
                            ._childIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AchievementsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AchievementsTable,
      AchievementRow,
      $$AchievementsTableFilterComposer,
      $$AchievementsTableOrderingComposer,
      $$AchievementsTableAnnotationComposer,
      $$AchievementsTableCreateCompanionBuilder,
      $$AchievementsTableUpdateCompanionBuilder,
      (AchievementRow, $$AchievementsTableReferences),
      AchievementRow,
      PrefetchHooks Function({bool childId})
    >;
typedef $$ChildCountersTableCreateCompanionBuilder =
    ChildCountersCompanion Function({
      Value<int> id,
      required int childId,
      required String counter,
      Value<int> amount,
    });
typedef $$ChildCountersTableUpdateCompanionBuilder =
    ChildCountersCompanion Function({
      Value<int> id,
      Value<int> childId,
      Value<String> counter,
      Value<int> amount,
    });

final class $$ChildCountersTableReferences
    extends
        BaseReferences<_$AppDatabase, $ChildCountersTable, ChildCounterRow> {
  $$ChildCountersTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ChildProfilesTable _childIdTable(_$AppDatabase db) => db.childProfiles
      .createAlias('child_counters__child_id__child_profiles__id');

  $$ChildProfilesTableProcessedTableManager get childId {
    final $_column = $_itemColumn<int>('child_id')!;

    final manager = $$ChildProfilesTableTableManager(
      $_db,
      $_db.childProfiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_childIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ChildCountersTableFilterComposer
    extends Composer<_$AppDatabase, $ChildCountersTable> {
  $$ChildCountersTableFilterComposer({
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

  ColumnFilters<String> get counter => $composableBuilder(
    column: $table.counter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  $$ChildProfilesTableFilterComposer get childId {
    final $$ChildProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childId,
      referencedTable: $db.childProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChildProfilesTableFilterComposer(
            $db: $db,
            $table: $db.childProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChildCountersTableOrderingComposer
    extends Composer<_$AppDatabase, $ChildCountersTable> {
  $$ChildCountersTableOrderingComposer({
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

  ColumnOrderings<String> get counter => $composableBuilder(
    column: $table.counter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  $$ChildProfilesTableOrderingComposer get childId {
    final $$ChildProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childId,
      referencedTable: $db.childProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChildProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.childProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChildCountersTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChildCountersTable> {
  $$ChildCountersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get counter =>
      $composableBuilder(column: $table.counter, builder: (column) => column);

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  $$ChildProfilesTableAnnotationComposer get childId {
    final $$ChildProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childId,
      referencedTable: $db.childProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChildProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.childProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChildCountersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChildCountersTable,
          ChildCounterRow,
          $$ChildCountersTableFilterComposer,
          $$ChildCountersTableOrderingComposer,
          $$ChildCountersTableAnnotationComposer,
          $$ChildCountersTableCreateCompanionBuilder,
          $$ChildCountersTableUpdateCompanionBuilder,
          (ChildCounterRow, $$ChildCountersTableReferences),
          ChildCounterRow,
          PrefetchHooks Function({bool childId})
        > {
  $$ChildCountersTableTableManager(_$AppDatabase db, $ChildCountersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChildCountersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChildCountersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChildCountersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> childId = const Value.absent(),
                Value<String> counter = const Value.absent(),
                Value<int> amount = const Value.absent(),
              }) => ChildCountersCompanion(
                id: id,
                childId: childId,
                counter: counter,
                amount: amount,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int childId,
                required String counter,
                Value<int> amount = const Value.absent(),
              }) => ChildCountersCompanion.insert(
                id: id,
                childId: childId,
                counter: counter,
                amount: amount,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ChildCountersTable, ChildCounterRow>(table),
                  $$ChildCountersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({childId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
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
                      dynamic
                    >
                  >(state) {
                    if (childId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.childId,
                        referencedTable: $$ChildCountersTableReferences
                            ._childIdTable(db),
                        referencedColumn: $$ChildCountersTableReferences
                            ._childIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ChildCountersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChildCountersTable,
      ChildCounterRow,
      $$ChildCountersTableFilterComposer,
      $$ChildCountersTableOrderingComposer,
      $$ChildCountersTableAnnotationComposer,
      $$ChildCountersTableCreateCompanionBuilder,
      $$ChildCountersTableUpdateCompanionBuilder,
      (ChildCounterRow, $$ChildCountersTableReferences),
      ChildCounterRow,
      PrefetchHooks Function({bool childId})
    >;
typedef $$FlashcardsTableCreateCompanionBuilder = FlashcardsCompanion Function({
  Value<int> id,
  required int childId,
  required String front,
  required String back,
  Value<String?> source,
  Value<DateTime> createdAt,
  Value<int> timesKnown,
  Value<int> timesReviewed,
  Value<DateTime?> lastReviewedAt,
});
typedef $$FlashcardsTableUpdateCompanionBuilder = FlashcardsCompanion Function({
  Value<int> id,
  Value<int> childId,
  Value<String> front,
  Value<String> back,
  Value<String?> source,
  Value<DateTime> createdAt,
  Value<int> timesKnown,
  Value<int> timesReviewed,
  Value<DateTime?> lastReviewedAt,
});

final class $$FlashcardsTableReferences
    extends BaseReferences<_$AppDatabase, $FlashcardsTable, FlashcardRow> {
  $$FlashcardsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ChildProfilesTable _childIdTable(_$AppDatabase db) =>
      db.childProfiles.createAlias('flashcards__child_id__child_profiles__id');

  $$ChildProfilesTableProcessedTableManager get childId {
    final $_column = $_itemColumn<int>('child_id')!;

    final manager = $$ChildProfilesTableTableManager(
      $_db,
      $_db.childProfiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_childIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FlashcardsTableFilterComposer
    extends Composer<_$AppDatabase, $FlashcardsTable> {
  $$FlashcardsTableFilterComposer({
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

  ColumnFilters<String> get front => $composableBuilder(
    column: $table.front,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get back => $composableBuilder(
    column: $table.back,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timesKnown => $composableBuilder(
    column: $table.timesKnown,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timesReviewed => $composableBuilder(
    column: $table.timesReviewed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastReviewedAt => $composableBuilder(
    column: $table.lastReviewedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ChildProfilesTableFilterComposer get childId {
    final $$ChildProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childId,
      referencedTable: $db.childProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChildProfilesTableFilterComposer(
            $db: $db,
            $table: $db.childProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FlashcardsTableOrderingComposer
    extends Composer<_$AppDatabase, $FlashcardsTable> {
  $$FlashcardsTableOrderingComposer({
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

  ColumnOrderings<String> get front => $composableBuilder(
    column: $table.front,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get back => $composableBuilder(
    column: $table.back,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timesKnown => $composableBuilder(
    column: $table.timesKnown,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timesReviewed => $composableBuilder(
    column: $table.timesReviewed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastReviewedAt => $composableBuilder(
    column: $table.lastReviewedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ChildProfilesTableOrderingComposer get childId {
    final $$ChildProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childId,
      referencedTable: $db.childProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChildProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.childProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FlashcardsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FlashcardsTable> {
  $$FlashcardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get front =>
      $composableBuilder(column: $table.front, builder: (column) => column);

  GeneratedColumn<String> get back =>
      $composableBuilder(column: $table.back, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get timesKnown => $composableBuilder(
    column: $table.timesKnown,
    builder: (column) => column,
  );

  GeneratedColumn<int> get timesReviewed => $composableBuilder(
    column: $table.timesReviewed,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastReviewedAt => $composableBuilder(
    column: $table.lastReviewedAt,
    builder: (column) => column,
  );

  $$ChildProfilesTableAnnotationComposer get childId {
    final $$ChildProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childId,
      referencedTable: $db.childProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChildProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.childProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FlashcardsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FlashcardsTable,
          FlashcardRow,
          $$FlashcardsTableFilterComposer,
          $$FlashcardsTableOrderingComposer,
          $$FlashcardsTableAnnotationComposer,
          $$FlashcardsTableCreateCompanionBuilder,
          $$FlashcardsTableUpdateCompanionBuilder,
          (FlashcardRow, $$FlashcardsTableReferences),
          FlashcardRow,
          PrefetchHooks Function({bool childId})
        > {
  $$FlashcardsTableTableManager(_$AppDatabase db, $FlashcardsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FlashcardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FlashcardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FlashcardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> childId = const Value.absent(),
                Value<String> front = const Value.absent(),
                Value<String> back = const Value.absent(),
                Value<String?> source = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> timesKnown = const Value.absent(),
                Value<int> timesReviewed = const Value.absent(),
                Value<DateTime?> lastReviewedAt = const Value.absent(),
              }) => FlashcardsCompanion(
                id: id,
                childId: childId,
                front: front,
                back: back,
                source: source,
                createdAt: createdAt,
                timesKnown: timesKnown,
                timesReviewed: timesReviewed,
                lastReviewedAt: lastReviewedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int childId,
                required String front,
                required String back,
                Value<String?> source = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> timesKnown = const Value.absent(),
                Value<int> timesReviewed = const Value.absent(),
                Value<DateTime?> lastReviewedAt = const Value.absent(),
              }) => FlashcardsCompanion.insert(
                id: id,
                childId: childId,
                front: front,
                back: back,
                source: source,
                createdAt: createdAt,
                timesKnown: timesKnown,
                timesReviewed: timesReviewed,
                lastReviewedAt: lastReviewedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FlashcardsTable, FlashcardRow>(table),
                  $$FlashcardsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({childId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
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
                      dynamic
                    >
                  >(state) {
                    if (childId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.childId,
                        referencedTable: $$FlashcardsTableReferences
                            ._childIdTable(db),
                        referencedColumn: $$FlashcardsTableReferences
                            ._childIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$FlashcardsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FlashcardsTable,
      FlashcardRow,
      $$FlashcardsTableFilterComposer,
      $$FlashcardsTableOrderingComposer,
      $$FlashcardsTableAnnotationComposer,
      $$FlashcardsTableCreateCompanionBuilder,
      $$FlashcardsTableUpdateCompanionBuilder,
      (FlashcardRow, $$FlashcardsTableReferences),
      FlashcardRow,
      PrefetchHooks Function({bool childId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$GuardiansTableTableManager get guardians =>
      $$GuardiansTableTableManager(_db, _db.guardians);
  $$ChildProfilesTableTableManager get childProfiles =>
      $$ChildProfilesTableTableManager(_db, _db.childProfiles);
  $$TutorMessagesTableTableManager get tutorMessages =>
      $$TutorMessagesTableTableManager(_db, _db.tutorMessages);
  $$ReadingProgressTableTableManager get readingProgress =>
      $$ReadingProgressTableTableManager(_db, _db.readingProgress);
  $$AchievementsTableTableManager get achievements =>
      $$AchievementsTableTableManager(_db, _db.achievements);
  $$ChildCountersTableTableManager get childCounters =>
      $$ChildCountersTableTableManager(_db, _db.childCounters);
  $$FlashcardsTableTableManager get flashcards =>
      $$FlashcardsTableTableManager(_db, _db.flashcards);
}

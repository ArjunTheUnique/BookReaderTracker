// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'm1_library_store.dart';

// ignore_for_file: type=lint
class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, Category> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [categoryId, name, position];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<Category> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {categoryId};
  @override
  Category map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Category(
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }
}

class Category extends DataClass implements Insertable<Category> {
  final String categoryId;
  final String name;
  final int position;
  const Category({
    required this.categoryId,
    required this.name,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['category_id'] = Variable<String>(categoryId);
    map['name'] = Variable<String>(name);
    map['position'] = Variable<int>(position);
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      categoryId: Value(categoryId),
      name: Value(name),
      position: Value(position),
    );
  }

  factory Category.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Category(
      categoryId: serializer.fromJson<String>(json['categoryId']),
      name: serializer.fromJson<String>(json['name']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'categoryId': serializer.toJson<String>(categoryId),
      'name': serializer.toJson<String>(name),
      'position': serializer.toJson<int>(position),
    };
  }

  Category copyWith({String? categoryId, String? name, int? position}) =>
      Category(
        categoryId: categoryId ?? this.categoryId,
        name: name ?? this.name,
        position: position ?? this.position,
      );
  Category copyWithCompanion(CategoriesCompanion data) {
    return Category(
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      name: data.name.present ? data.name.value : this.name,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Category(')
          ..write('categoryId: $categoryId, ')
          ..write('name: $name, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(categoryId, name, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Category &&
          other.categoryId == this.categoryId &&
          other.name == this.name &&
          other.position == this.position);
}

class CategoriesCompanion extends UpdateCompanion<Category> {
  final Value<String> categoryId;
  final Value<String> name;
  final Value<int> position;
  final Value<int> rowid;
  const CategoriesCompanion({
    this.categoryId = const Value.absent(),
    this.name = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoriesCompanion.insert({
    required String categoryId,
    required String name,
    required int position,
    this.rowid = const Value.absent(),
  }) : categoryId = Value(categoryId),
       name = Value(name),
       position = Value(position);
  static Insertable<Category> custom({
    Expression<String>? categoryId,
    Expression<String>? name,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (categoryId != null) 'category_id': categoryId,
      if (name != null) 'name': name,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoriesCompanion copyWith({
    Value<String>? categoryId,
    Value<String>? name,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return CategoriesCompanion(
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('categoryId: $categoryId, ')
          ..write('name: $name, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BooksTable extends Books with TableInfo<$BooksTable, Book> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BooksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalPagesMeta = const VerificationMeta(
    'totalPages',
  );
  @override
  late final GeneratedColumn<int> totalPages = GeneratedColumn<int>(
    'total_pages',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverRefMeta = const VerificationMeta(
    'coverRef',
  );
  @override
  late final GeneratedColumn<String> coverRef = GeneratedColumn<String>(
    'cover_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    bookId,
    categoryId,
    title,
    totalPages,
    source,
    filePath,
    coverRef,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'books';
  @override
  VerificationContext validateIntegrity(
    Insertable<Book> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('total_pages')) {
      context.handle(
        _totalPagesMeta,
        totalPages.isAcceptableOrUnknown(data['total_pages']!, _totalPagesMeta),
      );
    } else if (isInserting) {
      context.missing(_totalPagesMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    }
    if (data.containsKey('cover_ref')) {
      context.handle(
        _coverRefMeta,
        coverRef.isAcceptableOrUnknown(data['cover_ref']!, _coverRefMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookId};
  @override
  Book map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Book(
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      totalPages: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_pages'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      ),
      coverRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_ref'],
      ),
    );
  }

  @override
  $BooksTable createAlias(String alias) {
    return $BooksTable(attachedDatabase, alias);
  }
}

class Book extends DataClass implements Insertable<Book> {
  final String bookId;
  final String categoryId;
  final String title;
  final int totalPages;
  final String source;
  final String? filePath;
  final String? coverRef;
  const Book({
    required this.bookId,
    required this.categoryId,
    required this.title,
    required this.totalPages,
    required this.source,
    this.filePath,
    this.coverRef,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_id'] = Variable<String>(bookId);
    map['category_id'] = Variable<String>(categoryId);
    map['title'] = Variable<String>(title);
    map['total_pages'] = Variable<int>(totalPages);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || filePath != null) {
      map['file_path'] = Variable<String>(filePath);
    }
    if (!nullToAbsent || coverRef != null) {
      map['cover_ref'] = Variable<String>(coverRef);
    }
    return map;
  }

  BooksCompanion toCompanion(bool nullToAbsent) {
    return BooksCompanion(
      bookId: Value(bookId),
      categoryId: Value(categoryId),
      title: Value(title),
      totalPages: Value(totalPages),
      source: Value(source),
      filePath: filePath == null && nullToAbsent
          ? const Value.absent()
          : Value(filePath),
      coverRef: coverRef == null && nullToAbsent
          ? const Value.absent()
          : Value(coverRef),
    );
  }

  factory Book.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Book(
      bookId: serializer.fromJson<String>(json['bookId']),
      categoryId: serializer.fromJson<String>(json['categoryId']),
      title: serializer.fromJson<String>(json['title']),
      totalPages: serializer.fromJson<int>(json['totalPages']),
      source: serializer.fromJson<String>(json['source']),
      filePath: serializer.fromJson<String?>(json['filePath']),
      coverRef: serializer.fromJson<String?>(json['coverRef']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookId': serializer.toJson<String>(bookId),
      'categoryId': serializer.toJson<String>(categoryId),
      'title': serializer.toJson<String>(title),
      'totalPages': serializer.toJson<int>(totalPages),
      'source': serializer.toJson<String>(source),
      'filePath': serializer.toJson<String?>(filePath),
      'coverRef': serializer.toJson<String?>(coverRef),
    };
  }

  Book copyWith({
    String? bookId,
    String? categoryId,
    String? title,
    int? totalPages,
    String? source,
    Value<String?> filePath = const Value.absent(),
    Value<String?> coverRef = const Value.absent(),
  }) => Book(
    bookId: bookId ?? this.bookId,
    categoryId: categoryId ?? this.categoryId,
    title: title ?? this.title,
    totalPages: totalPages ?? this.totalPages,
    source: source ?? this.source,
    filePath: filePath.present ? filePath.value : this.filePath,
    coverRef: coverRef.present ? coverRef.value : this.coverRef,
  );
  Book copyWithCompanion(BooksCompanion data) {
    return Book(
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      title: data.title.present ? data.title.value : this.title,
      totalPages: data.totalPages.present
          ? data.totalPages.value
          : this.totalPages,
      source: data.source.present ? data.source.value : this.source,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      coverRef: data.coverRef.present ? data.coverRef.value : this.coverRef,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Book(')
          ..write('bookId: $bookId, ')
          ..write('categoryId: $categoryId, ')
          ..write('title: $title, ')
          ..write('totalPages: $totalPages, ')
          ..write('source: $source, ')
          ..write('filePath: $filePath, ')
          ..write('coverRef: $coverRef')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    bookId,
    categoryId,
    title,
    totalPages,
    source,
    filePath,
    coverRef,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Book &&
          other.bookId == this.bookId &&
          other.categoryId == this.categoryId &&
          other.title == this.title &&
          other.totalPages == this.totalPages &&
          other.source == this.source &&
          other.filePath == this.filePath &&
          other.coverRef == this.coverRef);
}

class BooksCompanion extends UpdateCompanion<Book> {
  final Value<String> bookId;
  final Value<String> categoryId;
  final Value<String> title;
  final Value<int> totalPages;
  final Value<String> source;
  final Value<String?> filePath;
  final Value<String?> coverRef;
  final Value<int> rowid;
  const BooksCompanion({
    this.bookId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.title = const Value.absent(),
    this.totalPages = const Value.absent(),
    this.source = const Value.absent(),
    this.filePath = const Value.absent(),
    this.coverRef = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BooksCompanion.insert({
    required String bookId,
    required String categoryId,
    required String title,
    required int totalPages,
    required String source,
    this.filePath = const Value.absent(),
    this.coverRef = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : bookId = Value(bookId),
       categoryId = Value(categoryId),
       title = Value(title),
       totalPages = Value(totalPages),
       source = Value(source);
  static Insertable<Book> custom({
    Expression<String>? bookId,
    Expression<String>? categoryId,
    Expression<String>? title,
    Expression<int>? totalPages,
    Expression<String>? source,
    Expression<String>? filePath,
    Expression<String>? coverRef,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookId != null) 'book_id': bookId,
      if (categoryId != null) 'category_id': categoryId,
      if (title != null) 'title': title,
      if (totalPages != null) 'total_pages': totalPages,
      if (source != null) 'source': source,
      if (filePath != null) 'file_path': filePath,
      if (coverRef != null) 'cover_ref': coverRef,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BooksCompanion copyWith({
    Value<String>? bookId,
    Value<String>? categoryId,
    Value<String>? title,
    Value<int>? totalPages,
    Value<String>? source,
    Value<String?>? filePath,
    Value<String?>? coverRef,
    Value<int>? rowid,
  }) {
    return BooksCompanion(
      bookId: bookId ?? this.bookId,
      categoryId: categoryId ?? this.categoryId,
      title: title ?? this.title,
      totalPages: totalPages ?? this.totalPages,
      source: source ?? this.source,
      filePath: filePath ?? this.filePath,
      coverRef: coverRef ?? this.coverRef,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (totalPages.present) {
      map['total_pages'] = Variable<int>(totalPages.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (coverRef.present) {
      map['cover_ref'] = Variable<String>(coverRef.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BooksCompanion(')
          ..write('bookId: $bookId, ')
          ..write('categoryId: $categoryId, ')
          ..write('title: $title, ')
          ..write('totalPages: $totalPages, ')
          ..write('source: $source, ')
          ..write('filePath: $filePath, ')
          ..write('coverRef: $coverRef, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProgressLogTable extends ProgressLog
    with TableInfo<$ProgressLogTable, ProgressLogData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProgressLogTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currentPageMeta = const VerificationMeta(
    'currentPage',
  );
  @override
  late final GeneratedColumn<int> currentPage = GeneratedColumn<int>(
    'current_page',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _readOnMeta = const VerificationMeta('readOn');
  @override
  late final GeneratedColumn<String> readOn = GeneratedColumn<String>(
    'read_on',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idempotencyKeyMeta = const VerificationMeta(
    'idempotencyKey',
  );
  @override
  late final GeneratedColumn<String> idempotencyKey = GeneratedColumn<String>(
    'idempotency_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
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
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    currentPage,
    readOn,
    idempotencyKey,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'progress_log';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProgressLogData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('current_page')) {
      context.handle(
        _currentPageMeta,
        currentPage.isAcceptableOrUnknown(
          data['current_page']!,
          _currentPageMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currentPageMeta);
    }
    if (data.containsKey('read_on')) {
      context.handle(
        _readOnMeta,
        readOn.isAcceptableOrUnknown(data['read_on']!, _readOnMeta),
      );
    } else if (isInserting) {
      context.missing(_readOnMeta);
    }
    if (data.containsKey('idempotency_key')) {
      context.handle(
        _idempotencyKeyMeta,
        idempotencyKey.isAcceptableOrUnknown(
          data['idempotency_key']!,
          _idempotencyKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_idempotencyKeyMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProgressLogData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProgressLogData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      currentPage: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_page'],
      )!,
      readOn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}read_on'],
      )!,
      idempotencyKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}idempotency_key'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ProgressLogTable createAlias(String alias) {
    return $ProgressLogTable(attachedDatabase, alias);
  }
}

class ProgressLogData extends DataClass implements Insertable<ProgressLogData> {
  final int id;
  final String bookId;
  final int currentPage;
  final String readOn;
  final String idempotencyKey;
  final DateTime createdAt;
  const ProgressLogData({
    required this.id,
    required this.bookId,
    required this.currentPage,
    required this.readOn,
    required this.idempotencyKey,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['book_id'] = Variable<String>(bookId);
    map['current_page'] = Variable<int>(currentPage);
    map['read_on'] = Variable<String>(readOn);
    map['idempotency_key'] = Variable<String>(idempotencyKey);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ProgressLogCompanion toCompanion(bool nullToAbsent) {
    return ProgressLogCompanion(
      id: Value(id),
      bookId: Value(bookId),
      currentPage: Value(currentPage),
      readOn: Value(readOn),
      idempotencyKey: Value(idempotencyKey),
      createdAt: Value(createdAt),
    );
  }

  factory ProgressLogData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProgressLogData(
      id: serializer.fromJson<int>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      currentPage: serializer.fromJson<int>(json['currentPage']),
      readOn: serializer.fromJson<String>(json['readOn']),
      idempotencyKey: serializer.fromJson<String>(json['idempotencyKey']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'bookId': serializer.toJson<String>(bookId),
      'currentPage': serializer.toJson<int>(currentPage),
      'readOn': serializer.toJson<String>(readOn),
      'idempotencyKey': serializer.toJson<String>(idempotencyKey),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ProgressLogData copyWith({
    int? id,
    String? bookId,
    int? currentPage,
    String? readOn,
    String? idempotencyKey,
    DateTime? createdAt,
  }) => ProgressLogData(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    currentPage: currentPage ?? this.currentPage,
    readOn: readOn ?? this.readOn,
    idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    createdAt: createdAt ?? this.createdAt,
  );
  ProgressLogData copyWithCompanion(ProgressLogCompanion data) {
    return ProgressLogData(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      currentPage: data.currentPage.present
          ? data.currentPage.value
          : this.currentPage,
      readOn: data.readOn.present ? data.readOn.value : this.readOn,
      idempotencyKey: data.idempotencyKey.present
          ? data.idempotencyKey.value
          : this.idempotencyKey,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProgressLogData(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('currentPage: $currentPage, ')
          ..write('readOn: $readOn, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, bookId, currentPage, readOn, idempotencyKey, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProgressLogData &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.currentPage == this.currentPage &&
          other.readOn == this.readOn &&
          other.idempotencyKey == this.idempotencyKey &&
          other.createdAt == this.createdAt);
}

class ProgressLogCompanion extends UpdateCompanion<ProgressLogData> {
  final Value<int> id;
  final Value<String> bookId;
  final Value<int> currentPage;
  final Value<String> readOn;
  final Value<String> idempotencyKey;
  final Value<DateTime> createdAt;
  const ProgressLogCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.currentPage = const Value.absent(),
    this.readOn = const Value.absent(),
    this.idempotencyKey = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ProgressLogCompanion.insert({
    this.id = const Value.absent(),
    required String bookId,
    required int currentPage,
    required String readOn,
    required String idempotencyKey,
    required DateTime createdAt,
  }) : bookId = Value(bookId),
       currentPage = Value(currentPage),
       readOn = Value(readOn),
       idempotencyKey = Value(idempotencyKey),
       createdAt = Value(createdAt);
  static Insertable<ProgressLogData> custom({
    Expression<int>? id,
    Expression<String>? bookId,
    Expression<int>? currentPage,
    Expression<String>? readOn,
    Expression<String>? idempotencyKey,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (currentPage != null) 'current_page': currentPage,
      if (readOn != null) 'read_on': readOn,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ProgressLogCompanion copyWith({
    Value<int>? id,
    Value<String>? bookId,
    Value<int>? currentPage,
    Value<String>? readOn,
    Value<String>? idempotencyKey,
    Value<DateTime>? createdAt,
  }) {
    return ProgressLogCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      currentPage: currentPage ?? this.currentPage,
      readOn: readOn ?? this.readOn,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (currentPage.present) {
      map['current_page'] = Variable<int>(currentPage.value);
    }
    if (readOn.present) {
      map['read_on'] = Variable<String>(readOn.value);
    }
    if (idempotencyKey.present) {
      map['idempotency_key'] = Variable<String>(idempotencyKey.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProgressLogCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('currentPage: $currentPage, ')
          ..write('readOn: $readOn, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $DailySummaryTable extends DailySummary
    with TableInfo<$DailySummaryTable, DailySummaryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailySummaryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pagesTodayMeta = const VerificationMeta(
    'pagesToday',
  );
  @override
  late final GeneratedColumn<int> pagesToday = GeneratedColumn<int>(
    'pages_today',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pctTodayMeta = const VerificationMeta(
    'pctToday',
  );
  @override
  late final GeneratedColumn<double> pctToday = GeneratedColumn<double>(
    'pct_today',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [bookId, date, pagesToday, pctToday];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'daily_summary';
  @override
  VerificationContext validateIntegrity(
    Insertable<DailySummaryData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('pages_today')) {
      context.handle(
        _pagesTodayMeta,
        pagesToday.isAcceptableOrUnknown(data['pages_today']!, _pagesTodayMeta),
      );
    } else if (isInserting) {
      context.missing(_pagesTodayMeta);
    }
    if (data.containsKey('pct_today')) {
      context.handle(
        _pctTodayMeta,
        pctToday.isAcceptableOrUnknown(data['pct_today']!, _pctTodayMeta),
      );
    } else if (isInserting) {
      context.missing(_pctTodayMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookId, date};
  @override
  DailySummaryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DailySummaryData(
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      pagesToday: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pages_today'],
      )!,
      pctToday: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}pct_today'],
      )!,
    );
  }

  @override
  $DailySummaryTable createAlias(String alias) {
    return $DailySummaryTable(attachedDatabase, alias);
  }
}

class DailySummaryData extends DataClass
    implements Insertable<DailySummaryData> {
  final String bookId;
  final String date;
  final int pagesToday;
  final double pctToday;
  const DailySummaryData({
    required this.bookId,
    required this.date,
    required this.pagesToday,
    required this.pctToday,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_id'] = Variable<String>(bookId);
    map['date'] = Variable<String>(date);
    map['pages_today'] = Variable<int>(pagesToday);
    map['pct_today'] = Variable<double>(pctToday);
    return map;
  }

  DailySummaryCompanion toCompanion(bool nullToAbsent) {
    return DailySummaryCompanion(
      bookId: Value(bookId),
      date: Value(date),
      pagesToday: Value(pagesToday),
      pctToday: Value(pctToday),
    );
  }

  factory DailySummaryData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DailySummaryData(
      bookId: serializer.fromJson<String>(json['bookId']),
      date: serializer.fromJson<String>(json['date']),
      pagesToday: serializer.fromJson<int>(json['pagesToday']),
      pctToday: serializer.fromJson<double>(json['pctToday']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookId': serializer.toJson<String>(bookId),
      'date': serializer.toJson<String>(date),
      'pagesToday': serializer.toJson<int>(pagesToday),
      'pctToday': serializer.toJson<double>(pctToday),
    };
  }

  DailySummaryData copyWith({
    String? bookId,
    String? date,
    int? pagesToday,
    double? pctToday,
  }) => DailySummaryData(
    bookId: bookId ?? this.bookId,
    date: date ?? this.date,
    pagesToday: pagesToday ?? this.pagesToday,
    pctToday: pctToday ?? this.pctToday,
  );
  DailySummaryData copyWithCompanion(DailySummaryCompanion data) {
    return DailySummaryData(
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      date: data.date.present ? data.date.value : this.date,
      pagesToday: data.pagesToday.present
          ? data.pagesToday.value
          : this.pagesToday,
      pctToday: data.pctToday.present ? data.pctToday.value : this.pctToday,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailySummaryData(')
          ..write('bookId: $bookId, ')
          ..write('date: $date, ')
          ..write('pagesToday: $pagesToday, ')
          ..write('pctToday: $pctToday')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(bookId, date, pagesToday, pctToday);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailySummaryData &&
          other.bookId == this.bookId &&
          other.date == this.date &&
          other.pagesToday == this.pagesToday &&
          other.pctToday == this.pctToday);
}

class DailySummaryCompanion extends UpdateCompanion<DailySummaryData> {
  final Value<String> bookId;
  final Value<String> date;
  final Value<int> pagesToday;
  final Value<double> pctToday;
  final Value<int> rowid;
  const DailySummaryCompanion({
    this.bookId = const Value.absent(),
    this.date = const Value.absent(),
    this.pagesToday = const Value.absent(),
    this.pctToday = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DailySummaryCompanion.insert({
    required String bookId,
    required String date,
    required int pagesToday,
    required double pctToday,
    this.rowid = const Value.absent(),
  }) : bookId = Value(bookId),
       date = Value(date),
       pagesToday = Value(pagesToday),
       pctToday = Value(pctToday);
  static Insertable<DailySummaryData> custom({
    Expression<String>? bookId,
    Expression<String>? date,
    Expression<int>? pagesToday,
    Expression<double>? pctToday,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookId != null) 'book_id': bookId,
      if (date != null) 'date': date,
      if (pagesToday != null) 'pages_today': pagesToday,
      if (pctToday != null) 'pct_today': pctToday,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DailySummaryCompanion copyWith({
    Value<String>? bookId,
    Value<String>? date,
    Value<int>? pagesToday,
    Value<double>? pctToday,
    Value<int>? rowid,
  }) {
    return DailySummaryCompanion(
      bookId: bookId ?? this.bookId,
      date: date ?? this.date,
      pagesToday: pagesToday ?? this.pagesToday,
      pctToday: pctToday ?? this.pctToday,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (pagesToday.present) {
      map['pages_today'] = Variable<int>(pagesToday.value);
    }
    if (pctToday.present) {
      map['pct_today'] = Variable<double>(pctToday.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DailySummaryCompanion(')
          ..write('bookId: $bookId, ')
          ..write('date: $date, ')
          ..write('pagesToday: $pagesToday, ')
          ..write('pctToday: $pctToday, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $IdempotencyLedgerTable extends IdempotencyLedger
    with TableInfo<$IdempotencyLedgerTable, IdempotencyLedgerData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IdempotencyLedgerTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idempotencyKeyMeta = const VerificationMeta(
    'idempotencyKey',
  );
  @override
  late final GeneratedColumn<String> idempotencyKey = GeneratedColumn<String>(
    'idempotency_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _opMeta = const VerificationMeta('op');
  @override
  late final GeneratedColumn<String> op = GeneratedColumn<String>(
    'op',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [idempotencyKey, op, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'idempotency_ledger';
  @override
  VerificationContext validateIntegrity(
    Insertable<IdempotencyLedgerData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('idempotency_key')) {
      context.handle(
        _idempotencyKeyMeta,
        idempotencyKey.isAcceptableOrUnknown(
          data['idempotency_key']!,
          _idempotencyKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_idempotencyKeyMeta);
    }
    if (data.containsKey('op')) {
      context.handle(_opMeta, op.isAcceptableOrUnknown(data['op']!, _opMeta));
    } else if (isInserting) {
      context.missing(_opMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {op, idempotencyKey};
  @override
  IdempotencyLedgerData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return IdempotencyLedgerData(
      idempotencyKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}idempotency_key'],
      )!,
      op: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}op'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $IdempotencyLedgerTable createAlias(String alias) {
    return $IdempotencyLedgerTable(attachedDatabase, alias);
  }
}

class IdempotencyLedgerData extends DataClass
    implements Insertable<IdempotencyLedgerData> {
  final String idempotencyKey;
  final String op;
  final DateTime createdAt;
  const IdempotencyLedgerData({
    required this.idempotencyKey,
    required this.op,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['idempotency_key'] = Variable<String>(idempotencyKey);
    map['op'] = Variable<String>(op);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  IdempotencyLedgerCompanion toCompanion(bool nullToAbsent) {
    return IdempotencyLedgerCompanion(
      idempotencyKey: Value(idempotencyKey),
      op: Value(op),
      createdAt: Value(createdAt),
    );
  }

  factory IdempotencyLedgerData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return IdempotencyLedgerData(
      idempotencyKey: serializer.fromJson<String>(json['idempotencyKey']),
      op: serializer.fromJson<String>(json['op']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'idempotencyKey': serializer.toJson<String>(idempotencyKey),
      'op': serializer.toJson<String>(op),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  IdempotencyLedgerData copyWith({
    String? idempotencyKey,
    String? op,
    DateTime? createdAt,
  }) => IdempotencyLedgerData(
    idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    op: op ?? this.op,
    createdAt: createdAt ?? this.createdAt,
  );
  IdempotencyLedgerData copyWithCompanion(IdempotencyLedgerCompanion data) {
    return IdempotencyLedgerData(
      idempotencyKey: data.idempotencyKey.present
          ? data.idempotencyKey.value
          : this.idempotencyKey,
      op: data.op.present ? data.op.value : this.op,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('IdempotencyLedgerData(')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('op: $op, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(idempotencyKey, op, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IdempotencyLedgerData &&
          other.idempotencyKey == this.idempotencyKey &&
          other.op == this.op &&
          other.createdAt == this.createdAt);
}

class IdempotencyLedgerCompanion
    extends UpdateCompanion<IdempotencyLedgerData> {
  final Value<String> idempotencyKey;
  final Value<String> op;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const IdempotencyLedgerCompanion({
    this.idempotencyKey = const Value.absent(),
    this.op = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  IdempotencyLedgerCompanion.insert({
    required String idempotencyKey,
    required String op,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : idempotencyKey = Value(idempotencyKey),
       op = Value(op),
       createdAt = Value(createdAt);
  static Insertable<IdempotencyLedgerData> custom({
    Expression<String>? idempotencyKey,
    Expression<String>? op,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      if (op != null) 'op': op,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  IdempotencyLedgerCompanion copyWith({
    Value<String>? idempotencyKey,
    Value<String>? op,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return IdempotencyLedgerCompanion(
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      op: op ?? this.op,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (idempotencyKey.present) {
      map['idempotency_key'] = Variable<String>(idempotencyKey.value);
    }
    if (op.present) {
      map['op'] = Variable<String>(op.value);
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
    return (StringBuffer('IdempotencyLedgerCompanion(')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('op: $op, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$M1Database extends GeneratedDatabase {
  _$M1Database(QueryExecutor e) : super(e);
  $M1DatabaseManager get managers => $M1DatabaseManager(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $BooksTable books = $BooksTable(this);
  late final $ProgressLogTable progressLog = $ProgressLogTable(this);
  late final $DailySummaryTable dailySummary = $DailySummaryTable(this);
  late final $IdempotencyLedgerTable idempotencyLedger =
      $IdempotencyLedgerTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    categories,
    books,
    progressLog,
    dailySummary,
    idempotencyLedger,
  ];
}

typedef $$CategoriesTableCreateCompanionBuilder =
    CategoriesCompanion Function({
      required String categoryId,
      required String name,
      required int position,
      Value<int> rowid,
    });
typedef $$CategoriesTableUpdateCompanionBuilder =
    CategoriesCompanion Function({
      Value<String> categoryId,
      Value<String> name,
      Value<int> position,
      Value<int> rowid,
    });

class $$CategoriesTableFilterComposer
    extends Composer<_$M1Database, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$M1Database, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$M1Database, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);
}

class $$CategoriesTableTableManager
    extends
        RootTableManager<
          _$M1Database,
          $CategoriesTable,
          Category,
          $$CategoriesTableFilterComposer,
          $$CategoriesTableOrderingComposer,
          $$CategoriesTableAnnotationComposer,
          $$CategoriesTableCreateCompanionBuilder,
          $$CategoriesTableUpdateCompanionBuilder,
          (Category, BaseReferences<_$M1Database, $CategoriesTable, Category>),
          Category,
          PrefetchHooks Function()
        > {
  $$CategoriesTableTableManager(_$M1Database db, $CategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> categoryId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion(
                categoryId: categoryId,
                name: name,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String categoryId,
                required String name,
                required int position,
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion.insert(
                categoryId: categoryId,
                name: name,
                position: position,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CategoriesTable, Category>(table),
                  BaseReferences<_$M1Database, $CategoriesTable, Category>(
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

typedef $$CategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$M1Database,
      $CategoriesTable,
      Category,
      $$CategoriesTableFilterComposer,
      $$CategoriesTableOrderingComposer,
      $$CategoriesTableAnnotationComposer,
      $$CategoriesTableCreateCompanionBuilder,
      $$CategoriesTableUpdateCompanionBuilder,
      (Category, BaseReferences<_$M1Database, $CategoriesTable, Category>),
      Category,
      PrefetchHooks Function()
    >;
typedef $$BooksTableCreateCompanionBuilder =
    BooksCompanion Function({
      required String bookId,
      required String categoryId,
      required String title,
      required int totalPages,
      required String source,
      Value<String?> filePath,
      Value<String?> coverRef,
      Value<int> rowid,
    });
typedef $$BooksTableUpdateCompanionBuilder =
    BooksCompanion Function({
      Value<String> bookId,
      Value<String> categoryId,
      Value<String> title,
      Value<int> totalPages,
      Value<String> source,
      Value<String?> filePath,
      Value<String?> coverRef,
      Value<int> rowid,
    });

class $$BooksTableFilterComposer extends Composer<_$M1Database, $BooksTable> {
  $$BooksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalPages => $composableBuilder(
    column: $table.totalPages,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverRef => $composableBuilder(
    column: $table.coverRef,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BooksTableOrderingComposer extends Composer<_$M1Database, $BooksTable> {
  $$BooksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalPages => $composableBuilder(
    column: $table.totalPages,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverRef => $composableBuilder(
    column: $table.coverRef,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BooksTableAnnotationComposer
    extends Composer<_$M1Database, $BooksTable> {
  $$BooksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get totalPages => $composableBuilder(
    column: $table.totalPages,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get coverRef =>
      $composableBuilder(column: $table.coverRef, builder: (column) => column);
}

class $$BooksTableTableManager
    extends
        RootTableManager<
          _$M1Database,
          $BooksTable,
          Book,
          $$BooksTableFilterComposer,
          $$BooksTableOrderingComposer,
          $$BooksTableAnnotationComposer,
          $$BooksTableCreateCompanionBuilder,
          $$BooksTableUpdateCompanionBuilder,
          (Book, BaseReferences<_$M1Database, $BooksTable, Book>),
          Book,
          PrefetchHooks Function()
        > {
  $$BooksTableTableManager(_$M1Database db, $BooksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BooksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BooksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BooksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> bookId = const Value.absent(),
                Value<String> categoryId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> totalPages = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> filePath = const Value.absent(),
                Value<String?> coverRef = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BooksCompanion(
                bookId: bookId,
                categoryId: categoryId,
                title: title,
                totalPages: totalPages,
                source: source,
                filePath: filePath,
                coverRef: coverRef,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String bookId,
                required String categoryId,
                required String title,
                required int totalPages,
                required String source,
                Value<String?> filePath = const Value.absent(),
                Value<String?> coverRef = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BooksCompanion.insert(
                bookId: bookId,
                categoryId: categoryId,
                title: title,
                totalPages: totalPages,
                source: source,
                filePath: filePath,
                coverRef: coverRef,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BooksTable, Book>(table),
                  BaseReferences<_$M1Database, $BooksTable, Book>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BooksTableProcessedTableManager =
    ProcessedTableManager<
      _$M1Database,
      $BooksTable,
      Book,
      $$BooksTableFilterComposer,
      $$BooksTableOrderingComposer,
      $$BooksTableAnnotationComposer,
      $$BooksTableCreateCompanionBuilder,
      $$BooksTableUpdateCompanionBuilder,
      (Book, BaseReferences<_$M1Database, $BooksTable, Book>),
      Book,
      PrefetchHooks Function()
    >;
typedef $$ProgressLogTableCreateCompanionBuilder =
    ProgressLogCompanion Function({
      Value<int> id,
      required String bookId,
      required int currentPage,
      required String readOn,
      required String idempotencyKey,
      required DateTime createdAt,
    });
typedef $$ProgressLogTableUpdateCompanionBuilder =
    ProgressLogCompanion Function({
      Value<int> id,
      Value<String> bookId,
      Value<int> currentPage,
      Value<String> readOn,
      Value<String> idempotencyKey,
      Value<DateTime> createdAt,
    });

class $$ProgressLogTableFilterComposer
    extends Composer<_$M1Database, $ProgressLogTable> {
  $$ProgressLogTableFilterComposer({
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

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentPage => $composableBuilder(
    column: $table.currentPage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get readOn => $composableBuilder(
    column: $table.readOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProgressLogTableOrderingComposer
    extends Composer<_$M1Database, $ProgressLogTable> {
  $$ProgressLogTableOrderingComposer({
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

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentPage => $composableBuilder(
    column: $table.currentPage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get readOn => $composableBuilder(
    column: $table.readOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProgressLogTableAnnotationComposer
    extends Composer<_$M1Database, $ProgressLogTable> {
  $$ProgressLogTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<int> get currentPage => $composableBuilder(
    column: $table.currentPage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get readOn =>
      $composableBuilder(column: $table.readOn, builder: (column) => column);

  GeneratedColumn<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ProgressLogTableTableManager
    extends
        RootTableManager<
          _$M1Database,
          $ProgressLogTable,
          ProgressLogData,
          $$ProgressLogTableFilterComposer,
          $$ProgressLogTableOrderingComposer,
          $$ProgressLogTableAnnotationComposer,
          $$ProgressLogTableCreateCompanionBuilder,
          $$ProgressLogTableUpdateCompanionBuilder,
          (
            ProgressLogData,
            BaseReferences<_$M1Database, $ProgressLogTable, ProgressLogData>,
          ),
          ProgressLogData,
          PrefetchHooks Function()
        > {
  $$ProgressLogTableTableManager(_$M1Database db, $ProgressLogTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProgressLogTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProgressLogTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProgressLogTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<int> currentPage = const Value.absent(),
                Value<String> readOn = const Value.absent(),
                Value<String> idempotencyKey = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ProgressLogCompanion(
                id: id,
                bookId: bookId,
                currentPage: currentPage,
                readOn: readOn,
                idempotencyKey: idempotencyKey,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String bookId,
                required int currentPage,
                required String readOn,
                required String idempotencyKey,
                required DateTime createdAt,
              }) => ProgressLogCompanion.insert(
                id: id,
                bookId: bookId,
                currentPage: currentPage,
                readOn: readOn,
                idempotencyKey: idempotencyKey,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProgressLogTable, ProgressLogData>(table),
                  BaseReferences<
                    _$M1Database,
                    $ProgressLogTable,
                    ProgressLogData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProgressLogTableProcessedTableManager =
    ProcessedTableManager<
      _$M1Database,
      $ProgressLogTable,
      ProgressLogData,
      $$ProgressLogTableFilterComposer,
      $$ProgressLogTableOrderingComposer,
      $$ProgressLogTableAnnotationComposer,
      $$ProgressLogTableCreateCompanionBuilder,
      $$ProgressLogTableUpdateCompanionBuilder,
      (
        ProgressLogData,
        BaseReferences<_$M1Database, $ProgressLogTable, ProgressLogData>,
      ),
      ProgressLogData,
      PrefetchHooks Function()
    >;
typedef $$DailySummaryTableCreateCompanionBuilder =
    DailySummaryCompanion Function({
      required String bookId,
      required String date,
      required int pagesToday,
      required double pctToday,
      Value<int> rowid,
    });
typedef $$DailySummaryTableUpdateCompanionBuilder =
    DailySummaryCompanion Function({
      Value<String> bookId,
      Value<String> date,
      Value<int> pagesToday,
      Value<double> pctToday,
      Value<int> rowid,
    });

class $$DailySummaryTableFilterComposer
    extends Composer<_$M1Database, $DailySummaryTable> {
  $$DailySummaryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pagesToday => $composableBuilder(
    column: $table.pagesToday,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get pctToday => $composableBuilder(
    column: $table.pctToday,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DailySummaryTableOrderingComposer
    extends Composer<_$M1Database, $DailySummaryTable> {
  $$DailySummaryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pagesToday => $composableBuilder(
    column: $table.pagesToday,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get pctToday => $composableBuilder(
    column: $table.pctToday,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DailySummaryTableAnnotationComposer
    extends Composer<_$M1Database, $DailySummaryTable> {
  $$DailySummaryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get pagesToday => $composableBuilder(
    column: $table.pagesToday,
    builder: (column) => column,
  );

  GeneratedColumn<double> get pctToday =>
      $composableBuilder(column: $table.pctToday, builder: (column) => column);
}

class $$DailySummaryTableTableManager
    extends
        RootTableManager<
          _$M1Database,
          $DailySummaryTable,
          DailySummaryData,
          $$DailySummaryTableFilterComposer,
          $$DailySummaryTableOrderingComposer,
          $$DailySummaryTableAnnotationComposer,
          $$DailySummaryTableCreateCompanionBuilder,
          $$DailySummaryTableUpdateCompanionBuilder,
          (
            DailySummaryData,
            BaseReferences<_$M1Database, $DailySummaryTable, DailySummaryData>,
          ),
          DailySummaryData,
          PrefetchHooks Function()
        > {
  $$DailySummaryTableTableManager(_$M1Database db, $DailySummaryTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DailySummaryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DailySummaryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DailySummaryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> bookId = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<int> pagesToday = const Value.absent(),
                Value<double> pctToday = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DailySummaryCompanion(
                bookId: bookId,
                date: date,
                pagesToday: pagesToday,
                pctToday: pctToday,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String bookId,
                required String date,
                required int pagesToday,
                required double pctToday,
                Value<int> rowid = const Value.absent(),
              }) => DailySummaryCompanion.insert(
                bookId: bookId,
                date: date,
                pagesToday: pagesToday,
                pctToday: pctToday,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DailySummaryTable, DailySummaryData>(table),
                  BaseReferences<
                    _$M1Database,
                    $DailySummaryTable,
                    DailySummaryData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DailySummaryTableProcessedTableManager =
    ProcessedTableManager<
      _$M1Database,
      $DailySummaryTable,
      DailySummaryData,
      $$DailySummaryTableFilterComposer,
      $$DailySummaryTableOrderingComposer,
      $$DailySummaryTableAnnotationComposer,
      $$DailySummaryTableCreateCompanionBuilder,
      $$DailySummaryTableUpdateCompanionBuilder,
      (
        DailySummaryData,
        BaseReferences<_$M1Database, $DailySummaryTable, DailySummaryData>,
      ),
      DailySummaryData,
      PrefetchHooks Function()
    >;
typedef $$IdempotencyLedgerTableCreateCompanionBuilder =
    IdempotencyLedgerCompanion Function({
      required String idempotencyKey,
      required String op,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$IdempotencyLedgerTableUpdateCompanionBuilder =
    IdempotencyLedgerCompanion Function({
      Value<String> idempotencyKey,
      Value<String> op,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$IdempotencyLedgerTableFilterComposer
    extends Composer<_$M1Database, $IdempotencyLedgerTable> {
  $$IdempotencyLedgerTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$IdempotencyLedgerTableOrderingComposer
    extends Composer<_$M1Database, $IdempotencyLedgerTable> {
  $$IdempotencyLedgerTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$IdempotencyLedgerTableAnnotationComposer
    extends Composer<_$M1Database, $IdempotencyLedgerTable> {
  $$IdempotencyLedgerTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get op =>
      $composableBuilder(column: $table.op, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$IdempotencyLedgerTableTableManager
    extends
        RootTableManager<
          _$M1Database,
          $IdempotencyLedgerTable,
          IdempotencyLedgerData,
          $$IdempotencyLedgerTableFilterComposer,
          $$IdempotencyLedgerTableOrderingComposer,
          $$IdempotencyLedgerTableAnnotationComposer,
          $$IdempotencyLedgerTableCreateCompanionBuilder,
          $$IdempotencyLedgerTableUpdateCompanionBuilder,
          (
            IdempotencyLedgerData,
            BaseReferences<
              _$M1Database,
              $IdempotencyLedgerTable,
              IdempotencyLedgerData
            >,
          ),
          IdempotencyLedgerData,
          PrefetchHooks Function()
        > {
  $$IdempotencyLedgerTableTableManager(
    _$M1Database db,
    $IdempotencyLedgerTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IdempotencyLedgerTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$IdempotencyLedgerTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$IdempotencyLedgerTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> idempotencyKey = const Value.absent(),
                Value<String> op = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => IdempotencyLedgerCompanion(
                idempotencyKey: idempotencyKey,
                op: op,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String idempotencyKey,
                required String op,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => IdempotencyLedgerCompanion.insert(
                idempotencyKey: idempotencyKey,
                op: op,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$IdempotencyLedgerTable, IdempotencyLedgerData>(
                    table,
                  ),
                  BaseReferences<
                    _$M1Database,
                    $IdempotencyLedgerTable,
                    IdempotencyLedgerData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$IdempotencyLedgerTableProcessedTableManager =
    ProcessedTableManager<
      _$M1Database,
      $IdempotencyLedgerTable,
      IdempotencyLedgerData,
      $$IdempotencyLedgerTableFilterComposer,
      $$IdempotencyLedgerTableOrderingComposer,
      $$IdempotencyLedgerTableAnnotationComposer,
      $$IdempotencyLedgerTableCreateCompanionBuilder,
      $$IdempotencyLedgerTableUpdateCompanionBuilder,
      (
        IdempotencyLedgerData,
        BaseReferences<
          _$M1Database,
          $IdempotencyLedgerTable,
          IdempotencyLedgerData
        >,
      ),
      IdempotencyLedgerData,
      PrefetchHooks Function()
    >;

class $M1DatabaseManager {
  final _$M1Database _db;
  $M1DatabaseManager(this._db);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$BooksTableTableManager get books =>
      $$BooksTableTableManager(_db, _db.books);
  $$ProgressLogTableTableManager get progressLog =>
      $$ProgressLogTableTableManager(_db, _db.progressLog);
  $$DailySummaryTableTableManager get dailySummary =>
      $$DailySummaryTableTableManager(_db, _db.dailySummary);
  $$IdempotencyLedgerTableTableManager get idempotencyLedger =>
      $$IdempotencyLedgerTableTableManager(_db, _db.idempotencyLedger);
}

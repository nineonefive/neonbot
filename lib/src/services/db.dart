import 'package:sqlite3/sqlite3.dart';

class Field {
  final String type;
  const Field(this.type);

  Field get asPrimary => Field('$type PRIMARY KEY');
  Field get notNull => Field('$type NOT NULL');
  Field get unique => Field('$type UNIQUE');

  static const integer = Field('INTEGER');
  static const text = Field('TEXT');
  static const json = Field('JSON');
}

class Table {
  final String name;
  final Map<String, Field> fields;
  final String constraint;

  const Table(this.name, this.fields, {this.constraint = ""});

  String get create {
    List<String> columns = [];
    for (var entry in fields.entries) {
      columns.add('${entry.key} ${entry.value.type}');
    }
    var columnString = columns.join(', ');

    if (constraint.isNotEmpty) {
      columnString = '$columnString, $constraint';
    }

    var baseQuery = 'CREATE TABLE IF NOT EXISTS $name ($columnString)';

    return baseQuery;
  }
}

class Tables {
  static final guildPreferences = Table("guild_preferences", {
    "id": Field.integer.asPrimary,
    "guildId": Field.integer.notNull.unique,
    "preferences": Field.text.notNull
  });

  static final premierSchedule = Table(
      "premier_schedule",
      {
        "id": Field.integer.asPrimary,
        "region": Field.text.notNull,
        "startTime": Field.integer.notNull,
        "data": Field.text.notNull
      },
      constraint: "UNIQUE(region, startTime)");
}

class DatabaseService {
  static DatabaseService instance = DatabaseService._();
  DatabaseService._();

  static Database? get service => instance._db;

  Database? _db;

  void init(String databasePath) {
    _db = sqlite3.open(databasePath);

    createTable(Tables.guildPreferences);
    createTable(Tables.premierSchedule);
  }

  /// Creates the table defined by [schema]
  void createTable(Table schema) => _db!.execute(schema.create);

  /// Closes the current connection to the database
  void close() => _db?.dispose();
}

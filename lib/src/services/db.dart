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

  const Table(this.name, this.fields);

  String get create {
    List<String> columns = [];
    for (var entry in fields.entries) {
      columns.add('${entry.key} ${entry.value.type}');
    }
    var columnString = columns.join(', ');
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
}

class DatabaseService {
  static DatabaseService instance = DatabaseService._();
  DatabaseService._();

  static Database? get service => instance._db;

  Database? _db;

  void init(String databasePath) {
    _db = sqlite3.open(databasePath);

    createTable(Tables.guildPreferences);
  }

  /// Creates the table defined by [schema]
  void createTable(Table schema) => _db!.execute(schema.create);

  /// Closes the current connection to the database
  void close() => _db?.dispose();
}

import 'package:sqlite3/sqlite3.dart';

class Field {
  final String type;
  const Field(this.type);

  Field get asPrimary => Field('$type PRIMARY KEY');
  Field get notNull => Field('$type NOT NULL');
  Field get unique => Field('$type UNIQUE');

  static const INTEGER = Field('INTEGER');
  static const TEXT = Field('TEXT');
  static const JSON = Field('JSON');
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
  static final GuildPreferences = Table("guild_preferences", {
    "id": Field.INTEGER.asPrimary,
    "guildId": Field.TEXT.notNull.unique,
    "preferences": Field.TEXT.notNull
  });
}

class Db {
  static Database? db;

  static void init() {
    db = sqlite3.open('local_db.db');

    createTable(Tables.GuildPreferences);
  }

  /// Creates the table defined by [schema]
  static void createTable(Table schema) => db!.execute(schema.create);

  /// Closes the current connection to the database
  static void close() => db?.dispose();
}

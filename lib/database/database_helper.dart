import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/item.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('shopping.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
CREATE TABLE items(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT,
  price INTEGER,
  taxRate REAL,
  isChecked INTEGER,
  createdAt INTEGER
)
''');

    await db.execute('''
CREATE TABLE item_history(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT UNIQUE,
  count INTEGER,
  lastUsed INTEGER
)
''');
  }

  // -------------------------
  // items CRUD
  // -------------------------

  Future<int> insertItem(Item item) async {
    final db = await instance.database;
    return await db.insert('items', item.toMap());
  }

  Future<List<Item>> getItems() async {
    final db = await instance.database;
    final result = await db.query('items');

    return result.map((e) => Item.fromMap(e)).toList();
  }

  Future<int> updateItem(Item item) async {
    final db = await instance.database;
    return await db.update(
      'items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deleteItem(int id) async {
    final db = await instance.database;
    return await db.delete('items', where: 'id = ?', whereArgs: [id]);
  }

  // -------------------------
  // 履歴
  // -------------------------

  Future<void> upsertHistory(String name) async {
    final db = await instance.database;

    final result = await db.query(
      'item_history',
      where: 'name = ?',
      whereArgs: [name],
    );

    if (result.isEmpty) {
      await db.insert('item_history', {
        'name': name,
        'count': 1,
        'lastUsed': DateTime.now().millisecondsSinceEpoch,
      });
    } else {
      final count = result.first['count'] as int;

      await db.update(
        'item_history',
        {'count': count + 1, 'lastUsed': DateTime.now().millisecondsSinceEpoch},
        where: 'name = ?',
        whereArgs: [name],
      );
    }
  }

  Future<List<String>> getHistoryNames() async {
    final db = await instance.database;

    final result = await db.query(
      'item_history',
      orderBy: 'count DESC, lastUsed DESC',
    );

    return result.map((e) => e['name'] as String).toList();
  }
}

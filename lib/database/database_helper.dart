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

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
CREATE TABLE items(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT,
  price INTEGER,
  taxRate REAL,
  isChecked INTEGER,
  createdAt INTEGER,
  sortOrder INTEGER,
  quantity INTEGER,
  memo TEXT
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

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE items ADD COLUMN quantity INTEGER DEFAULT 1',
      );
    }
  }

  // -------------------------
  // items CRUD
  // -------------------------

  // 通常追加（idは自動）
  Future<int> insertItem(Item item) async {
    final db = await database;

    final map = item.toMap();
    map.remove('id'); // ←ここ重要
    map['createdAt'] ??= DateTime.now().millisecondsSinceEpoch;

    return await db.insert('items', map);
  }

  // Undo用（完全復元）
  Future<void> insertItemWithId(Item item) async {
    final db = await database;

    await db.insert(
      'items',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Item>> getItems() async {
    final db = await instance.database;
    final result = await db.query('items', orderBy: 'sortOrder ASC');

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

  Future<void> deleteCheckedItems() async {
    final db = await instance.database;

    await db.delete('items', where: 'isChecked = ?', whereArgs: [1]);
  }

  Future<void> updateSortOrders(List<Item> items) async {
    final db = await database;

    final batch = db.batch();

    for (final item in items) {
      batch.update(
        'items',
        {'sortOrder': item.sortOrder},
        where: 'id = ?',
        whereArgs: [item.id],
      );
    }

    await batch.commit(noResult: true);
  }

  Future<void> normalizeAllSortOrders() async {
    final db = await database;

    final result = await db.query('items', orderBy: 'sortOrder ASC');

    final items = result.map((e) => Item.fromMap(e)).toList();

    final batch = db.batch();

    for (int i = 0; i < items.length; i++) {
      batch.update(
        'items',
        {'sortOrder': i},
        where: 'id = ?',
        whereArgs: [items[i].id],
      );
    }

    await batch.commit(noResult: true);
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

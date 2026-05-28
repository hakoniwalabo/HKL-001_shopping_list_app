import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/item.dart';
import '../models/shopping_list.dart';

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
      version: 5,
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
  isChecked INTEGER,
  createdAt INTEGER,
  sortOrder INTEGER,
  quantity INTEGER,
  memo TEXT,
  listId INTEGER
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

    await db.execute('''
CREATE TABLE lists(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT,
  createdAt INTEGER
)
''');

    await db.insert('lists', {
      'name': '買い物リスト',
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // 不足しているテーブルを作成（IF NOT EXISTS で冪等）
    await db.execute('''
CREATE TABLE IF NOT EXISTS item_history(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT UNIQUE,
  count INTEGER,
  lastUsed INTEGER
)
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS lists(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT,
  createdAt INTEGER
)
''');

    // lists が空なら初期リストを挿入
    final existingLists = await db.query('lists');
    if (existingLists.isEmpty) {
      await db.insert('lists', {
        'name': '買い物リスト',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
    }

    // 不足しているカラムを追加（既存なら例外を握り潰す）
    for (final sql in [
      'ALTER TABLE items ADD COLUMN quantity INTEGER DEFAULT 1',
      'ALTER TABLE items ADD COLUMN memo TEXT',
      'ALTER TABLE items ADD COLUMN listId INTEGER DEFAULT 1',
    ]) {
      try {
        await db.execute(sql);
      } catch (_) {
        // カラムが既に存在する場合は無視
      }
    }

    // version 4 → 5: taxRate カラムを削除（SQLite は DROP COLUMN 非対応のためテーブル再作成）
    if (oldVersion < 5) {
      await db.execute('''
CREATE TABLE items_new(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT,
  price INTEGER,
  isChecked INTEGER,
  createdAt INTEGER,
  sortOrder INTEGER,
  quantity INTEGER,
  memo TEXT,
  listId INTEGER
)
''');
      await db.execute('''
INSERT INTO items_new(id, name, price, isChecked, createdAt, sortOrder, quantity, memo, listId)
SELECT id, name, price, isChecked, createdAt, sortOrder, quantity, memo, listId FROM items
''');
      await db.execute('DROP TABLE items');
      await db.execute('ALTER TABLE items_new RENAME TO items');
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

  Future<List<Item>> getItemsByListId(int listId) async {
    final db = await instance.database;
    final result = await db.query(
      'items',
      where: 'listId = ?',
      whereArgs: [listId],
      orderBy: 'sortOrder ASC',
    );

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

  Future<void> deleteCheckedItems(int listId) async {
    final db = await instance.database;

    await db.delete(
      'items',
      where: 'isChecked = ? AND listId = ?',
      whereArgs: [1, listId],
    );
  }

  Future<void> updateSortOrders(List<Item> items) async {
    final db = await database;

    await db.transaction((txn) async {
      final batch = txn.batch();

      for (final item in items) {
        batch.update(
          'items',
          {'sortOrder': item.sortOrder},
          where: 'id = ?',
          whereArgs: [item.id],
        );
      }

      await batch.commit(noResult: true);
    });
  }

  Future<void> normalizeAllSortOrders(int listId) async {
    final db = await database;

    await db.transaction((txn) async {
      final result = await txn.query(
        'items',
        where: 'listId = ?',
        whereArgs: [listId],
        orderBy: 'sortOrder ASC',
      );

      final items = result.map((e) => Item.fromMap(e)).toList();

      final batch = txn.batch();

      for (int i = 0; i < items.length; i++) {
        batch.update(
          'items',
          {'sortOrder': i},
          where: 'id = ?',
          whereArgs: [items[i].id],
        );
      }

      await batch.commit(noResult: true);
    });
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

  Future<List<ShoppingList>> getLists() async {
    final db = await database;

    final result = await db.query('lists', orderBy: 'createdAt ASC');

    return result.map((e) => ShoppingList.fromMap(e)).toList();
  }

  Future<int> insertList(ShoppingList list) async {
    final db = await database;

    return await db.insert('lists', list.toMap());
  }

  Future<void> deleteList(int listId) async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.delete('items', where: 'listId = ?', whereArgs: [listId]);

      await txn.delete('lists', where: 'id = ?', whereArgs: [listId]);
    });
  }

  Future<void> updateListName(int listId, String newName) async {
    final db = await database;

    await db.update(
      'lists',
      {'name': newName},
      where: 'id = ?',
      whereArgs: [listId],
    );
  }
}

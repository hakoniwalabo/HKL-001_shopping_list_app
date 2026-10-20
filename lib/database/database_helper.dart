import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/item.dart';
import '../models/shopping_list.dart';

class ImportResult {
  final int listCount;
  final int itemCount;
  final int favoriteCount;
  final int? firstNewListId;

  const ImportResult({
    required this.listCount,
    required this.itemCount,
    required this.favoriteCount,
    this.firstNewListId,
  });
}

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
      version: 9,
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
  listId INTEGER,
  categoryId INTEGER
)
''');

    await db.execute('''
CREATE TABLE lists(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT,
  createdAt INTEGER,
  budget INTEGER NOT NULL DEFAULT 0,
  sortOrder INTEGER NOT NULL DEFAULT 0
)
''');

    await db.insert('lists', {
      'name': '買い物リスト',
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'sortOrder': 0,
    });

    await db.execute('''
CREATE TABLE favorites (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  price INTEGER NOT NULL DEFAULT 0,
  quantity INTEGER NOT NULL DEFAULT 1,
  sortOrder INTEGER NOT NULL DEFAULT 0,
  createdAt INTEGER NOT NULL,
  categoryId INTEGER
)
''');

    await db.execute('''
CREATE TABLE categories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  sortOrder INTEGER NOT NULL DEFAULT 0,
  createdAt INTEGER NOT NULL
)
''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // 不足しているテーブルを作成（IF NOT EXISTS で冪等）
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

    if (oldVersion < 6) {
      await db.execute('''
CREATE TABLE IF NOT EXISTS favorites (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  price INTEGER NOT NULL DEFAULT 0,
  quantity INTEGER NOT NULL DEFAULT 1,
  sortOrder INTEGER NOT NULL DEFAULT 0,
  createdAt INTEGER NOT NULL
)
''');
    }

    if (oldVersion < 7) {
      await db.execute('''
CREATE TABLE IF NOT EXISTS categories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  sortOrder INTEGER NOT NULL DEFAULT 0,
  createdAt INTEGER NOT NULL
)
''');
      for (final sql in [
        'ALTER TABLE items ADD COLUMN categoryId INTEGER',
        'ALTER TABLE favorites ADD COLUMN categoryId INTEGER',
      ]) {
        try {
          await db.execute(sql);
        } catch (_) {}
      }
    }

    if (oldVersion < 8) {
      try {
        await db.execute(
          'ALTER TABLE lists ADD COLUMN budget INTEGER NOT NULL DEFAULT 0',
        );
      } catch (_) {
        // カラムが既に存在する場合は無視
      }
    }

    if (oldVersion < 9) {
      try {
        await db.execute(
          'ALTER TABLE lists ADD COLUMN sortOrder INTEGER NOT NULL DEFAULT 0',
        );
      } catch (_) {
        // カラムが既に存在する場合は無視
      }

      // 既存リストに現在の作成日時順で連番を初期セットする
      final existingRows = await db.query('lists', orderBy: 'createdAt ASC');
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (int i = 0; i < existingRows.length; i++) {
          batch.update(
            'lists',
            {'sortOrder': i},
            where: 'id = ?',
            whereArgs: [existingRows[i]['id']],
          );
        }
        await batch.commit(noResult: true);
      });
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

  Future<void> updateItemListId(int itemId, int targetListId) async {
    final db = await database;
    await db.update(
      'items',
      {'listId': targetListId},
      where: 'id = ?',
      whereArgs: [itemId],
    );
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

  Future<void> updateListBudget(int listId, int budget) async {
    final db = await database;

    await db.update(
      'lists',
      {'budget': budget},
      where: 'id = ?',
      whereArgs: [listId],
    );
  }

  /// 指定リストを複製して新しいリストIDを返す
  Future<int> duplicateList(int sourceListId, String newName) async {
    final db = await database;

    return await db.transaction((txn) async {
      // 新しいリストを作成
      final newListId = await txn.insert('lists', {
        'name': newName,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });

      // 元リストのアイテムを取得してコピー
      final items = await txn.query(
        'items',
        where: 'listId = ?',
        whereArgs: [sourceListId],
        orderBy: 'sortOrder ASC',
      );

      for (final item in items) {
        final copy = Map<String, dynamic>.from(item);
        copy.remove('id');
        copy['listId'] = newListId;
        copy['isChecked'] = 0; // 複製時はすべて未チェックにリセット
        await txn.insert('items', copy);
      }

      return newListId;
    });
  }

  // -------------------------
  // favorites CRUD
  // -------------------------

  Future<List<Map<String, dynamic>>> getFavorites() async {
    final db = await database;
    return await db.query('favorites', orderBy: 'sortOrder ASC');
  }

  Future<void> insertFavorite(
    String name,
    int price,
    int quantity, {
    int? categoryId,
  }) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT MAX(sortOrder) as maxOrder FROM favorites',
    );
    final maxOrder = (result.first['maxOrder'] as int?) ?? -1;
    await db.insert('favorites', {
      'name': name,
      'price': price,
      'quantity': quantity,
      'sortOrder': maxOrder + 1,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'categoryId': categoryId,
    });
  }

  Future<void> updateFavorite(
    int id,
    String name,
    int price,
    int quantity, {
    int? categoryId,
  }) async {
    final db = await database;
    await db.update(
      'favorites',
      {
        'name': name,
        'price': price,
        'quantity': quantity,
        'categoryId': categoryId,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteFavorite(int id) async {
    final db = await database;
    await db.delete('favorites', where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> favoriteNameExists(String name) async {
    final db = await database;
    final rows = await db.query('favorites', where: 'name = ?', whereArgs: [name]);
    return rows.isNotEmpty;
  }

  Future<void> reorderFavorites(List<int> orderedIds) async {
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (int i = 0; i < orderedIds.length; i++) {
        batch.update(
          'favorites',
          {'sortOrder': i},
          where: 'id = ?',
          whereArgs: [orderedIds[i]],
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await database;
    return await db.query('categories', orderBy: 'sortOrder ASC');
  }

  Future<int> insertCategory(String name) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT MAX(sortOrder) as maxOrder FROM categories',
    );
    final maxOrder = (result.first['maxOrder'] as int?) ?? -1;
    return await db.insert('categories', {
      'name': name,
      'sortOrder': maxOrder + 1,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> deleteCategory(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'items',
        {'categoryId': null},
        where: 'categoryId = ?',
        whereArgs: [id],
      );
      await txn.update(
        'favorites',
        {'categoryId': null},
        where: 'categoryId = ?',
        whereArgs: [id],
      );
      await txn.delete('categories', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> restoreFavorite(
    String name,
    int price,
    int quantity,
    int sortOrder, {
    int? categoryId,
  }) async {
    final db = await database;
    await db.insert('favorites', {
      'name': name,
      'price': price,
      'quantity': quantity,
      'sortOrder': sortOrder,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'categoryId': categoryId,
    });
  }

  Future<void> addFavoriteItemsToList(
      List<int> favoriteIds, int listId) async {
    final db = await database;
    await db.transaction((txn) async {
      final maxResult = await txn.rawQuery(
        'SELECT MAX(sortOrder) as maxOrder FROM items WHERE listId = ?',
        [listId],
      );
      int nextOrder = ((maxResult.first['maxOrder'] as int?) ?? -1) + 1;
      for (final favId in favoriteIds) {
        final rows = await txn.query(
          'favorites',
          where: 'id = ?',
          whereArgs: [favId],
        );
        if (rows.isEmpty) continue;
        final fav = rows.first;
        await txn.insert('items', {
          'name': fav['name'],
          'price': fav['price'],
          'quantity': fav['quantity'],
          'isChecked': 0,
          'memo': '',
          'listId': listId,
          'sortOrder': nextOrder++,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'categoryId': fav['categoryId'],
        });
      }
    });
  }

  // -------------------------
  // バックアップ・インポート
  // -------------------------

  /// バックアップJSONデータをマージINSERTする
  Future<ImportResult> importData(Map<String, dynamic> data) async {
    if (data['lists'] is! List ||
        data['items'] is! List ||
        data['favorites'] is! List) {
      throw ArgumentError('importData: 不正なデータ構造');
    }
    final db = await database;

    final version = data['version'] as int? ?? 1;
    final incomingCategories = version == 2
        ? List<Map<String, dynamic>>.from(data['categories'] as List)
        : <Map<String, dynamic>>[];
    final incomingLists =
        List<Map<String, dynamic>>.from(data['lists'] as List);
    final incomingItems =
        List<Map<String, dynamic>>.from(data['items'] as List);
    final incomingFavorites =
        List<Map<String, dynamic>>.from(data['favorites'] as List);

    // 既存リスト名を先に取得（transaction外）
    final existingListRows = await db.query('lists', columns: ['name']);
    final existingNames =
        existingListRows.map((r) => r['name'] as String).toSet();

    if (existingNames.length + incomingLists.length > 10) {
      throw const FormatException('list_limit_exceeded');
    }

    final listIdMap = <int, int>{};
    final categoryIdMap = <int, int>{};
    int insertedFavCount = 0;

    await db.transaction((txn) async {
      // categories INSERT（name 重複はスキップ）
      final existingCatRows =
          await txn.query('categories', columns: ['name']);
      final existingCatNames =
          existingCatRows.map((r) => r['name'] as String).toSet();
      final maxCatResult = await txn.rawQuery(
        'SELECT MAX(sortOrder) as maxOrder FROM categories',
      );
      int nextCatOrder =
          ((maxCatResult.first['maxOrder'] as int?) ?? -1) + 1;

      for (final cat in incomingCategories) {
        final oldId = (cat['id'] as num).toInt();
        final catName = cat['name'] as String;
        if (existingCatNames.contains(catName)) {
          final existing = await txn.query(
            'categories',
            columns: ['id'],
            where: 'name = ?',
            whereArgs: [catName],
          );
          if (existing.isNotEmpty) {
            categoryIdMap[oldId] = existing.first['id'] as int;
          }
          continue;
        }
        existingCatNames.add(catName);
        final newId = await txn.insert('categories', {
          'name': catName,
          'sortOrder': nextCatOrder++,
          'createdAt': cat['createdAt'],
        });
        categoryIdMap[oldId] = newId;
      }

      // lists INSERT
      // 既存リスト中の最大 createdAt を取得して、インポートリストが必ず右端に並ぶようにする
      final maxCreatedAtResult = await txn.rawQuery(
        'SELECT MAX(createdAt) as maxAt FROM lists',
      );
      final baseCreatedAt =
          ((maxCreatedAtResult.first['maxAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch) + 1;
      int listInsertIndex = 0;

      for (final list in incomingLists) {
        final oldId = (list['id'] as num).toInt();
        final resolvedName =
            resolveListName(list['name'] as String, existingNames);
        existingNames.add(resolvedName);

        final newId = await txn.insert('lists', {
          'name': resolvedName,
          'createdAt': baseCreatedAt + listInsertIndex,
          'budget': (list['budget'] as num?)?.toInt() ?? 0,
        });
        listInsertIndex++;
        listIdMap[oldId] = newId;
      }

      // items INSERT（listId・categoryId を新IDに差し替え）
      for (final item in incomingItems) {
        final oldListId = (item['listId'] as num).toInt();
        final newListId = listIdMap[oldListId];
        if (newListId == null) continue;

        final oldCategoryId = item['categoryId'] != null
            ? (item['categoryId'] as num).toInt()
            : null;
        final newCategoryId = oldCategoryId != null
            ? categoryIdMap[oldCategoryId]
            : null;

        final rawQuantity = item['quantity'];
        final quantity = (rawQuantity is num && rawQuantity.toInt() >= 1)
            ? rawQuantity.toInt()
            : 1;

        final copy = Map<String, dynamic>.from(item)
          ..remove('id')
          ..['listId'] = newListId
          ..['categoryId'] = newCategoryId
          ..['quantity'] = quantity;
        await txn.insert('items', copy);
      }

      // favorites INSERT（sortOrder を MAX+1 から採番・name 重複はスキップ）
      final existingFavRows = await txn.query('favorites', columns: ['name']);
      final existingFavNames =
          existingFavRows.map((r) => r['name'] as String).toSet();
      final maxResult = await txn.rawQuery(
        'SELECT MAX(sortOrder) as maxOrder FROM favorites',
      );
      int nextOrder =
          ((maxResult.first['maxOrder'] as int?) ?? -1) + 1;

      for (final fav in incomingFavorites) {
        final favName = fav['name'] as String;
        if (existingFavNames.contains(favName)) continue;
        existingFavNames.add(favName);

        final oldCategoryId = fav['categoryId'] != null
            ? (fav['categoryId'] as num).toInt()
            : null;
        final newCategoryId = oldCategoryId != null
            ? categoryIdMap[oldCategoryId]
            : null;

        final rawQuantity = fav['quantity'];
        final quantity = (rawQuantity is num && rawQuantity.toInt() >= 1)
            ? rawQuantity.toInt()
            : 1;

        final copy = Map<String, dynamic>.from(fav)
          ..remove('id')
          ..['sortOrder'] = nextOrder++
          ..['categoryId'] = newCategoryId
          ..['quantity'] = quantity;
        await txn.insert('favorites', copy);
        insertedFavCount++;
      }
    });

    return ImportResult(
      listCount: incomingLists.length,
      itemCount: incomingItems.length,
      favoriteCount: insertedFavCount,
      firstNewListId: listIdMap.isNotEmpty ? listIdMap.values.first : null,
    );
  }

  /// リスト名の衝突を解決して一意な名前を返す。
  /// 衝突する場合は末尾に(2)(3)...を付与する。
  static String resolveListName(String name, Set<String> existingNames) {
    if (!existingNames.contains(name)) return name;
    int i = 2;
    while (existingNames.contains('$name($i)')) {
      i++;
    }
    return '$name($i)';
  }
}

import 'package:test/test.dart';
import 'package:shopping_list_app/models/category.dart';
import 'package:shopping_list_app/utils/favorites_section_helper.dart';

void main() {
  group('buildFavoriteSections', () {
    test('カテゴリが1件もない場合は null を返す（フラット表示に切り替える合図）', () {
      final favorites = [
        {'id': 1, 'name': '牛乳', 'categoryId': null},
      ];
      final result =
          buildFavoriteSections(favorites: favorites, categories: []);
      expect(result, isNull);
    });

    test('カテゴリごとにセクションへ分割する（sortOrder順を維持する）', () {
      final categories = [
        Category(id: 1, name: '野菜', sortOrder: 0, createdAt: 0),
        Category(id: 2, name: '肉', sortOrder: 1, createdAt: 0),
      ];
      final favorites = [
        {'id': 1, 'name': 'にんじん', 'categoryId': 1},
        {'id': 2, 'name': '牛肉', 'categoryId': 2},
        {'id': 3, 'name': 'キャベツ', 'categoryId': 1},
      ];
      final result =
          buildFavoriteSections(favorites: favorites, categories: categories)!;
      expect(result.length, 2);
      expect(result[0].title, '野菜');
      expect(result[0].items.map((f) => f['id']), [1, 3]);
      expect(result[1].title, '肉');
      expect(result[1].items.map((f) => f['id']), [2]);
    });

    test('categoryId が null の favorite は「カテゴリなし」セクションに最後にまとまる', () {
      final categories = [
        Category(id: 1, name: '野菜', sortOrder: 0, createdAt: 0),
      ];
      final favorites = [
        {'id': 1, 'name': 'にんじん', 'categoryId': 1},
        {'id': 2, 'name': '謎の商品', 'categoryId': null},
      ];
      final result =
          buildFavoriteSections(favorites: favorites, categories: categories)!;
      expect(result.length, 2);
      expect(result.last.title, 'カテゴリなし');
      expect(result.last.items.single['id'], 2);
    });

    test('存在しないカテゴリIDを指す favorite も「カテゴリなし」セクションに入る', () {
      final categories = [
        Category(id: 1, name: '野菜', sortOrder: 0, createdAt: 0),
      ];
      final favorites = [
        {'id': 1, 'name': '削除済みカテゴリの商品', 'categoryId': 99},
      ];
      final result =
          buildFavoriteSections(favorites: favorites, categories: categories)!;
      expect(result.length, 1);
      expect(result.single.title, 'カテゴリなし');
    });

    test('該当する favorite が1件もないカテゴリのセクションは生成しない', () {
      final categories = [
        Category(id: 1, name: '野菜', sortOrder: 0, createdAt: 0),
        Category(id: 2, name: '肉', sortOrder: 1, createdAt: 0),
      ];
      final favorites = [
        {'id': 1, 'name': 'にんじん', 'categoryId': 1},
      ];
      final result =
          buildFavoriteSections(favorites: favorites, categories: categories)!;
      expect(result.length, 1);
      expect(result.single.title, '野菜');
    });
  });

  group('resolveGlobalFavoriteIndex', () {
    test('セクション内indexから全favoritesリスト上のグローバル位置を算出する', () {
      final allFavorites = [
        {'id': 10, 'name': 'A'},
        {'id': 20, 'name': 'B'},
        {'id': 30, 'name': 'C'},
      ];
      final sectionItems = [
        {'id': 30, 'name': 'C'},
        {'id': 10, 'name': 'A'},
      ];
      expect(
        resolveGlobalFavoriteIndex(
          allFavorites: allFavorites,
          sectionItems: sectionItems,
          indexInSection: 0,
        ),
        2,
      );
      expect(
        resolveGlobalFavoriteIndex(
          allFavorites: allFavorites,
          sectionItems: sectionItems,
          indexInSection: 1,
        ),
        0,
      );
    });

    test('該当する id が全体リストに存在しない場合は -1 を返す', () {
      final allFavorites = [
        {'id': 10, 'name': 'A'},
      ];
      final sectionItems = [
        {'id': 999, 'name': 'X'},
      ];
      expect(
        resolveGlobalFavoriteIndex(
          allFavorites: allFavorites,
          sectionItems: sectionItems,
          indexInSection: 0,
        ),
        -1,
      );
    });
  });
}

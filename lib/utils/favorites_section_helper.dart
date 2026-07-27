import '../models/category.dart';

/// よく買うものの1カテゴリ分の表示セクション。
class FavoriteSection {
  final String title;
  final List<Map<String, dynamic>> items;

  const FavoriteSection({required this.title, required this.items});
}

/// favorites をカテゴリ別セクションに分割する。
///
/// - カテゴリが1件も登録されていない場合は null を返す（呼び出し側でフラット表示に切り替える）。
/// - categoryId が null、または存在しないカテゴリIDを指す favorite は
///   「カテゴリなし」セクションとして最後にまとめる。
/// - 該当する favorite が1件もないカテゴリのセクションは生成しない。
List<FavoriteSection>? buildFavoriteSections({
  required List<Map<String, dynamic>> favorites,
  required List<Category> categories,
}) {
  if (categories.isEmpty) return null;

  final sections = <FavoriteSection>[];
  for (final cat in categories) {
    final items =
        favorites.where((f) => (f['categoryId'] as int?) == cat.id).toList();
    if (items.isEmpty) continue;
    sections.add(FavoriteSection(title: cat.name, items: items));
  }

  final categoryIds = categories.map((c) => c.id).toSet();
  final noCategory = favorites
      .where((f) =>
          f['categoryId'] == null ||
          !categoryIds.contains(f['categoryId'] as int?))
      .toList();
  if (noCategory.isNotEmpty) {
    sections.add(FavoriteSection(title: 'カテゴリなし', items: noCategory));
  }

  return sections;
}

/// カテゴリセクション内の並べ替えindex（indexInSection）を、
/// sortOrder順の全favoritesリスト（allFavorites）上でのグローバル位置に変換する。
///
/// sectionItems[indexInSection] の id を allFavorites 内で検索し、
/// 一致する要素のインデックスを返す。見つからない場合は -1 を返す。
int resolveGlobalFavoriteIndex({
  required List<Map<String, dynamic>> allFavorites,
  required List<Map<String, dynamic>> sectionItems,
  required int indexInSection,
}) {
  final targetId = sectionItems[indexInSection]['id'] as int;
  return allFavorites.indexWhere((f) => f['id'] as int == targetId);
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/models/favorite_suggestion.dart';
import 'package:shopping_list_app/widgets/fields/item_name_field.dart';

FavoriteSuggestion fav(String name,
        {int price = 100, int quantity = 2, int? categoryId, String? cat}) =>
    FavoriteSuggestion(
      name: name,
      price: price,
      quantity: quantity,
      categoryId: categoryId,
      categoryName: cat,
    );

void main() {
  group('FavoriteSuggestion', () {
    test('fromMap は double 値でも変換できる', () {
      final f = FavoriteSuggestion.fromMap({
        'name': '牛乳',
        'price': 198.0,
        'quantity': 2.0,
        'categoryId': 3.0,
      });
      expect(f.price, 198);
      expect(f.quantity, 2);
      expect(f.categoryId, 3);
    });

    test('subtitle は価格0で¥を、カテゴリ未解決でカテゴリ名を省略する', () {
      expect(fav('a', price: 0).subtitle, '×2');
      expect(fav('a', cat: '乳製品').subtitle, '×2　¥100　乳製品');
      expect(fav('a', price: 0, cat: '乳製品').subtitle, '×2　乳製品');
    });
  });

  group('buildNameSuggestions', () {
    test('空欄では候補を出さない', () {
      expect(
        buildNameSuggestions(text: '', history: ['牛乳'], favorites: [fav('牛乳')]),
        isEmpty,
      );
    });

    test('部分一致・大文字小文字無視で絞り込む', () {
      final r = buildNameSuggestions(
        text: 'MI',
        history: ['milk', 'bread'],
        favorites: [fav('Mix')],
      );
      expect(r.map((s) => s.name), ['Mix', 'milk']);
    });

    test('同名は星付きと履歴の両方を表示し、履歴側の重複は除く', () {
      final r = buildNameSuggestions(
        text: '牛',
        history: ['牛乳', '牛乳', '牛肉'],
        favorites: [fav('牛乳')],
      );
      expect(r.map((s) => s.name), ['牛乳', '牛乳', '牛肉']);
      expect(r.map((s) => s.favorite != null), [true, false, false]);
    });

    test('よく買うもの最大5件、合計最大8件', () {
      final favs = List.generate(7, (i) => fav('a$i'));
      final hist = List.generate(10, (i) => 'a-h$i');
      final r = buildNameSuggestions(text: 'a', history: hist, favorites: favs);
      expect(r.length, 8);
      expect(r.where((s) => s.favorite != null).length, 5);
      expect(r.take(5).every((s) => s.favorite != null), isTrue);
    });

    test('よく買うものが少なければ履歴が残り枠を使う', () {
      final r = buildNameSuggestions(
        text: 'a',
        history: List.generate(10, (i) => 'a$i'),
        favorites: [fav('a')],
      );
      expect(r.length, 8);
    });
  });

  group('ItemNameField', () {
    late TextEditingController ctrl;
    late FocusNode focus;
    FavoriteSuggestion? selected;

    setUp(() {
      ctrl = TextEditingController();
      focus = FocusNode();
      selected = null;
    });

    tearDown(() {
      ctrl.dispose();
      focus.dispose();
    });

    Future<void> pump(WidgetTester tester,
        {List<FavoriteSuggestion> favorites = const [], bool callback = true}) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItemNameField(
              controller: ctrl,
              focusNode: focus,
              candidateNames: const ['牛乳(履歴)', 'バナナ'],
              favoriteSuggestions: favorites,
              onFavoriteSelected: callback ? (f) => selected = f : null,
            ),
          ),
        ),
      );
    }

    testWidgets('星付き候補を選ぶとコールバックが呼ばれ、候補が閉じる', (tester) async {
      await pump(tester, favorites: [fav('牛乳', cat: '乳製品')]);
      await tester.enterText(find.byType(TextField), '牛');
      await tester.pump();
      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.text('×2　¥100　乳製品'), findsOneWidget);

      await tester.tap(find.text('牛乳'));
      await tester.pump();
      expect(selected?.name, '牛乳');
      expect(find.byType(ListTile), findsNothing);
      expect(focus.hasFocus, isFalse);
    });

    testWidgets('履歴候補を選ぶと名前のみ反映される', (tester) async {
      await pump(tester, favorites: [fav('牛乳')]);
      await tester.enterText(find.byType(TextField), '牛');
      await tester.pump();
      await tester.tap(find.text('牛乳(履歴)'));
      await tester.pump();
      expect(ctrl.text, '牛乳(履歴)');
      expect(selected, isNull);
      expect(find.byType(ListTile), findsNothing);
    });

    testWidgets('よく買うものを渡さない従来の使い方は履歴のみ表示する', (tester) async {
      await pump(tester, callback: false);
      await tester.enterText(find.byType(TextField), 'バ');
      await tester.pump();
      expect(find.byIcon(Icons.star), findsNothing);
      await tester.tap(find.text('バナナ'));
      await tester.pump();
      expect(ctrl.text, 'バナナ');
    });
  });
}

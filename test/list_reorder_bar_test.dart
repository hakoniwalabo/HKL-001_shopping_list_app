import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/models/shopping_list.dart';
import 'package:shopping_list_app/widgets/list_reorder_bar.dart';

Widget buildApp(List<ShoppingList> lists) {
  return MaterialApp(
    home: Scaffold(
      appBar: AppBar(
        title: const Text('買い物リスト'),
        bottom: ListReorderBar(
          shoppingLists: lists,
          onReorder: (oldIndex, newIndex) async {},
        ),
      ),
      body: const SizedBox(),
    ),
  );
}

void main() {
  group('ListReorderBar', () {
    testWidgets('AppBar.bottomに置いても例外なくレイアウトされ、Chipが表示される', (tester) async {
      final lists = List.generate(
        10,
        (i) => ShoppingList(
          id: i + 1,
          name: 'とても長いリスト名その${i + 1}',
          sortOrder: i,
        ),
      );

      await tester.pumpWidget(buildApp(lists));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(Chip), findsWidgets);
    });

    testWidgets('リストが空でも例外なく、Chipは表示されない', (tester) async {
      await tester.pumpWidget(buildApp([]));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(Chip), findsNothing);
    });
  });
}

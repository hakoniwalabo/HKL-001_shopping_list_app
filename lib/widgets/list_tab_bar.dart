import 'package:flutter/material.dart';

import '../models/shopping_list.dart';

class ListTabBar extends StatelessWidget implements PreferredSizeWidget {
  final List<ShoppingList> shoppingLists;
  final TabController? tabController;
  final void Function(ShoppingList)? onRenameTab;

  const ListTabBar({
    super.key,
    required this.shoppingLists,
    required this.tabController,
    this.onRenameTab,
  });

  @override
  Widget build(BuildContext context) {
    if (shoppingLists.isEmpty || tabController == null) {
      return const SizedBox.shrink();
    }

    return TabBar(
      controller: tabController,
      isScrollable: true,
      tabs: [
        for (final list in shoppingLists)
          GestureDetector(
            // 長押しでタブ名変更
            onLongPress: () => onRenameTab?.call(list),
            child: Tab(text: list.name),
          ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

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
          // GestureDetector を Tab の外ではなく中に置く。
          // TabBar が各タブに被せる InkWell とジェスチャーが競合しないようにするため。
          Tab(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPress: () => onRenameTab?.call(list),
              child: Text(list.name),
            ),
          ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

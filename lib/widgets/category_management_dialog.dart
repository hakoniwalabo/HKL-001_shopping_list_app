import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/category_provider.dart';

Future<void> showCategoryManagementDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => const _CategoryManagementDialog(),
  );
}

class _CategoryManagementDialog extends ConsumerWidget {
  const _CategoryManagementDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoryProvider);
    final categories = categoriesAsync.value ?? [];

    return AlertDialog(
      title: const Text('カテゴリを管理'),
      content: SizedBox(
        width: double.maxFinite,
        child: categories.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('まだカテゴリがありません'),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: categories.length,
                itemBuilder: (ctx, i) {
                  final cat = categories[i];
                  return ListTile(
                    title: Text(cat.name),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: '削除',
                      onPressed: () async {
                        await ref
                            .read(categoryProvider.notifier)
                            .deleteCategory(cat.id!);
                      },
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            String newName = '';
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('カテゴリを追加'),
                content: TextField(
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'カテゴリ名'),
                  onChanged: (v) => newName = v.trim(),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('キャンセル'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('追加'),
                  ),
                ],
              ),
            );
            if (confirmed != true || newName.isEmpty) return;
            await ref.read(categoryProvider.notifier).addCategory(newName);
          },
          child: const Text('＋ カテゴリを追加'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('閉じる'),
        ),
      ],
    );
  }
}

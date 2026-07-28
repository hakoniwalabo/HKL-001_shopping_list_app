import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/purchase_provider.dart';

/// 広告なしアップグレードのダイアログ
class UpgradeDialog extends ConsumerWidget {
  const UpgradeDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.star, color: Colors.amber),
          SizedBox(width: 8),
          Text('広告なしプラン'),
        ],
      ),
      content: const Text(
        '一度購入すると広告が非表示になります。\n\n'
        '端末を変えても「購入を復元」で再適用できます。',
      ),
      actions: [
        // キャンセル
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        // 購入の復元
        TextButton(
          onPressed: () async {
            await ref.read(purchaseProvider.notifier).restore();
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('購入の照合が完了しました')),
              );
            }
          },
          child: const Text('購入を復元'),
        ),
        // 購入する
        FilledButton.icon(
          onPressed: () async {
            Navigator.pop(context); // 先にダイアログを閉じてから Play シートを表示
            final error =
                await ref.read(purchaseProvider.notifier).purchase();
            if (error != null && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(error)),
              );
            }
          },
          icon: const Icon(Icons.star_outline),
          label: const Text('購入する'),
        ),
      ],
    );
  }
}

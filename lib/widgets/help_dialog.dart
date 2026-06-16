import 'package:flutter/material.dart';

class HelpDialog extends StatelessWidget {
  const HelpDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('使い方'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            _HelpItem(
              icon: Icons.add_circle_outline,
              label: '商品を追加',
              description: '右下の「追加」ボタンをタップ\n'
                  '「追加」を押すと続けて入力できます（まとめて追加できます）。終わったら「閉じる」',
            ),
            _HelpItem(
              icon: Icons.edit_outlined,
              label: '商品を編集',
              description: '商品名をタップするとダイアログが開きます',
            ),
            _HelpItem(
              icon: Icons.swipe_left_alt,
              label: '商品を削除',
              description: '商品を左にスワイプ\n削除後は「元に戻す」で5秒以内に復元できます',
            ),
            _HelpItem(
              icon: Icons.check_circle_outline,
              label: '購入済みにする',
              description: 'チェックボックスをタップ',
            ),
            _HelpItem(
              icon: Icons.delete_sweep,
              label: '購入済みを一括削除',
              description: '「購入済み削除」ボタンを押して確認後に削除\nUndoで一括復元もできます',
            ),
            _HelpItem(
              icon: Icons.drag_handle,
              label: '並び替え',
              description: '未購入商品の右端のハンドルをドラッグ',
            ),
            _HelpItem(
              icon: Icons.touch_app,
              label: 'リスト名を変更',
              description: 'タブを長押し',
            ),
            _HelpItem(
              icon: Icons.playlist_add,
              label: 'リストを追加',
              description: 'AppBar右上の「＋」ボタン（最大10件）',
            ),
            _HelpItem(
              icon: Icons.delete_outline,
              label: 'リストを削除',
              description: 'AppBar右上の「⋮」→「リストを削除」\n（最後のリストは削除できません）',
            ),
            _HelpItem(
              icon: Icons.drive_file_move_outline,
              label: '別リストへ移動',
              description: '商品を長押しして移動先のリストを選択',
            ),
            _HelpItem(
              icon: Icons.history,
              label: '入力履歴から補完',
              description: '商品名入力時に過去の入力履歴がサジェストされます',
            ),
            _HelpItem(
              icon: Icons.copy_outlined,
              label: 'リストを複製',
              description: 'AppBar右上の「複製」ボタン\n全商品をコピーした新しいリストを作成します（チェックはリセット）',
            ),
            _HelpItem(
              icon: Icons.favorite_border,
              label: 'よく買うものから追加',
              description: 'AppBar右上のハートボタンから定番商品を登録・管理できます。チェックして「リストに追加」を押すと一括追加されます。商品をタップすると価格・個数を編集できます',
            ),
            _HelpItem(
              icon: Icons.share_outlined,
              label: 'テキストで共有',
              description: 'AppBar右上の「⋮」→「テキストで共有」\nリストの内容をテキストとして他のアプリに送れます',
            ),
            _HelpItem(
              icon: Icons.backup_outlined,
              label: 'バックアップ',
              description: 'AppBar右上の「⋮」→「バックアップ」\nデータをJSONファイルとして書き出します。「共有」でメール・クラウドへ送るか「端末に保存」でダウンロードフォルダに保存できます',
            ),
            _HelpItem(
              icon: Icons.restore_outlined,
              label: 'バックアップデータを読み込む',
              description: 'AppBar右上の「⋮」→「バックアップデータを読み込む」\nバックアップファイルを選択して、既存データに追加読み込みします',
            ),
            _HelpItem(
              icon: Icons.star_outline,
              label: '広告を非表示にする',
              description: 'AppBar右上の「⋮」→「広告を削除」から買い切り購入',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('閉じる'),
        ),
      ],
    );
  }
}

class _HelpItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;

  const _HelpItem({
    required this.icon,
    required this.label,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

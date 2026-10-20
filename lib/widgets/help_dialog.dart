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
              description: '右下の「追加」ボタンをタップ\n「追加」を押すと続けて入力できます（まとめて追加できます）。終わったら「閉じる」\n「よく買うものに登録」チェックで同時登録可能',
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
              label: 'チェック済みにする',
              description: 'チェックボックスをタップ',
            ),
            _HelpItem(
              icon: Icons.delete_sweep,
              label: 'チェック済みを一括削除',
              description: '「チェック済み削除」ボタンを押して確認後に削除\nUndoで一括復元もできます',
            ),
            _HelpItem(
              icon: Icons.drag_handle,
              label: '並び替え',
              description: '未チェック商品の右端のハンドルをドラッグ',
            ),
            _HelpItem(
              icon: Icons.touch_app,
              label: 'リスト名を変更',
              description: 'リスト名を長押し',
            ),
            _HelpItem(
              icon: Icons.playlist_add,
              label: 'リストを追加',
              description: 'AppBar右上の「＋」ボタン（最大10件）',
            ),
            _HelpItem(
              icon: Icons.reorder,
              label: 'リストの並び替え',
              description:
                  'AppBar右上の並び替えボタン（≡アイコン）をタップすると並び替えモードになります\n表示されたハンドルをドラッグして順番を変更できます。再度ボタンを押すと通常表示に戻ります',
            ),
            _HelpItem(
              icon: Icons.delete_outline,
              label: 'リストを削除',
              description: 'AppBar右上の「⋮」→「リストを削除」\n（最後のリストは削除できません）',
            ),
            _HelpItem(
              icon: Icons.savings_outlined,
              label: 'リストの予算を設定',
              description:
                  '合計表示の上の「予算 -」（または金額）をタップすると入力欄が開きます\n'
                  '空欄のまま保存すると未設定（-表示）に戻ります',
            ),
            _HelpItem(
              icon: Icons.drive_file_move_outline,
              label: '別リストへ移動',
              description: '商品を長押しするとメニューが表示されます\n「別のリストに移動」で移動先リストを選択、「よく買うものに登録」でよく買うものに追加できます',
            ),
            _HelpItem(
              icon: Icons.search,
              label: '商品名の候補表示',
              description: '商品名入力中、現在のリスト内にある商品名と「よく買うもの」が候補として表示されます（最大8件）\n星マークの候補は「よく買うもの」で、選ぶと名前・個数・価格・カテゴリがまとめて入力されます（確認・修正して「追加」）\n星なしの候補は名前のみ入力されます（商品の追加時のみ。編集時は「よく買うもの」は表示されません）',
            ),
            _HelpItem(
              icon: Icons.copy_outlined,
              label: 'リストを複製',
              description: 'AppBar右上の「複製」ボタン\n全商品をコピーした新しいリストを作成します（チェックはリセット）',
            ),
            _HelpItem(
              icon: Icons.favorite_border,
              label: 'よく買うものから追加',
              description: 'AppBar右上のハートボタンから、定番商品を管理する画面が開きます（カテゴリ別に一覧表示されます）。チェックして「リストに追加」を押すと一括追加されます。商品をタップすると価格・個数・カテゴリを編集できます。検索窓で商品名を絞り込むことができ、各カテゴリ内はドラッグで並べ替えできます',
            ),
            _HelpItem(
              icon: Icons.share_outlined,
              label: 'テキストで共有',
              description: 'AppBar右上の「⋮」→「テキストで共有」\nリストの内容をテキストとして他のアプリに送れます',
            ),
            _HelpItem(
              icon: Icons.send_outlined,
              label: 'リストを共有（読み込み用）',
              description: 'AppBar右上の「⋮」→「リストを共有（読み込み用）」\n未チェック商品をJSONファイルとして送信。受け取った側は「読み込む」から取り込めます',
            ),
            _HelpItem(
              icon: Icons.backup_outlined,
              label: 'バックアップ',
              description: 'AppBar右上の「⋮」→「バックアップ」\nデータをJSONファイルとして書き出します。「共有」でメール・クラウドへ送るか「端末に保存」で保存先を選んで保存できます',
            ),
            _HelpItem(
              icon: Icons.restore_outlined,
              label: '読み込む（バックアップ／共有リスト）',
              description: 'AppBar右上の「⋮」→「読み込む（バックアップ／共有リスト）」\nバックアップや共有されたリストのファイルを選択して、既存データに追加読み込みします',
            ),
            _HelpItem(
              icon: Icons.label_outline,
              label: 'カテゴリを管理',
              description: 'AppBar右上の「⋮」→「カテゴリを管理」\n'
                  'カテゴリを作成・削除できます。商品の追加・編集画面でカテゴリを設定すると、リストがカテゴリ別に整理されます',
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

import 'package:flutter/material.dart';
import '../database/database_helper.dart';

class HistorySelectDialog extends StatefulWidget {
  final Future<void> Function(List<String> names) onRegister;

  const HistorySelectDialog({super.key, required this.onRegister});

  @override
  State<HistorySelectDialog> createState() => _HistorySelectDialogState();
}

class _HistorySelectDialogState extends State<HistorySelectDialog> {
  List<String> _allNames = [];
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final names = await DatabaseHelper.instance.getHistoryNames();
    if (!mounted) return;
    setState(() {
      _allNames = names;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('履歴から登録'),
      content: SizedBox(
        width: double.maxFinite,
        child: _allNames.isEmpty
            ? const Text('履歴がありません')
            : ListView.builder(
                shrinkWrap: true,
                itemCount: _allNames.length,
                itemBuilder: (_, i) {
                  final name = _allNames[i];
                  return CheckboxListTile(
                    value: _selected.contains(name),
                    title: Text(name),
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selected.add(name);
                        } else {
                          _selected.remove(name);
                        }
                      });
                    },
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () async {
                  final names = _selected.toList();
                  Navigator.pop(context);
                  await widget.onRegister(names);
                },
          child: const Text('登録'),
        ),
      ],
    );
  }
}

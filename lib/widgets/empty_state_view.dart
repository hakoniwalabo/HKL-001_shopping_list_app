import 'package:flutter/material.dart';

class EmptyStateView extends StatelessWidget {
  const EmptyStateView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),

          SizedBox(height: 16),

          Text('＋ボタンから追加してください'),
        ],
      ),
    );
  }
}

class ShoppingList {
  final int? id;
  final String name;
  final int createdAt;

  ShoppingList({this.id, required this.name, int? createdAt})
    : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'createdAt': createdAt};
  }

  factory ShoppingList.fromMap(Map<String, dynamic> map) {
    return ShoppingList(
      id: map['id'],
      name: map['name'],
      createdAt: map['createdAt'],
    );
  }
}

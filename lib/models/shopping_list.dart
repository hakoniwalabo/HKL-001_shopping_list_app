class ShoppingList {
  final int? id;
  final String name;
  final int createdAt;
  final int budget;
  final int sortOrder;

  ShoppingList({
    this.id,
    required this.name,
    int? createdAt,
    this.budget = 0,
    this.sortOrder = 0,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt,
      'budget': budget,
      'sortOrder': sortOrder,
    };
  }

  factory ShoppingList.fromMap(Map<String, dynamic> map) {
    return ShoppingList(
      id: map['id'],
      name: map['name'],
      createdAt: map['createdAt'],
      budget: map['budget'] ?? 0,
      sortOrder: map['sortOrder'] ?? 0,
    );
  }

  ShoppingList copyWith({
    int? id,
    String? name,
    int? createdAt,
    int? budget,
    int? sortOrder,
  }) {
    return ShoppingList(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      budget: budget ?? this.budget,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

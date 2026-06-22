class Category {
  final int? id;
  final String name;
  final int sortOrder;
  final int createdAt;

  Category({
    this.id,
    required this.name,
    this.sortOrder = 0,
    int? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'sortOrder': sortOrder,
        'createdAt': createdAt,
      };

  factory Category.fromMap(Map<String, dynamic> map) => Category(
        id: map['id'] != null ? (map['id'] as num).toInt() : null,
        name: map['name'] as String,
        sortOrder: (map['sortOrder'] as num).toInt(),
        createdAt: (map['createdAt'] as num).toInt(),
      );
}

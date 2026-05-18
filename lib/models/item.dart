class Item {
  final String name;
  final int price;
  final double taxRate;
  final bool isChecked;
  final int? id;
  final int createdAt;
  final int sortOrder;

  Item({
    required this.name,
    required this.price,
    required this.taxRate,
    this.isChecked = false,
    this.id,
    int? createdAt,
    this.sortOrder = 0,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'taxRate': taxRate,
      'isChecked': isChecked ? 1 : 0,
      'createdAt': createdAt,
      'sortOrder': sortOrder,
    };
  }

  factory Item.fromMap(Map<String, dynamic> map) {
    return Item(
      id: map['id'],
      name: map['name'],
      price: map['price'],
      taxRate: map['taxRate'],
      isChecked: map['isChecked'] == 1,
      createdAt: map['createdAt'],
      sortOrder: map['sortOrder'],
    );
  }

  Item copyWith({
    String? name,
    int? price,
    double? taxRate,
    bool? isChecked,
    int? id,
    int? createdAt,
    int? sortOrder,
  }) {
    return Item(
      name: name ?? this.name,
      price: price ?? this.price,
      taxRate: taxRate ?? this.taxRate,
      isChecked: isChecked ?? this.isChecked,
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

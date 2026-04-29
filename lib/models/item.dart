class Item {
  String name;
  int price;
  double taxRate;
  bool isChecked;
  int? id;
  int? createdAt;
  int? sortOrder;

  Item({
    required this.name,
    required this.price,
    required this.taxRate,
    this.isChecked = false,
    int? createdAt,
    this.sortOrder,
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
      name: map['name'],
      price: map['price'],
      taxRate: map['taxRate'],
      isChecked: map['isChecked'] == 1,
      createdAt: map['createdAt'],
      sortOrder: map['sortOrder'],
    )..id = map['id'];
  }
}

class Item {
  final String name;
  final int price; // 税込単価（追加時は税込価格をそのまま保存、taxRate=0.0固定）
  final double taxRate;
  final bool isChecked;
  final int? id;
  final int createdAt;
  final int sortOrder;
  final int quantity;
  final String memo;
  final int listId;

  Item({
    required this.name,
    required this.price,
    required this.taxRate,
    this.isChecked = false,
    this.id,
    int? createdAt,
    this.sortOrder = 0,
    this.quantity = 1,
    this.memo = '',
    required this.listId,
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
      'quantity': quantity,
      'memo': memo,
      'listId': listId,
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
      quantity: map['quantity'] ?? 1,
      memo: map['memo'] ?? '',
      listId: map['listId'],
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
    int? quantity,
    String? memo,
    int? listId,
  }) {
    return Item(
      name: name ?? this.name,
      price: price ?? this.price,
      taxRate: taxRate ?? this.taxRate,
      isChecked: isChecked ?? this.isChecked,
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      sortOrder: sortOrder ?? this.sortOrder,
      quantity: quantity ?? this.quantity,
      memo: memo ?? this.memo,
      listId: listId ?? this.listId,
    );
  }
}

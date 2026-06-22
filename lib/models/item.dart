class Item {
  final String name;
  final int price; // 税込単価
  final bool isChecked;
  final int? id;
  final int createdAt;
  final int sortOrder;
  final int quantity;
  final String memo;
  final int listId;
  final int? categoryId;

  Item({
    required this.name,
    required this.price,
    this.isChecked = false,
    this.id,
    int? createdAt,
    this.sortOrder = 0,
    this.quantity = 1,
    this.memo = '',
    required this.listId,
    this.categoryId,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'isChecked': isChecked ? 1 : 0,
      'createdAt': createdAt,
      'sortOrder': sortOrder,
      'quantity': quantity,
      'memo': memo,
      'listId': listId,
      'categoryId': categoryId,
    };
  }

  factory Item.fromMap(Map<String, dynamic> map) {
    return Item(
      id: map['id'],
      name: map['name'],
      price: map['price'],
      isChecked: map['isChecked'] == 1,
      createdAt: map['createdAt'],
      sortOrder: map['sortOrder'],
      quantity: map['quantity'] ?? 1,
      memo: map['memo'] ?? '',
      listId: map['listId'],
      categoryId: map['categoryId'] as int?,
    );
  }

  Item copyWith({
    String? name,
    int? price,
    bool? isChecked,
    int? id,
    int? createdAt,
    int? sortOrder,
    int? quantity,
    String? memo,
    int? listId,
    int? categoryId,
  }) {
    return Item(
      name: name ?? this.name,
      price: price ?? this.price,
      isChecked: isChecked ?? this.isChecked,
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      sortOrder: sortOrder ?? this.sortOrder,
      quantity: quantity ?? this.quantity,
      memo: memo ?? this.memo,
      listId: listId ?? this.listId,
      categoryId: categoryId ?? this.categoryId,
    );
  }

  // copyWith は null を「変更なし」と解釈するため、categoryId を明示的に null にするにはこちらを使う。
  Item copyWithNullableCategory({required int? categoryId}) {
    return Item(
      name: name,
      price: price,
      isChecked: isChecked,
      id: id,
      createdAt: createdAt,
      sortOrder: sortOrder,
      quantity: quantity,
      memo: memo,
      listId: listId,
      categoryId: categoryId,
    );
  }
}

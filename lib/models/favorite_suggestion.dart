class FavoriteSuggestion {
  final String name;
  final int price;
  final int quantity;
  final int? categoryId;
  final String? categoryName;

  const FavoriteSuggestion({
    required this.name,
    required this.price,
    required this.quantity,
    this.categoryId,
    this.categoryName,
  });

  factory FavoriteSuggestion.fromMap(Map<String, dynamic> map) =>
      FavoriteSuggestion(
        name: map['name'] as String,
        price: ((map['price'] as num?) ?? 0).toInt(),
        quantity: ((map['quantity'] as num?) ?? 1).toInt(),
        categoryId: map['categoryId'] != null
            ? (map['categoryId'] as num).toInt()
            : null,
      );

  FavoriteSuggestion withCategoryName(String? categoryName) =>
      FavoriteSuggestion(
        name: name,
        price: price,
        quantity: quantity,
        categoryId: categoryId,
        categoryName: categoryName,
      );

  String get subtitle => [
        '×$quantity',
        if (price > 0) '¥$price',
        ?categoryName,
      ].join('　');
}

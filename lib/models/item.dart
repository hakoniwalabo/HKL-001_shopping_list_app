class Item {
  String name;
  int price;
  double taxRate;
  bool isChecked;

  Item({
    required this.name,
    required this.price,
    required this.taxRate,
    this.isChecked = false,
  });
}

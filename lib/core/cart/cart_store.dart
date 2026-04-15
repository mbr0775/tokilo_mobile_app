import 'package:flutter/material.dart';

class CartItem {
  final String id;
  final String name;
  final String? imageUrl;
  final String? price;
  final String? category;
  int quantity;

  CartItem({
    required this.id,
    required this.name,
    this.imageUrl,
    this.price,
    this.category,
    this.quantity = 1,
  });

  double get numericPrice {
    if (price == null || price!.isEmpty) return 0;
    final cleaned = price!.replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(cleaned) ?? 0;
  }

  double get subtotal => numericPrice * quantity;
}

class CartStore extends ChangeNotifier {
  static final CartStore instance = CartStore._();
  CartStore._();

  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);
  int get totalCount => _items.fold(0, (sum, i) => sum + i.quantity);
  double get totalPrice => _items.fold(0, (sum, i) => sum + i.subtotal);
  bool get isEmpty => _items.isEmpty;

  bool contains(String id) => _items.any((i) => i.id == id);

  void add(Map<String, dynamic> product) {
    final id = product['id']?.toString() ?? '';
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx != -1) {
      _items[idx].quantity++;
    } else {
      _items.add(CartItem(
        id:       id,
        name:     product['name']      as String? ?? '',
        imageUrl: product['image_url'] as String?,
        price:    product['price']     as String?,
        category: product['category']  as String?,
      ));
    }
    notifyListeners();
  }

  void remove(String id) {
    _items.removeWhere((i) => i.id == id);
    notifyListeners();
  }

  void increment(String id) {
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx != -1) { _items[idx].quantity++; notifyListeners(); }
  }

  void decrement(String id) {
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx != -1) {
      if (_items[idx].quantity <= 1) {
        _items.removeAt(idx);
      } else {
        _items[idx].quantity--;
      }
      notifyListeners();
    }
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
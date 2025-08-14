import 'package:flutter/foundation.dart';

class CartItem {
  final String id;
  final String name;
  final double price;
  final bool hasImage;
  final bool isVeg;
  int quantity;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.hasImage,
    required this.isVeg,
    this.quantity = 1,
  });
}

class CartProvider with ChangeNotifier {
  Map<String, CartItem> _items = {};
  int? _canteenId;

  Map<String, CartItem> get items {
    return {..._items};
  }

  int? get canteenId => _canteenId;

  int get itemCount {
    return _items.values.fold(0, (sum, item) => sum + item.quantity);
  }

  double get totalAmount {
    var total = 0.0;
    _items.forEach((key, cartItem) {
      total += cartItem.price * cartItem.quantity;
    });
    return total;
  }

  void addItem(String productId, String name, double price, int canteenId, bool hasImage, bool isVeg) {
    if (_canteenId != null && _canteenId != canteenId) {
      clear();
    }
    _canteenId = canteenId;

    if (_items.containsKey(productId)) {
      _items.update(
        productId,
        (existingCartItem) => CartItem(
          id: existingCartItem.id,
          name: existingCartItem.name,
          price: existingCartItem.price,
          hasImage: existingCartItem.hasImage,
          isVeg: existingCartItem.isVeg,
          quantity: existingCartItem.quantity + 1,
        ),
      );
    } else {
      _items.putIfAbsent(
        productId,
        () => CartItem(
          id: productId,
          name: name,
          price: price,
          hasImage: hasImage,
          isVeg: isVeg,
        ),
      );
    }
    notifyListeners();
  }

  void removeSingleItem(String productId) {
    if (!_items.containsKey(productId)) return;
    if (_items[productId]!.quantity > 1) {
      _items.update(
        productId,
        (existingCartItem) => CartItem(
          id: existingCartItem.id,
          name: existingCartItem.name,
          price: existingCartItem.price,
          quantity: existingCartItem.quantity - 1,
          hasImage: existingCartItem.hasImage,
          isVeg: existingCartItem.isVeg,
        ),
      );
    } else {
      _items.remove(productId);
      if (_items.isEmpty) {
        _canteenId = null;
      }
    }
    notifyListeners();
  }

  void clear() {
    _items = {};
    _canteenId = null;
    notifyListeners();
  }
}
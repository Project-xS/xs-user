import 'package:flutter/material.dart';

class CartItem {
  final String id;
  final String name;
  final double price;
  final String? pic;
  final String? etag;
  final bool isVeg;
  final int stock;
  int quantity;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.pic,
    required this.etag,
    required this.isVeg,
    required this.stock,
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

  void addItem(String productId, String name, double price, int canteenId, String? pic, String? etag, bool isVeg, int stock) {
    if (_canteenId != null && _canteenId != canteenId) {
      clear();
    }
    _canteenId = canteenId;

    if (_items.containsKey(productId)) {
      if (_items[productId]!.quantity >= 20) {
        SnackBar(content: Text('You can only add up to 20 of each item.'));
        return;
      }
      if(stock != -1 && _items[productId]!.quantity >= stock){
        SnackBar(content: Text('Can\'t add more items, stock limit reached.'));
        return;
      }
      _items.update(
        productId,
        (existingCartItem) => CartItem(
          id: existingCartItem.id,
          name: existingCartItem.name,
          price: existingCartItem.price,
          pic: existingCartItem.pic,
          etag: existingCartItem.etag,
          isVeg: existingCartItem.isVeg,
          stock: existingCartItem.stock,
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
          pic: pic,
          etag: etag,
          stock: stock,
          quantity: 1,
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
          pic: existingCartItem.pic,
          etag: existingCartItem.etag,
          stock: existingCartItem.stock,
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
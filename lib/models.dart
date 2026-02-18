import 'package:flutter/foundation.dart';

class StatusResponse {
  final String status;
  final String? error;

  StatusResponse({required this.status, this.error});

  factory StatusResponse.fromJson(Map<String, dynamic> json) {
    return StatusResponse(status: json['status'], error: json['error']);
  }
}

class HoldResponse {
  final String status;
  final int? holdId;
  final int? expiresAt;
  final String? error;

  HoldResponse({required this.status, this.holdId, this.expiresAt, this.error});

  factory HoldResponse.fromJson(Map<String, dynamic> json) {
    return HoldResponse(
      status: json['status'],
      holdId: json['hold_id'],
      expiresAt: json['expires_at'],
      error: json['error'],
    );
  }
}

class ConfirmResponse {
  final String status;
  final int? orderId;
  final String? error;

  ConfirmResponse({required this.status, this.orderId, this.error});

  factory ConfirmResponse.fromJson(Map<String, dynamic> json) {
    return ConfirmResponse(
      status: json['status'],
      orderId: json['order_id'],
      error: json['error'],
    );
  }
}

class OrderItem {
  final String description;
  final bool isVeg;
  final String name;
  final String? picEtag;
  final String? picLink;
  final int quantity;
  final int price;

  OrderItem({
    required this.description,
    required this.isVeg,
    required this.name,
    this.picEtag,
    this.picLink,
    required this.quantity,
    required this.price,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      description: json['description'] ?? '',
      isVeg: json['is_veg'] ?? false,
      name: json['name'] ?? '',
      picEtag: json['pic_etag'],
      picLink: json['pic_link'],
      quantity: json['quantity'] ?? 0,
      price: json['price'] ?? 0,
    );
  }
}

class Order {
  final int orderId;
  final bool orderStatus;
  final int orderedAtMs; // Always stored as milliseconds since epoch
  final int totalPrice;
  final List<OrderItem> items;
  final String? deliverAt;
  final String canteenName;

  Order({
    required this.orderId,
    required this.orderStatus,
    required this.orderedAtMs,
    required this.totalPrice,
    required this.items,
    this.deliverAt,
    required this.canteenName,
  });

  /// Returns the DateTime for when this order was placed.
  DateTime get orderedAtDateTime =>
      DateTime.fromMillisecondsSinceEpoch(orderedAtMs);

  factory Order.fromJson(Map<String, dynamic> json) {
    debugPrint('Order.fromJson raw: $json');
    final itemsList = (json['items'] as List?) ?? [];
    List<OrderItem> items = itemsList
        .map((i) => OrderItem.fromJson(i as Map<String, dynamic>))
        .toList();

    // Parse ordered_at: backend sends int64.
    // Detect whether it's seconds or milliseconds:
    //   - If > 1e12, it's likely milliseconds
    //   - Otherwise, it's seconds and needs *1000
    final rawOrderedAt = json['ordered_at'];
    int orderedAtMs = 0;
    int? orderedAtValue;
    if (rawOrderedAt is int) {
      orderedAtValue = rawOrderedAt;
    } else if (rawOrderedAt is double) {
      orderedAtValue = rawOrderedAt.round();
    } else if (rawOrderedAt is String) {
      orderedAtValue = int.tryParse(rawOrderedAt);
      if (orderedAtValue == null) {
        final parsedDouble = double.tryParse(rawOrderedAt);
        if (parsedDouble != null) {
          orderedAtValue = parsedDouble.round();
        }
      }
    }

    if (orderedAtValue != null && orderedAtValue > 0) {
      if (orderedAtValue > 1e12) {
        // Already in milliseconds
        orderedAtMs = orderedAtValue;
      } else {
        // In seconds, convert to milliseconds
        orderedAtMs = orderedAtValue * 1000;
      }
    }
    debugPrint(
      'Order.fromJson: orderId=${json['order_id']}, rawOrderedAt=$rawOrderedAt, orderedAtMs=$orderedAtMs, items=${items.length}',
    );

    return Order(
      orderId: json['order_id'] ?? 0,
      orderStatus:
          json['order_status'] ?? false, // Default to false (active) if missing
      orderedAtMs: orderedAtMs,
      totalPrice: json['total_price'] ?? 0,
      items: items,
      deliverAt: json['deliver_at']?.toString(),
      canteenName: json['canteen_name'] ?? 'Unknown Canteen',
    );
  }
}

class OrderResponse {
  final List<Order> data;
  final String? error;
  final String status;

  OrderResponse({required this.data, this.error, required this.status});

  factory OrderResponse.fromJson(Map<String, dynamic> json) {
    List<Order> orders = [];
    if (json['data'] is List) {
      var dataList = json['data'] as List;
      orders = dataList.map((i) => Order.fromJson(i)).toList();
    } else if (json['data'] is Map<String, dynamic>) {
      orders = [Order.fromJson(json['data'])];
    }
    orders.sort((a, b) => b.orderId.compareTo(a.orderId));

    return OrderResponse(
      data: orders,
      error: json['error'],
      status: json['status'],
    );
  }
}

class NewUser {
  final String rfid;
  final String name;
  final String email;

  NewUser({required this.rfid, required this.name, required this.email});

  Map<String, dynamic> toJson() => {'rfid': rfid, 'name': name, 'email': email};
}

class LoginRequest {
  final String email;

  LoginRequest({required this.email});

  Map<String, dynamic> toJson() => {'email': email};
}

class HoldRequest {
  final List<int> itemIds;
  final String? deliverAt;

  HoldRequest({required this.itemIds, this.deliverAt});

  Map<String, dynamic> toJson() {
    final payload = <String, dynamic>{'item_ids': itemIds};
    if (deliverAt != null) {
      payload['deliver_at'] = deliverAt;
    }
    return payload;
  }
}

class Canteen {
  final int id;
  final String name;
  final String location;
  final String? pic;
  final String? etag;
  final double rating;

  Canteen({
    required this.id,
    required this.name,
    required this.location,
    required this.pic,
    required this.etag,
    required this.rating,
  });

  factory Canteen.fromJson(Map<String, dynamic> json) {
    return Canteen(
      id: json['canteen_id'],
      name: json['canteen_name'],
      location: json['location'],
      pic: json['pic_link'],
      etag: json['pic_etag']?.replaceAll(RegExp(r'["\\]'), ''),
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class Item {
  final int id;
  final String name;
  final String? description;
  final double price;
  final String? pic;
  final String? etag;
  final int canteenId;
  final bool isVeg;
  final bool isAvailable;
  final int stock;

  Item({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.pic,
    required this.etag,
    required this.canteenId,
    required this.isVeg,
    required this.isAvailable,
    required this.stock,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['item_id'],
      name: json['name'],
      description: json['description'],
      price: (json['price'] as num).toDouble(),
      pic: json['pic_link'],
      etag: json['pic_etag']?.replaceAll(RegExp(r'["\\]'), ''),
      canteenId: json['canteen_id'],
      isVeg: json['is_veg'],
      isAvailable: json['is_available'] || json['stock'] == -1,
      stock: json['stock'],
    );
  }
}

class User {
  final int id;
  final String rfid;
  final String name;
  final String email;
  final String? profilePictureUrl;

  User({
    required this.id,
    required this.rfid,
    required this.name,
    required this.email,
    this.profilePictureUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      rfid: json['rfid'],
      name: json['name'],
      email: json['email'],
      profilePictureUrl: json['profile_picture_url'],
    );
  }
}

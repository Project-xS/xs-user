class StatusResponse {
  final String status;
  final String? error;

  StatusResponse({required this.status, this.error});

  factory StatusResponse.fromJson(Map<String, dynamic> json) {
    return StatusResponse(
      status: json['status'],
      error: json['error'],
    );
  }
}

class OrderItem {
  final int canteenId;
  final String description;
  final bool isVeg;
  final int itemId;
  final String name;
  final String? picEtag;
  final String? picLink;
  final int quantity;

  OrderItem({
    required this.canteenId,
    required this.description,
    required this.isVeg,
    required this.itemId,
    required this.name,
    this.picEtag,
    this.picLink,
    required this.quantity,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      canteenId: json['canteen_id'],
      description: json['description'],
      isVeg: json['is_veg'],
      itemId: json['item_id'],
      name: json['name'],
      picEtag: json['pic_etag'],
      picLink: json['pic_link'],
      quantity: json['quantity'],
    );
  }
}

class Order {
  final int orderId;
  final bool orderStatus;
  final int orderedAt;
  final int totalPrice;
  final List<OrderItem> items;

  Order({
    required this.orderId,
    required this.orderStatus,
    required this.orderedAt,
    required this.totalPrice,
    required this.items,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    var itemsList = json['items'] as List;
    List<OrderItem> items = itemsList.map((i) => OrderItem.fromJson(i)).toList();

    return Order(
      orderId: json['order_id'],
      orderStatus: json['order_status'] ?? false,
      orderedAt: json['ordered_at'],
      totalPrice: json['total_price'],
      items: items,
    );
  }
}

class OrderResponse {
  final List<Order> data;
  final String? error;
  final String status;

  OrderResponse({
    required this.data,
    this.error,
    required this.status,
  });

  factory OrderResponse.fromJson(Map<String, dynamic> json) {
    List<Order> orders = [];
    if (json['data'] is List) {
      var dataList = json['data'] as List;
      orders = dataList.map((i) => Order.fromJson(i)).toList();
    } else if (json['data'] is Map<String, dynamic>) {
      orders = [Order.fromJson(json['data'])];
    }
    orders.sort((a,b) => b.orderId.compareTo(a.orderId));

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

  Map<String, dynamic> toJson() => {
    'rfid': rfid,
    'name': name,
    'email': email,
  };
}

class LoginRequest {
  final String email;

  LoginRequest({required this.email});

  Map<String, dynamic> toJson() => {
    'email': email,
  };
}

class NewOrder {
  final int userId;
  final List<int> itemIds;
  final String deliverAt;

  NewOrder({required this.userId, required this.itemIds, required this.deliverAt});

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'item_ids': itemIds,
    'deliver_at': deliverAt,
  };
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

class ApiResponse {
  final String status;
  final String? error;
  final dynamic data;

  ApiResponse({required this.status, this.error, this.data});

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse(
      status: json['status'],
      error: json['error'],
      data: json['data'],
    );
  }
}

class OrderItem {
  final String canteenName;
  final String name;
  final int quantity;
  final bool isVeg;
  final bool? picLink;
  final String? description;

  OrderItem({
    required this.canteenName,
    required this.name,
    required this.quantity,
    required this.isVeg,
    this.picLink,
    this.description,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      canteenName: json['canteen_name'],
      name: json['name'],
      quantity: json['quantity'],
      isVeg: json['is_veg'],
      picLink: json['pic_link'] as bool?,
      description: json['description'],
    );
  }
}

class OrderData {
  final int orderId;
  final int totalPrice;
  final String deliverAt;
  final List<OrderItem> items;

  OrderData({
    required this.orderId,
    required this.totalPrice,
    required this.deliverAt,
    required this.items,
  });

  factory OrderData.fromJson(Map<String, dynamic> json) {
    return OrderData(
      orderId: json['order_id'],
      totalPrice: json['total_price'],
      deliverAt: json['deliver_at'],
      items: (json['items'] as List).map((item) => OrderItem.fromJson(item)).toList(),
    );
  }
}

class OrderResponse {
  final String status;
  final String? error;
  final List<OrderData>? data;

  OrderResponse({required this.status, this.error, this.data});

  factory OrderResponse.fromJson(Map<String, dynamic> json) {
    dynamic dataJson = json['data'];
    List<OrderData>? parsedData;

    if (dataJson is List) {
      parsedData = dataJson.map((item) => OrderData.fromJson(item)).toList();
    } else if (dataJson is Map<String, dynamic>) {
      parsedData = [OrderData.fromJson(dataJson)];
    }

    return OrderResponse(
      status: json['status'],
      error: json['error'],
      data: parsedData,
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
  final bool hasImage;
  final double rating;

  Canteen({
    required this.id,
    required this.name,
    required this.location,
    required this.hasImage,
    required this.rating,
  });

  factory Canteen.fromJson(Map<String, dynamic> json) {
    return Canteen(
      id: json['canteen_id'],
      name: json['canteen_name'],
      location: json['location'],
      hasImage: json['pic_link'] ?? false,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class Item {
  final int id;
  final String name;
  final String? description;
  final double price;
  final bool hasImage;
  final int canteenId;
  final bool isVeg;
  final bool isAvailable;
  final int stock;

  Item({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.hasImage,
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
      hasImage: json['pic_link'] ?? false,
      canteenId: json['canteen_id'],
      isVeg: json['is_veg'],
      isAvailable: json['is_available'],
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

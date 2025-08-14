
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

class ApiService {
  static const String baseUrl = 'https://proj-xs.fly.dev';

  Future<ApiResponse> createUser(String rfid, String name, String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/create'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(NewUser(rfid: rfid, name: name, email: email).toJson()),
    );

    if (response.statusCode == 200 || response.statusCode == 409) {
      return ApiResponse.fromJson(jsonDecode(response.body));
    } else {
      final errorResponse = jsonDecode(response.body);
      throw Exception('Failed to create user: ${errorResponse['message']}');
    }
  }

  Future<ApiResponse> loginUser(String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(LoginRequest(email: email).toJson()),
    );

    if (response.statusCode == 200 || response.statusCode == 400) {
      return ApiResponse.fromJson(jsonDecode(response.body));
    } else {
      final errorResponse = jsonDecode(response.body);
      throw Exception('Failed to login user: ${errorResponse['message']}');
    }
  }

  Future<ApiResponse> createOrder(int userId, List<int> itemIds, String deliverAt) async {
    final response = await http.post(
      Uri.parse('$baseUrl/orders'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(NewOrder(userId: userId, itemIds: itemIds, deliverAt: deliverAt).toJson()),
    );

    if (response.statusCode == 200 || response.statusCode == 409) {
      return ApiResponse.fromJson(jsonDecode(response.body));
    } else {
      final errorResponse = jsonDecode(response.body);
      throw Exception('Failed to create order: ${errorResponse['message']}');
    }
  }

  Future<OrderResponse> getActiveOrders({int? userId, String? rfid}) async {
    final queryParameters = {
      if (userId != null) 'user_id': userId.toString(),
      if (rfid != null) 'rfid': rfid,
    };

    final uri = Uri.parse('$baseUrl/orders/by_user').replace(queryParameters: queryParameters);

    final response = await http.get(uri);

    if (response.statusCode == 200 || response.statusCode == 500) {
      return OrderResponse.fromJson(jsonDecode(response.body));
    } else {
      final errorResponse = jsonDecode(response.body);
      throw Exception('Failed to get active orders: ${errorResponse['message']}');
    }
  }

  Future<OrderData> getOrderById(int id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/orders/$id'),
    );

    if (response.statusCode == 200) {
      final orderResponse = OrderResponse.fromJson(jsonDecode(response.body));
      if (orderResponse.data != null && orderResponse.data!.isNotEmpty) {
        return orderResponse.data!.first;
      } else {
        throw Exception('No order data found for id: $id');
      }
    } else {
      final errorResponse = jsonDecode(response.body);
      throw Exception('Failed to get order by id: ${errorResponse['message']}');
    }
  }

  Future<List<Item>> getItemsByCanteenId(int canteenId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/canteen/$canteenId/items'),
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      if (responseData['data'] != null) {
        final List<dynamic> itemsJson = responseData['data'];
        return itemsJson.map((json) => Item.fromJson(json)).toList();
      }
      return [];
    } else {
      throw Exception('Failed to get items for canteen');
    }
  }

  Future<User> getUser(int userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/$userId'),
    );

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    } else {
      final errorResponse = jsonDecode(response.body);
      throw Exception('Failed to get user: ${errorResponse['message']}');
    }
  }

  Future<List<Canteen>> getActiveCanteens() async {
    final response = await http.get(
      Uri.parse('$baseUrl/canteen'),
    );

    if (response.statusCode == 200) {
      final List<dynamic> canteensJson = jsonDecode(response.body)['data'];
      return canteensJson.map((json) => Canteen.fromJson(json)).toList();
    } else {
      final errorResponse = jsonDecode(response.body);
      throw Exception('Failed to get active canteens: ${errorResponse['message']}');
    }
  }

  Future<List<Item>> searchItems(String query) async {
    final response = await http.get(
      Uri.parse('$baseUrl/search/$query'),
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      if (responseData['data'] != null) {
        final List<dynamic> itemsJson = responseData['data'];
        return itemsJson.map((json) => Item.fromJson(json)).toList();
      }
      return [];
    } else {
      throw Exception('Failed to search items');
    }
  }
}

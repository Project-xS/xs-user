import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:xs_user/auth_service.dart';
import 'package:xs_user/models.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  static String get baseUrl {
    const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
    if (apiBaseUrl.isNotEmpty) return apiBaseUrl;

    final envUrl = dotenv.env['API_BASE_URL'];
    if (envUrl != null && envUrl.isNotEmpty) return envUrl;

    return 'https://proj-xs.fly.dev';
  }
  static const _allowedDeliveryBands = {
    '11:00am - 12:00pm',
    '12:00pm - 01:00pm',
  };

  final http.Client _client;

  Future<StatusResponse> createUser(
    String rfid,
    String name,
    String email,
  ) async {
    final response = await _post(
      path: '/auth/create',
      body: NewUser(rfid: rfid, name: name, email: email).toJson(),
    );

    if (response.statusCode == 200 || response.statusCode == 409) {
      return StatusResponse.fromJson(_decodeJson(response.body));
    }

    throw ApiException(response.statusCode, _extractError(response));
  }

  Future<StatusResponse> loginUser(String email) async {
    final response = await _post(
      path: '/auth/login',
      body: LoginRequest(email: email).toJson(),
    );

    if (response.statusCode == 200 || response.statusCode == 400) {
      return StatusResponse.fromJson(_decodeJson(response.body));
    }

    throw ApiException(response.statusCode, _extractError(response));
  }

  Future<HoldResponse> createHold(List<int> itemIds, String? deliverAt) async {
    final normalizedDeliverAt = _allowedDeliveryBands.contains(deliverAt)
        ? deliverAt
        : null;

    final response = await _post(
      path: '/orders/hold',
      body: HoldRequest(
        itemIds: itemIds,
        deliverAt: normalizedDeliverAt,
      ).toJson(),
    );

    if (response.statusCode == 200 || response.statusCode == 409) {
      return HoldResponse.fromJson(_decodeJson(response.body));
    }

    throw ApiException(
      response.statusCode,
      'Failed to reserve items. Please try again.',
    );
  }

  Future<ConfirmResponse> confirmHold(int holdId) async {
    final response = await _postEmpty(path: '/orders/hold/$holdId/confirm');

    if (response.statusCode == 200 || response.statusCode == 409) {
      return ConfirmResponse.fromJson(_decodeJson(response.body));
    }

    throw ApiException(
      response.statusCode,
      'Failed to confirm order. Please try again.',
    );
  }

  Future<StatusResponse> cancelHold(int holdId) async {
    final response = await _delete(path: '/orders/hold/$holdId');

    if (response.statusCode == 200 || response.statusCode == 409) {
      return StatusResponse.fromJson(_decodeJson(response.body));
    }

    throw ApiException(
      response.statusCode,
      'Failed to cancel reservation. Please try again.',
    );
  }

  /// Fetches the QR code PNG for an order. Returns raw image bytes.
  Future<Uint8List> getOrderQrCode(int orderId) async {
    final response = await _get(path: '/orders/$orderId/qr');

    if (response.statusCode == 200) {
      return response.bodyBytes;
    }

    if (response.statusCode == 403) {
      throw ApiException(403, 'You don\'t have permission to view this order.');
    }
    if (response.statusCode == 404) {
      throw ApiException(404, 'Order not found or already completed.');
    }

    throw ApiException(
      response.statusCode,
      'Failed to generate QR code. Please try again.',
    );
  }

  Future<OrderResponse> getOrdersForCurrentUser() async {
    final response = await _get(path: '/orders/by_user');

    if (response.statusCode == 200 || response.statusCode == 500) {
      return OrderResponse.fromJson(_decodeJson(response.body));
    }

    throw ApiException(response.statusCode, _extractError(response));
  }

  Future<OrderResponse> getPastOrders() async {
    final response = await _get(path: '/users/get_past_orders');

    if (response.statusCode == 200 || response.statusCode == 500) {
      return OrderResponse.fromJson(_decodeJson(response.body));
    }

    throw ApiException(response.statusCode, _extractError(response));
  }

  Future<Order> getOrderById(int id) async {
    final response = await _get(path: '/orders/$id');

    if (response.statusCode == 200) {
      final orderResponse = OrderResponse.fromJson(_decodeJson(response.body));
      if (orderResponse.data.isNotEmpty) {
        return orderResponse.data.first;
      }
      throw ApiException(404, 'No order data found for id: $id');
    }

    throw ApiException(response.statusCode, _extractError(response));
  }

  Future<List<Item>> getItemsByCanteenId(int canteenId) async {
    final response = await _get(path: '/canteen/$canteenId/items');

    if (response.statusCode == 200) {
      final responseData = _decodeJson(response.body);
      final List<dynamic>? itemsJson = responseData['data'] as List<dynamic>?;
      if (itemsJson == null) return const [];
      return itemsJson.map((json) => Item.fromJson(json)).toList();
    }

    throw ApiException(response.statusCode, _extractError(response));
  }

  Future<List<Canteen>> getActiveCanteens() async {
    final response = await _get(path: '/canteen');

    if (response.statusCode == 200) {
      final data = _decodeJson(response.body)['data'] as List<dynamic>;
      return data.map((json) => Canteen.fromJson(json)).toList();
    }

    throw ApiException(response.statusCode, _extractError(response));
  }

  Future<List<Item>> searchItems(String query) async {
    final encodedQuery = Uri.encodeComponent(query);
    final response = await _get(path: '/search/$encodedQuery');

    if (response.statusCode == 200) {
      final responseData = _decodeJson(response.body);
      final List<dynamic>? itemsJson = responseData['data'] as List<dynamic>?;
      if (itemsJson == null) return const [];
      return itemsJson.map((json) => Item.fromJson(json)).toList();
    }

    throw ApiException(response.statusCode, _extractError(response));
  }

  Future<http.Response> _get({required String path}) {
    return _send(method: 'GET', path: path, includeJsonContentType: false);
  }

  Future<http.Response> _post({
    required String path,
    required Map<String, dynamic> body,
  }) {
    return _send(
      method: 'POST',
      path: path,
      jsonBody: body,
      includeJsonContentType: true,
    );
  }

  Future<http.Response> _postEmpty({required String path}) {
    return _send(method: 'POST', path: path, includeJsonContentType: false);
  }

  Future<http.Response> _delete({required String path}) {
    return _send(method: 'DELETE', path: path, includeJsonContentType: false);
  }

  Future<http.Response> _send({
    required String method,
    required String path,
    Map<String, dynamic>? jsonBody,
    bool includeJsonContentType = true,
  }) async {
    final normalizedPath = _normalizePath(path);
    final uri = _buildUri(normalizedPath);

    debugPrint('ApiService._send: $method $uri');

    http.Response response;
    Map<String, String> headers = await _buildHeaders(
      normalizedPath,
      includeJsonContentType,
    );

    try {
      response = await _dispatch(method, uri, headers, jsonBody);
      debugPrint(
        'ApiService._send: Response status ${response.statusCode} for $method $uri',
      );
    } catch (e) {
      debugPrint('ApiService._send: Request error for $method $uri: $e');
      rethrow;
    }

    if (response.statusCode == 401 && _shouldAttachToken(normalizedPath)) {
      debugPrint('ApiService._send: Got 401, retrying with refreshed token');
      headers = await _buildHeaders(
        normalizedPath,
        includeJsonContentType,
        forceRefresh: true,
      );
      response = await _dispatch(method, uri, headers, jsonBody);
      debugPrint(
        'ApiService._send: Retry response status ${response.statusCode} for $method $uri',
      );
    }

    if (response.statusCode == 401) {
      final errorMsg = _extractError(response);
      debugPrint('ApiService._send: Still 401 after retry, error: $errorMsg');
      throw AuthException(
        'sign-in-required',
        'Sign-in required or token expired: $errorMsg',
      );
    }

    if (response.statusCode == 403) {
      debugPrint('ApiService._send: Got 403, throwing forbidden error');
      throw AuthException('forbidden', 'Permission denied.');
    }

    return response;
  }

  Future<Map<String, String>> _buildHeaders(
    String path,
    bool includeJsonHeader, {
    bool forceRefresh = false,
  }) async {
    final headers = <String, String>{};
    if (includeJsonHeader) {
      headers['Content-Type'] = 'application/json';
    }

    if (!_shouldAttachToken(path)) {
      debugPrint('ApiService._buildHeaders: Skipping token for path $path');
      return headers;
    }

    debugPrint(
      'ApiService._buildHeaders: Getting token for $path (forceRefresh=$forceRefresh)',
    );
    final token = await AuthService.getValidIdToken(forceRefresh: forceRefresh);
    if (token == null) {
      debugPrint('ApiService._buildHeaders: Token is null for path $path');
      throw AuthException(
        'sign-in-required',
        'Sign-in required or token expired.',
      );
    }

    debugPrint(
      'ApiService._buildHeaders: Token attached (len=${token.length})',
    );

    headers['Authorization'] = 'Bearer $token';
    debugPrint('ApiService._buildHeaders: Authorization header set');
    return headers;
  }

  bool _shouldAttachToken(String path) {
    final normalized = _normalizePath(path);
    return normalized != '/' && normalized != '/health';
  }

  Uri _buildUri(String path) {
    return Uri.parse('$baseUrl$path');
  }

  String _normalizePath(String path) {
    if (path.isEmpty) return '/';
    return path.startsWith('/') ? path : '/$path';
  }

  Future<http.Response> _dispatch(
    String method,
    Uri uri,
    Map<String, String> headers,
    Map<String, dynamic>? jsonBody,
  ) {
    switch (method.toUpperCase()) {
      case 'GET':
        return _client.get(uri, headers: headers);
      case 'POST':
        final body = jsonBody != null ? jsonEncode(jsonBody) : null;
        return _client.post(uri, headers: headers, body: body);
      case 'DELETE':
        return _client.delete(uri, headers: headers);
      default:
        throw UnimplementedError('HTTP method $method is not implemented.');
    }
  }

  Map<String, dynamic> _decodeJson(String source) {
    if (source.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(source);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw const FormatException('Unexpected JSON structure.');
  }

  String _extractError(http.Response response) {
    try {
      final json = _decodeJson(response.body);
      final dynamic message = json['error'] ?? json['message'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
    } catch (_) {
      // ignore parse errors
    }
    return 'Request failed with status code ${response.statusCode}.';
  }
}

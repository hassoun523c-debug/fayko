import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

const faykoApiBaseUrl = String.fromEnvironment(
  'FAYKO_API_BASE_URL',
  defaultValue: 'http://10.0.2.2:4000/api/v1',
);

class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  final int statusCode;
  final String code;
  final String message;

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}

class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = (baseUrl ?? faykoApiBaseUrl).replaceFirst(
          RegExp(r'/+$'),
          '',
        );

  final http.Client _client;
  final String _baseUrl;
  static const _timeout = Duration(seconds: 20);

  Future<Map<String, dynamic>> get(
    String path, {
    String? token,
    Map<String, String>? queryParameters,
  }) {
    return _send(
      'GET',
      path,
      token: token,
      queryParameters: queryParameters,
    );
  }

  Future<Map<String, dynamic>> post(
    String path, {
    String? token,
    Map<String, Object?>? body,
  }) {
    return _send('POST', path, token: token, body: body);
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    required String token,
    required Map<String, Object?> body,
  }) {
    return _send('PATCH', path, token: token, body: body);
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    required String token,
  }) {
    return _send('DELETE', path, token: token);
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    String? token,
    Map<String, Object?>? body,
    Map<String, String>? queryParameters,
  }) async {
    final uri = Uri.parse('$_baseUrl$path').replace(
      queryParameters: queryParameters,
    );
    final headers = <String, String>{'accept': 'application/json'};

    if (body != null) {
      headers['content-type'] = 'application/json; charset=utf-8';
    }
    if (token != null && token.isNotEmpty) {
      headers['authorization'] = 'Bearer $token';
    }

    final request = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);

    late http.Response response;
    try {
      final streamed = await _client.send(request).timeout(_timeout);
      response = await http.Response.fromStream(streamed).timeout(_timeout);
    } on TimeoutException {
      throw const ApiException(
        statusCode: 0,
        code: 'network_timeout',
        message: 'انتهت مهلة الاتصال بالخادم. حاول مجدداً.',
      );
    } on http.ClientException {
      throw const ApiException(
        statusCode: 0,
        code: 'network_unavailable',
        message: 'تعذر الاتصال بخادم فايكو. تحقق من الاتصال وعنوان الخادم.',
      );
    }

    Map<String, dynamic> payload;
    if (response.bodyBytes.isEmpty) {
      payload = <String, dynamic>{};
    } else {
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Expected a JSON object.');
        }
        payload = decoded;
      } on FormatException {
        throw ApiException(
          statusCode: response.statusCode,
          code: 'invalid_server_response',
          message: 'استلم التطبيق استجابة غير مفهومة من الخادم.',
        );
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = payload['error'];
      final message = error is Map<String, dynamic> &&
              error['message'] is String
          ? error['message'] as String
          : 'تعذر إكمال الطلب. حاول مجدداً.';
      final code = error is Map<String, dynamic> &&
              error['code'] is String
          ? error['code'] as String
          : 'request_failed';
      throw ApiException(
        statusCode: response.statusCode,
        code: code,
        message: message,
      );
    }

    return payload;
  }

  void close() => _client.close();
}

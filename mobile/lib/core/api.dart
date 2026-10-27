import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'config.dart';

const _tokenKey = 'token';
const _storage = FlutterSecureStorage();

Future<String?> readToken() async {
  try {
    return await _storage.read(key: _tokenKey);
  } catch (_) {
    return null;
  }
}

Future<void> saveToken(String? token) async {
  try {
    if (token == null) {
      await _storage.delete(key: _tokenKey);
    } else {
      await _storage.write(key: _tokenKey, value: token);
    }
  } catch (_) {}
}

/// Pesan error yang aman ditampilkan ke pengguna.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class Api {
  Api({required this.onUnauthorized})
      : dio = Dio(BaseOptions(
          baseUrl: apiUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
        )) {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await readToken();
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (e, handler) {
        if (e.response?.statusCode == 401 && e.requestOptions.extra['auth'] == true) {
          onUnauthorized();
        }
        handler.next(e);
      },
    ));
  }

  final Dio dio;
  final void Function() onUnauthorized;

  Future<T> _run<T>(Future<Response<dynamic>> Function() call, T Function(dynamic) parse) async {
    try {
      final res = await call();
      return parse(res.data);
    } on DioException catch (e) {
      final data = e.response?.data;
      var message = 'Tidak dapat terhubung ke server';
      if (data is Map && data['message'] != null) {
        final m = data['message'];
        message = m is List ? m.join('\n') : m.toString();
      } else if (e.response != null) {
        message = 'Terjadi kesalahan (${e.response!.statusCode})';
      }
      throw ApiException(message, statusCode: e.response?.statusCode);
    }
  }

  Options get _authed => Options(extra: {'auth': true});

  Future<T> get<T>(String path, T Function(dynamic) parse, {Map<String, dynamic>? query, bool auth = false}) =>
      _run(() => dio.get(path, queryParameters: query, options: auth ? _authed : null), parse);

  Future<T> post<T>(String path, Object? body, T Function(dynamic) parse, {bool auth = false}) =>
      _run(() => dio.post(path, data: body, options: auth ? _authed : null), parse);

  Future<T> patch<T>(String path, Object? body, T Function(dynamic) parse, {bool auth = false}) =>
      _run(() => dio.patch(path, data: body, options: auth ? _authed : null), parse);

  Future<void> delete(String path) => _run(() => dio.delete(path, options: _authed), (_) {});
}

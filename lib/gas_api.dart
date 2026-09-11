import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

class GasApiException implements Exception {
  GasApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Googleの秘密鍵は保持しない。GASはデプロイしたアカウントでSheetsにアクセスする。
class GasApi {
  GasApi({http.Client? client, String? url, String? apiKey})
      : _client = client ?? http.Client(),
        _url = url ?? const String.fromEnvironment('UPAY_GAS_URL'),
        _apiKey =
            apiKey ?? const String.fromEnvironment('UPAY_REGISTER_API_KEY');

  static final instance = GasApi();
  final http.Client _client;
  final String _url;
  final String _apiKey;
  final Map<String, String> _pending = {};

  static String requestId() {
    final random = Random.secure();
    return List.generate(
            16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
        .join();
  }

  Uri get _endpoint {
    final uri = Uri.tryParse(_url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'script.google.com' ||
        !uri.path.endsWith('/exec')) {
      throw GasApiException('UPAY_GAS_URLにGASのWebアプリURL（/exec）を設定してください。');
    }
    return uri;
  }

  Future<Map<String, dynamic>> _request(Map<String, dynamic>? body) async {
    final endpoint = _endpoint;
    if (body != null && _apiKey.length < 32) {
      throw GasApiException('UPAY_REGISTER_API_KEYを設定してください。');
    }
    try {
      final request = http.Request(body == null ? 'GET' : 'POST', endpoint);
      if (body != null) {
        request.headers['Content-Type'] = 'text/plain; charset=utf-8';
        request.body = jsonEncode({...body, 'apiKey': _apiKey});
      }
      // GAS ContentServiceの302応答はGETで取得する（POST本文を再送しない）。
      request.followRedirects = false;
      var response =
          await http.Response.fromStream(await _client.send(request));
      for (var hop = 0;
          hop < 5 && [301, 302, 303].contains(response.statusCode);
          hop++) {
        final location = response.headers['location'];
        final target = location == null ? null : endpoint.resolve(location);
        if (target == null ||
            target.scheme != 'https' ||
            target.host != 'script.googleusercontent.com') {
          throw GasApiException('GASの公開設定を確認してください。ログインなしでAPIにアクセスできる設定が必要です。');
        }
        final redirect = http.Request('GET', target)..followRedirects = false;
        response = await http.Response.fromStream(await _client.send(redirect));
      }
      if (response.statusCode != 200) {
        throw GasApiException('GASとの通信に失敗しました。同じ操作を再試行してください。');
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      if (decoded['success'] != true) {
        throw GasApiException(decoded['error']?.toString() ?? '処理に失敗しました。');
      }
      return decoded;
    } on FormatException {
      throw GasApiException('GASからJSONが返りませんでした。デプロイURLと公開設定を確認してください。');
    } on http.ClientException {
      throw GasApiException('通信が途切れました。取引は完了している可能性があります。同じ画面で再試行してください。');
    }
  }

  Future<Map<String, dynamic>> call(Map<String, dynamic>? body) =>
      _request(body).timeout(const Duration(seconds: 60), onTimeout: () {
        throw GasApiException('応答がありません。取引は完了している可能性があります。同じ画面で再試行してください。');
      });

  Future<List<Map<String, dynamic>>> items() async {
    final result = await call(null);
    return (result['items'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Map<String, dynamic>> verifyQr(String token) =>
      call({'action': 'verifyQrToken', 'token': token});

  Future<Map<String, dynamic>> transact(
      String action, String sessionToken, Map<String, dynamic> payload) async {
    if (sessionToken.isEmpty) throw GasApiException('WebポータルのQRを読み取り直してください。');
    final operation = jsonEncode([action, sessionToken, payload]);
    final id = _pending.putIfAbsent(operation, requestId);
    final result = await call({
      'action': action,
      'sessionToken': sessionToken,
      'requestId': id,
      ...payload
    });
    _pending.remove(operation);
    return Map<String, dynamic>.from(result['user'] as Map);
  }
}

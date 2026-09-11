import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:upay_ver01/gas_api.dart';
import 'package:upay_ver01/main.dart';

const url = 'https://script.google.com/macros/s/test/exec';
final key = 'k' * 32;
final session = 'a' * 32;
final user = {
  'UserID': '26012',
  'UserName': 'Test',
  'Balance': 700,
  'PurchaseNum': 2,
  'TotalAmount': 300,
  'GiftAmount': 0
};

void main() {
  test('GAS POST redirect is followed as GET without sending API key again',
      () async {
    final requests = <http.Request>[];
    final api = GasApi(
        url: url,
        apiKey: key,
        client: MockClient((request) async {
          requests.add(request);
          if (requests.length == 1) {
            expect(jsonDecode(request.body)['apiKey'], key);
            return http.Response('', 302, headers: {
              'location':
                  'https://script.googleusercontent.com/macros/echo?test=1'
            });
          }
          expect(request.method, 'GET');
          expect(request.body, isEmpty);
          return http.Response(
              jsonEncode(
                  {'success': true, 'user': user, 'sessionToken': session}),
              200);
        }));
    final result = await api.verifyQr('b' * 32);
    expect(result['sessionToken'], session);
    expect(requests, hasLength(2));
  });

  test(
      'retry after network error preserves request ID and sends no client balance',
      () async {
    final requests = <Map<String, dynamic>>[];
    final api = GasApi(
        url: url,
        apiKey: key,
        client: MockClient((request) async {
          requests.add(jsonDecode(request.body) as Map<String, dynamic>);
          if (requests.length == 1) throw http.ClientException('offline');
          return http.Response(
              jsonEncode({'success': true, 'user': user}), 200);
        }));
    final payload = {
      'items': [
        {'itemId': 3, 'quantity': 2}
      ]
    };
    await expectLater(api.transact('purchase', session, payload),
        throwsA(isA<GasApiException>()));
    expect(await api.transact('purchase', session, payload), user);
    expect(requests[0]['requestId'], requests[1]['requestId']);
    expect(requests[0].containsKey('balance'), false);
    expect(requests[0].containsKey('userId'), false);
  });

  test('server error is surfaced even on HTTP 200 and retry keeps ID',
      () async {
    final ids = <String>[];
    final api = GasApi(
        url: url,
        apiKey: key,
        client: MockClient((request) async {
          ids.add(jsonDecode(request.body)['requestId'] as String);
          return http.Response(
              jsonEncode({'success': false, 'error': '残高不足'}), 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }));
    for (var i = 0; i < 2; i++) {
      await expectLater(
          api.transact('purchase', session, {'items': []}),
          throwsA(isA<GasApiException>()
              .having((e) => e.message, 'message', '残高不足')));
    }
    expect(ids[0], ids[1]);
  });

  test('missing settings, HTML and login redirects produce actionable errors',
      () async {
    final missing = GasApi(url: '', apiKey: '');
    await expectLater(missing.items(), throwsA(isA<GasApiException>()));
    for (final response in [
      http.Response('<html>login</html>', 200),
      http.Response('', 302,
          headers: {'location': 'https://accounts.google.com/login'})
    ]) {
      final api = GasApi(
          url: url, apiKey: key, client: MockClient((_) async => response));
      await expectLater(api.items(), throwsA(isA<GasApiException>()));
    }
  });

  test('user model accepts numeric API values and preserves session on copy',
      () {
    final model = UserData.fromApi(user, session);
    final copy = model.copyWith();
    expect(copy.sessionToken, session);
    copy.applyApi({...user, 'Balance': 1200, 'GiftAmount': 200});
    expect(copy.balance, 1200);
    expect(copy.giftAmount, 200);
    expect(model.balance, 700);
  });
}

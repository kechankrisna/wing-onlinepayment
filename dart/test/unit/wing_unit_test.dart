// Offline tests: no network, no Wing credentials. Expected payloads,
// hashes and callbacks in ../spec/test-vectors/php_known_answers.json were
// computed with PHP's openssl_encrypt as in Wing's spec
// (../spec/test-vectors/php_known_answers.php), shared by every SDK.
import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:dart_wing/dart_wing.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

final Map<String, dynamic> kat =
    json.decode(
          io.File(
            '../spec/test-vectors/php_known_answers.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;

/// answers every request with [handler] and records what was sent
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;
  final requests = <RequestOptions>[];
  final bodies = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bytes = requestStream == null
        ? <int>[]
        : await requestStream.expand((chunk) => chunk).toList();
    requests.add(options);
    bodies.add(utf8.decode(bytes, allowMalformed: true));
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(Object body, int statusCode) =>
    ResponseBody.fromString(json.encode(body), statusCode);

void main() {
  const merchant = WingMerchant(
    username: 'online.testing',
    restApiKey: 'test-rest-api-key',
    password: 'test-password-0123456789abcdefgh',
    billTillNumber: '2000',
    referer: 'https://shop.test',
    baseApiUrl: 'https://wing.test/wingonlinesdkv2/',
  );
  const randStr = 'cbae7968ed6d0eff';
  const timestamp = '1624684179';
  DateTime fixedClock() =>
      DateTime.fromMillisecondsSinceEpoch(1624684179 * 1000, isUtc: true);
  String fixedRandom() => randStr;

  WingRequestBuilder builderFor(WingMerchant m) =>
      WingRequestBuilder(merchant: m, clock: fixedClock, random: fixedRandom);
  final builder = builderFor(merchant);

  const minimal = WingPayment(
    orderReferenceNo: 'c19245baae',
    amount: 15,
    returnUrl: 'https://shop.test/wing/return?order=c19245baae',
    cancelUrl: 'https://shop.test/wing/cancel?order=c19245baae',
  );
  const full = WingPayment(
    orderReferenceNo: 'c19245baae',
    amount: 15,
    returnUrl: 'https://shop.test/wing/return?order=c19245baae',
    cancelUrl: 'https://shop.test/wing/cancel?order=c19245baae',
    integrationType: WingIntegrationType.mobileApp,
    isWingAppInstalled: true,
    itemName: 'កាហ្វេ / coffee',
    merchantName: 'Testing Shop',
    wingAccount: '00001614',
  );

  WingService serviceWith(FakeAdapter adapter, {WingLogger? logger}) =>
      WingService(
        merchant: merchant,
        dio: Dio()..httpClientAdapter = adapter,
        clock: fixedClock,
        random: fixedRandom,
        logger: logger,
      );

  group('payloads and hashes match the PHP known answers', () {
    test('payload with the required fields only', () {
      expect(
        builder.payloadJson(minimal, randStr: randStr, timestamp: timestamp),
        kat['payload_minimal_json'],
      );
      expect(builder.authorization(minimal), {
        'username': 'online.testing',
        'rest_api_key': 'test-rest-api-key',
        'payload': kat['payload_minimal'],
        'hash': kat['hash'],
        'sandbox': '1',
      });
    });

    test('payload with every field', () {
      expect(
        builder.payloadJson(full, randStr: randStr, timestamp: timestamp),
        kat['payload_full_json'],
      );
      expect(builder.authorization(full)['payload'], kat['payload_full']);
    });

    test('explicit rand_str and timestamp give the same body', () {
      final explicit = WingRequestBuilder(
        merchant: merchant,
      ).authorization(minimal, randStr: randStr, timestamp: timestamp);
      expect(explicit['payload'], kat['payload_minimal']);
      expect(explicit['hash'], kat['hash']);
    });

    test('hash of a KHR amount', () {
      expect(
        builder.hash(
          amount: '12000.00',
          orderReferenceNo: 'c19245baae',
          randStr: randStr,
          timestamp: timestamp,
        ),
        kat['hash_khr'],
      );
    });

    test('a short password is NUL-padded like openssl_encrypt', () {
      final short = builderFor(
        merchant.copyWith(password: kat['short_password'] as String),
      ).authorization(minimal);
      expect(short['payload'], kat['payload_minimal_short_password']);
      expect(short['hash'], kat['hash_short_password']);
    });

    test('a long password is truncated like openssl_encrypt', () {
      final long = builderFor(
        merchant.copyWith(password: kat['long_password'] as String),
      ).authorization(minimal);
      expect(long['payload'], kat['payload_minimal_long_password']);
    });

    test('production sends sandbox 0', () {
      expect(
        builderFor(
          merchant.copyWith(sandbox: false),
        ).authorization(minimal)['sandbox'],
        '0',
      );
      expect(builder.inquiry('x'), {
        'username': 'online.testing',
        'rest_api_key': 'test-rest-api-key',
        'order_reference_no': 'x',
        'sandbox': '1',
      });
    });
  });

  group('inputs', () {
    test('amounts have 2 decimals', () {
      expect(WingRequestBuilder.formatAmount(15), '15.00');
      expect(WingRequestBuilder.formatAmount(2.5), '2.50');
      expect(WingRequestBuilder.formatAmount(0.07), '0.07');
      expect(WingRequestBuilder.formatAmount(12000), '12000.00');
      expect(WingRequestBuilder.formatAmount(1234567.89), '1234567.89');
    });

    test('amounts Wing would round, or not positive, are rejected', () {
      for (final amount in [1.005, 0.1 + 0.2, 0, -1, double.nan, 1e13]) {
        expect(
          () => WingRequestBuilder.formatAmount(amount),
          throwsArgumentError,
          reason: '$amount',
        );
      }
    });

    test('rand_str is 16 random hex characters', () {
      final values = {
        for (var i = 0; i < 20; i++) WingRequestBuilder.randomString(),
      };
      expect(values.length, 20);
      for (final value in values) {
        expect(value, matches(RegExp(r'^[0-9a-f]{16}$')));
      }
      expect(
        () => builder.authorization(minimal, randStr: 'XYZ'),
        throwsArgumentError,
      );
      expect(
        () => builder.authorization(minimal, timestamp: '2026-01-02'),
        throwsArgumentError,
      );
    });

    test('timestamp is Unix seconds from the clock', () {
      final payload = const WingCrypto().aes256CbcDecrypt(
        builder.authorization(minimal)['payload']!,
        merchant.password,
        WingCrypto.passwordIv(merchant.password),
      );
      expect(payload, contains('"timestamp":"1624684179"'));
    });
  });

  group('callbacks', () {
    final service = WingService(merchant: merchant);

    test('the contents decrypt to the documented callback', () {
      expect(
        service.decryptCallback(kat['callback_contents'] as String),
        kat['callback_json'],
      );
    });

    test('JSON, form and bare contents bodies parse', () {
      final contents = kat['callback_contents'] as String;
      for (final body in [
        json.encode({'contents': contents}),
        'contents=${Uri.encodeQueryComponent(contents)}',
        contents,
      ]) {
        final callback = service.parseCallback(body);
        expect(callback.transactionId, '0002355252200023');
        expect(callback.orderReferenceNo, '1234321');
        expect(callback.amount, 1.5);
        expect(callback.totalAmount, 1.5);
        expect(callback.currency, 'USD');
        expect(callback.transactionDate, '28-08-23 09:34:38');
        expect(callback.raw['ps_trn_id'], ' ONL015627');
        expect(callback.covers(1.5), true);
        expect(callback.covers(1.51), false);
      }
    });

    test('contents from another password are rejected', () {
      final other = WingService(
        merchant: merchant.copyWith(password: 'another-password-0123456789'),
      );
      for (final contents in [
        kat['callback_contents'] as String,
        'not base64!',
        base64.encode(utf8.encode('short')),
      ]) {
        expect(
          () => other.parseCallback(contents),
          throwsA(
            isA<WingException>().having(
              (e) => e.type,
              'type',
              WingErrorType.invalidCallback,
            ),
          ),
        );
      }
    });

    test('decrypted contents that are not a JSON object are rejected', () {
      final contents = const WingCrypto().aes256CbcEncrypt(
        '[1]',
        merchant.password,
        WingCrypto.passwordIv(merchant.password),
      );
      expect(
        () => service.parseCallback(contents),
        throwsA(isA<WingException>()),
      );
    });
  });

  group('WingService with an injected Dio', () {
    test('authorize posts JSON with a Base64 Referer', () async {
      final adapter = FakeAdapter(
        (_) async => jsonResponse({
          'errorCode': '200',
          'errorText': 'Success authorization',
          'token': 'eyJhbGciOiJIUzI1NiJ9.e30.sig',
        }, 200),
      );

      final response = await serviceWith(adapter).authorize(minimal);

      expect(response.isSuccess, true);
      expect(response.token, 'eyJhbGciOiJIUzI1NiJ9.e30.sig');
      expect(
        response.confirmUrl.toString(),
        'https://wing.test/wingonlinesdkv2/v1/online/payment/confirm?token='
        '${Uri.encodeQueryComponent(base64.encode(utf8.encode(response.token!)))}',
      );
      final request = adapter.requests.single;
      expect(
        request.uri.toString(),
        'https://wing.test/wingonlinesdkv2${WingService.authorizationPath}',
      );
      expect(request.headers[Headers.contentTypeHeader], 'application/json');
      expect(
        request.headers['Referer'],
        base64.encode(utf8.encode('https://shop.test')),
      );
      expect(
        request.headers['User-Agent'],
        'dart-wing/${WingService.sdkVersion}',
      );
      expect(
        json.decode(adapter.bodies.single),
        builder.authorization(minimal),
      );
    });

    test('confirmUrl percent-encodes the Base64 token', () {
      final service = WingService(merchant: merchant);
      // base64 of these bytes holds '+', '/' and '='
      final url = service.confirmUrl(String.fromCharCodes([0xfb, 0xff]));
      expect(url.query, startsWith('token='));
      expect(url.query, isNot(contains('+')));
      expect(
        url.queryParameters['token'],
        base64.encode(utf8.encode(String.fromCharCodes([0xfb, 0xff]))),
      );
    });

    test('a Wing error is returned, not thrown', () async {
      final adapter = FakeAdapter(
        (_) async => jsonResponse({
          'errorCode': '401',
          'errorText': 'Invalid rest api key.',
          'token': null,
        }, 401),
      );
      final response = await serviceWith(adapter).authorize(minimal);
      expect(response.isSuccess, false);
      expect(response.status.code, '401');
      expect(response.confirmUrl, isNull);
    });

    test('a password shorter than 16 bytes is an encryption error', () {
      final service = WingService(
        merchant: merchant.copyWith(password: 'too-short'),
      );
      expect(
        () => service.authorize(minimal),
        throwsA(
          isA<WingException>().having(
            (e) => e.type,
            'type',
            WingErrorType.encryption,
          ),
        ),
      );
    });

    test('inquiry reads a transaction at the top level', () async {
      final adapter = FakeAdapter(
        (_) async => jsonResponse({
          'errorCode': '200',
          'respType': 'respType',
          'amount': '15.00',
          'total_amount': 15.0,
          'currency': 'USD',
          'order_reference_no': 'c19245baae',
          'transaction_id': '0002355252200023',
        }, 200),
      );

      final response = await serviceWith(
        adapter,
      ).inquiry(orderReferenceNo: 'c19245baae');

      expect(response.isSuccess, true);
      expect(response.transaction!.amount, 15);
      expect(response.transaction!.raw['respType'], 'respType');
      expect(response.isPaid(15), true);
      expect(response.isPaid(15.01), false);
      final request = adapter.requests.single;
      expect(request.uri.path, '/wingonlinesdkv2${WingService.inquiryPath}');
      expect(json.decode(adapter.bodies.single), builder.inquiry('c19245baae'));
    });

    test('inquiry reads a transaction inside data', () async {
      final adapter = FakeAdapter(
        (_) async => jsonResponse({
          'errorCode': '200',
          'data': {'amount': 2.5, 'transaction_id': 'T1'},
        }, 200),
      );
      final response = await serviceWith(
        adapter,
      ).inquiry(orderReferenceNo: 'x');
      expect(response.transaction!.transactionId, 'T1');
      expect(response.isPaid(2.5), true);
    });

    test('transaction not found is returned, not thrown', () async {
      final adapter = FakeAdapter(
        (_) async => jsonResponse({
          'errorCode': '006035',
          'errorText': 'Transaction not found...!',
        }, 200),
      );
      final response = await serviceWith(
        adapter,
      ).inquiry(orderReferenceNo: 'x');
      expect(response.isSuccess, false);
      expect(response.status.code, '006035');
      expect(response.transaction, isNull);
      expect(response.isPaid(1), false);
    });

    test('network failures throw retryable connection errors', () async {
      final adapter = FakeAdapter(
        (options) async => throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ),
      );
      expect(
        serviceWith(adapter).inquiry(orderReferenceNo: 'x'),
        throwsA(
          isA<WingException>()
              .having((e) => e.type, 'type', WingErrorType.connection)
              .having((e) => e.isRetryable, 'isRetryable', true),
        ),
      );
    });

    test('an HTML page instead of JSON is an unexpected response', () async {
      final adapter = FakeAdapter(
        (_) async => ResponseBody.fromString('<html>', 502),
      );
      expect(
        serviceWith(adapter).inquiry(orderReferenceNo: 'x'),
        throwsA(
          isA<WingException>()
              .having((e) => e.type, 'type', WingErrorType.unexpectedResponse)
              .having((e) => e.statusCode, 'statusCode', 502),
        ),
      );
    });

    test('a cancelled call is typed', () async {
      final adapter = FakeAdapter(
        (options) async => throw DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
        ),
      );
      expect(
        serviceWith(
          adapter,
        ).inquiry(orderReferenceNo: 'x', cancelToken: CancelToken()),
        throwsA(
          isA<WingException>().having(
            (e) => e.type,
            'type',
            WingErrorType.cancelled,
          ),
        ),
      );
    });

    test('logs go to the injected logger, without the REST API key', () async {
      final lines = <String>[];
      final adapter = FakeAdapter(
        (_) async =>
            jsonResponse({'errorCode': '006035', 'errorText': 'x'}, 200),
      );
      await serviceWith(
        adapter,
        logger: lines.add,
      ).inquiry(orderReferenceNo: 'x');
      expect(lines, hasLength(2));
      expect(lines.first, contains('POST https://wing.test'));
      expect(lines.join(), isNot(contains('test-rest-api-key')));
    });
  });

  group('models', () {
    test('merchant JSON round-trips and toString hides the secrets', () {
      expect(WingMerchant.fromJson(merchant.toJson()), merchant);
      expect(merchant.toString(), isNot(contains('test-rest-api-key')));
      expect(merchant.toString(), isNot(contains('test-password')));
    });

    test('numbers sent as strings still parse', () {
      final transaction = WingTransaction.fromJson({
        'amount': '10.5',
        'fee': 0,
        'transaction_id': 123,
      });
      expect(transaction.amount, 10.5);
      expect(transaction.fee, 0);
      expect(transaction.transactionId, '123');
      expect(transaction.orderReferenceNo, '');
    });
  });

  test('sdkVersion matches pubspec.yaml', () {
    final pubspec = io.File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version: (\S+)',
      multiLine: true,
    ).firstMatch(pubspec)!;
    expect(WingService.sdkVersion, version.group(1));
  });
}

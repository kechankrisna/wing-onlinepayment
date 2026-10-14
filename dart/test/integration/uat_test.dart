// Integration tests against Wing's online payment API. They read partner
// credentials from an env file and are skipped without one:
//
//   dart test -t integration                                 # uses .env
//   WING_ENV_FILE=.env.production dart test -t integration   # another file
//
// They authorize a real payment (0.10 USD, never paid), so a file with
// WING_SANDBOX="0" is refused unless you also set WING_ALLOW_PRODUCTION=true.
//
// Run only the offline tests with: dart test -x integration
@Tags(['integration'])
library;

import 'dart:io' as io;

import 'package:dart_wing/dart_wing.dart';
import 'package:dotenv/dotenv.dart';
import 'package:test/test.dart';

void main() {
  final envFile = io.Platform.environment['WING_ENV_FILE'] ?? '.env';
  final env = DotEnv();
  if (io.File(envFile).existsSync()) env.load([envFile]);
  final baseUrl = env['WING_API_URL'] ?? WingMerchant.uatBaseUrl;
  final isProduction = env['WING_SANDBOX'] == '0';
  final allowProduction =
      io.Platform.environment['WING_ALLOW_PRODUCTION'] == 'true';

  final Object skip = !io.File(envFile).existsSync()
      ? 'no $envFile with Wing credentials'
      : isProduction && !allowProduction
      ? '$envFile sets WING_SANDBOX="0"; set WING_ALLOW_PRODUCTION=true '
            'to run tests that authorize real payments'
      : false;

  group(
    'Wing online payment (${Uri.parse(baseUrl).host}, $envFile)',
    skip: skip,
    () {
      late WingService wing;
      final orderReferenceNo = 'sdk${DateTime.now().millisecondsSinceEpoch}';
      final referer = env['WING_REFERER_DOMAIN'] ?? 'https://example.com';

      setUpAll(() {
        io.HttpOverrides.global = null;
        wing = WingService(
          merchant: WingMerchant(
            username: env['WING_USERNAME'] ?? '',
            restApiKey: env['WING_REST_API_KEY'] ?? '',
            password: env['WING_PASSWORD'] ?? '',
            billTillNumber: env['WING_BILL_TILL_NUMBER'] ?? '',
            referer: referer,
            baseApiUrl: baseUrl,
            sandbox: !isProduction,
          ),
          logger: print,
        );
      });

      test('authorize returns a token and the payment page', () async {
        final response = await wing.authorize(
          WingPayment(
            orderReferenceNo: orderReferenceNo,
            amount: 0.1,
            returnUrl: '$referer/wing/return',
            cancelUrl: '$referer/wing/cancel',
            itemName: 'dart_wing integration test',
          ),
        );
        expect(response.isSuccess, true, reason: '${response.status}');
        expect(response.confirmUrl!.path, endsWith(WingService.confirmPath));
      });

      test('inquiry of an unpaid order is reported, not thrown', () async {
        final response = await wing.inquiry(orderReferenceNo: orderReferenceNo);
        expect(response.isPaid(0.1), false, reason: '${response.status}');
      });
    },
  );
}

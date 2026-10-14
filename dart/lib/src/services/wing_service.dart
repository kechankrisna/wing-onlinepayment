import 'dart:convert';

import 'package:dio/dio.dart';

import '../exceptions.dart';
import '../models/requests/wing_payment.dart';
import '../models/responses/wing_responses.dart';
import '../models/responses/wing_status.dart';
import '../models/responses/wing_transaction.dart';
import '../models/wing_merchant.dart';
import '../version.dart';
import 'wing_crypto.dart';
import 'wing_request_builder.dart';

/// receives request/response log lines
typedef WingLogger = void Function(String message);

/// browsers do not allow setting `Referer` or `User-Agent`
const bool _kIsWeb =
    bool.fromEnvironment('dart.library.js_util') ||
    bool.fromEnvironment('dart.library.js_interop');

/// Wing Bank online payment (Web SDK v2) client.
///
/// ```dart
/// final wing = WingService(merchant: merchant);
/// final auth = await wing.authorize(payment);
/// if (auth.isSuccess) redirectTo(auth.confirmUrl!);
/// // later, after Wing redirects to your return_url:
/// final inquiry = await wing.inquiry(orderReferenceNo: 'order-1001');
/// if (inquiry.isPaid(15)) deliverOrder();
/// ```
///
/// Wing business errors (invalid REST API key, transaction not found, ...)
/// are returned in `status`. A [WingException] is thrown only when Wing
/// could not be reached or did not answer with an `errorCode`.
///
/// Run it on your server: the REST API key and the password are secrets.
class WingService {
  /// version of this SDK, sent as `User-Agent: dart-wing/<version>`
  static const String sdkVersion = packageVersion;

  /// endpoint of [authorize]
  static const String authorizationPath = '/v1/online/payment/authorization';

  /// Wing's payment page, opened by [confirmUrl]
  static const String confirmPath = '/v1/online/payment/confirm';

  /// endpoint of [inquiry]. Section 4.1 of the spec (v2.0.3) gives `v2`;
  /// its endpoint list in section 2 still shows `v1`.
  static const String inquiryPath = '/v2/online/payment/transaction/inquiry';

  /// partner credentials used to encrypt and sign
  final WingMerchant merchant;

  /// encryption and hashing
  final WingCrypto crypto;

  /// builds the request bodies; exposed to support new endpoints
  final WingRequestBuilder requestBuilder;

  final Dio _dio;
  final WingLogger? _logger;

  /// Creates a client for [merchant].
  ///
  /// Every dependency except [merchant] is optional and injectable:
  /// - `dio`: HTTP client, used as is (URLs and headers are set per request)
  ///   and reused for all calls
  /// - `clock`: source of `timestamp` (default `DateTime.now`)
  /// - `random`: source of `rand_str` (default: secure random hex)
  /// - `crypto`: encryption and hashing
  /// - `logger`: receives request/response logs, with the REST API key
  ///   masked; nothing is logged without it
  WingService({
    required this.merchant,
    Dio? dio,
    WingClock? clock,
    WingRandom? random,
    this.crypto = const WingCrypto(),
    WingLogger? logger,
  }) : requestBuilder = WingRequestBuilder(
         merchant: merchant,
         clock: clock,
         random: random,
         crypto: crypto,
       ),
       _dio = dio ?? createDio(),
       _logger = logger;

  /// default HTTP client: platform adapter with certificate validation
  static Dio createDio() => Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
    ),
  );

  /// ## [authorize]
  ///
  /// Encrypts and signs [payment] and asks Wing for a payment token. On
  /// success, send the payer to [WingAuthorizationResponse.confirmUrl].
  ///
  /// Throws [ArgumentError] for an amount with more than 2 decimals, and a
  /// [WingException] of type [WingErrorType.encryption] for a password
  /// shorter than 16 bytes.
  Future<WingAuthorizationResponse> authorize(
    WingPayment payment, {
    CancelToken? cancelToken,
  }) async {
    if (utf8.encode(merchant.password).length < 16) {
      throw const WingException(
        WingErrorType.encryption,
        'The Wing password must be at least 16 bytes: its first 16 are the IV',
      );
    }
    final body = requestBuilder.authorization(payment);
    return _post(authorizationPath, body, (json) {
      final status = WingStatus.fromJson(json);
      final token = json['token'];
      return WingAuthorizationResponse(
        status: status,
        token: token is String ? token : null,
        confirmUrl: token is String && token.isNotEmpty
            ? confirmUrl(token)
            : null,
      );
    }, cancelToken);
  }

  /// ## [confirmUrl]
  ///
  /// Wing's payment page for an authorization [token]:
  /// `{base}/v1/online/payment/confirm?token=base64(token)`.
  Uri confirmUrl(String token) => Uri.parse(
    '${_url(confirmPath)}?token='
    '${Uri.encodeQueryComponent(base64.encode(utf8.encode(token)))}',
  );

  /// ## [inquiry]
  ///
  /// Details of the payment of [orderReferenceNo]. Call it when Wing
  /// redirects the payer to your `return_url` with `status=success`, and
  /// check [WingInquiryResponse.isPaid] with your price before delivering.
  Future<WingInquiryResponse> inquiry({
    required String orderReferenceNo,
    CancelToken? cancelToken,
  }) {
    return _post(
      inquiryPath,
      requestBuilder.inquiry(orderReferenceNo),
      WingInquiryResponse.fromJson,
      cancelToken,
    );
  }

  /// ## [decryptCallback]
  ///
  /// The JSON in the `contents` Wing POSTs to your callback URL, decrypted
  /// with the merchant password.
  ///
  /// Throws a [WingException] of type [WingErrorType.invalidCallback] when
  /// [contents] was not encrypted with the merchant password.
  String decryptCallback(String contents) {
    try {
      return crypto.aes256CbcDecrypt(
        contents,
        merchant.password,
        WingCrypto.passwordIv(merchant.password),
      );
    } on FormatException catch (error) {
      throw WingException(
        WingErrorType.invalidCallback,
        'Callback contents could not be decrypted with the Wing password',
        cause: error,
      );
    } on ArgumentError catch (error) {
      throw WingException(
        WingErrorType.invalidCallback,
        'Callback contents could not be decrypted with the Wing password',
        cause: error,
      );
    }
  }

  /// ## [parseCallback]
  ///
  /// Decrypts and parses the body Wing POSTed to your callback URL: the JSON
  /// `{"contents": "..."}`, the form `contents=...`, or the `contents`
  /// value itself.
  ///
  /// Only Wing and you know the password, so a body that decrypts came from
  /// Wing; still confirm with [inquiry] and the amount before delivering.
  WingTransaction parseCallback(String body) {
    final decrypted = decryptCallback(callbackContents(body));
    try {
      final decoded = json.decode(decrypted);
      if (decoded is Map<String, dynamic>) {
        return WingTransaction.fromJson(decoded);
      }
    } on FormatException catch (error) {
      throw WingException(
        WingErrorType.invalidCallback,
        'Decrypted callback is not JSON',
        cause: error,
      );
    }
    throw const WingException(
      WingErrorType.invalidCallback,
      'Decrypted callback is not a JSON object',
    );
  }

  /// The encrypted `contents` of a callback body (see [parseCallback]).
  static String callbackContents(String body) {
    final trimmed = body.trim();
    if (trimmed.startsWith('{')) {
      try {
        final decoded = json.decode(trimmed);
        if (decoded is Map && decoded['contents'] is String) {
          return decoded['contents'] as String;
        }
      } on FormatException {
        // not JSON: fall through
      }
    }
    if (trimmed.startsWith('contents=')) {
      return Uri.splitQueryString(trimmed)['contents'] ?? '';
    }
    return trimmed;
  }

  /// POST [body] as JSON and parse Wing's reply. Wing answers errors with a
  /// JSON body carrying `errorCode`, possibly with a non-2xx HTTP status,
  /// which is parsed like a success.
  Future<T> _post<T>(
    String path,
    Map<String, String> body,
    T Function(Map<String, dynamic> json) parse,
    CancelToken? cancelToken,
  ) async {
    final url = Uri.parse(_url(path));
    _logger?.call(
      '[Wing] POST $url '
      '${json.encode({...body, if (body.containsKey('rest_api_key')) 'rest_api_key': '***'})}',
    );

    Response<String> response;
    try {
      response = await _dio.postUri<String>(
        url,
        data: json.encode(body),
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            if (!_kIsWeb) 'User-Agent': 'dart-wing/$sdkVersion',
            if (!_kIsWeb && merchant.referer.isNotEmpty)
              'Referer': base64.encode(utf8.encode(merchant.referer)),
          },
          responseType: ResponseType.plain,
        ),
        cancelToken: cancelToken,
      );
    } on DioException catch (error) {
      final errorBody = error.response?.data;
      _logger?.call(
        '[Wing] ${error.response?.statusCode ?? error.type.name} '
        '${errorBody ?? error.message}',
      );
      final map = _statusBody(errorBody);
      if (map != null) return parse(map);
      final (type, message) = _describe(error);
      throw WingException(
        type,
        message,
        statusCode: error.response?.statusCode,
        cause: error,
      );
    }

    _logger?.call('[Wing] ${response.statusCode} ${response.data}');
    final map = _statusBody(response.data);
    if (map != null) return parse(map);
    throw WingException(
      WingErrorType.unexpectedResponse,
      'Unexpected response from Wing',
      statusCode: response.statusCode,
    );
  }

  String _url(String path) =>
      merchant.baseApiUrl.replaceFirst(RegExp(r'/+$'), '') + path;

  /// decode [body] when it is a JSON object with Wing's `errorCode`
  static Map<String, dynamic>? _statusBody(Object? body) {
    if (body is! String || body.isEmpty) return null;
    final Object? decoded;
    try {
      decoded = json.decode(body);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    return decoded.containsKey('errorCode') ? decoded : null;
  }

  static (WingErrorType, String) _describe(DioException error) {
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => (
        WingErrorType.timeout,
        'Timeout with Wing',
      ),
      DioExceptionType.badCertificate => (
        WingErrorType.badCertificate,
        'Bad certificate from Wing',
      ),
      DioExceptionType.badResponse => (
        WingErrorType.unexpectedResponse,
        'Unexpected response from Wing',
      ),
      DioExceptionType.cancel => (
        WingErrorType.cancelled,
        'Request to Wing was cancelled',
      ),
      DioExceptionType.connectionError => (
        WingErrorType.connection,
        'Could not connect to Wing',
      ),
      // unknown, and any type a newer dio adds
      _ => (
        WingErrorType.unknown,
        'Request to Wing failed: ${error.message ?? error.error}',
      ),
    };
  }
}

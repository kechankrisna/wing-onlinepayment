import 'package:flutter_wing/flutter_wing.dart';

/// A payment Wing is ready to take: open [confirmUrl] in `WingCheckoutView`.
class CheckoutSession {
  const CheckoutSession({
    required this.orderReferenceNo,
    required this.amount,
    required this.confirmUrl,
    required this.returnUrl,
    required this.cancelUrl,
  });

  final String orderReferenceNo;
  final num amount;
  final Uri confirmUrl;
  final String returnUrl;
  final String cancelUrl;
}

/// A step of the payment that failed, with a message for the payer.
class PaymentException implements Exception {
  const PaymentException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// What the app asks **your server**. The server holds the Wing credentials,
/// calls `WingService.authorize` and `WingService.inquiry`, and checks the
/// amount against the order it stored.
abstract interface class PaymentBackend {
  /// Creates the order and authorizes it with Wing.
  Future<CheckoutSession> createCheckout({
    required num amount,
    required String itemName,
  });

  /// Asks Wing whether the order is paid in full.
  Future<WingInquiryResponse> confirm(CheckoutSession session);
}

/// Demo stand-in for your server: calls Wing from the app with the `.env`
/// credentials. Never ship this; implement [PaymentBackend] with HTTP calls
/// to your server instead.
class DemoPaymentBackend implements PaymentBackend {
  DemoPaymentBackend(WingMerchant merchant, {WingService? wing})
    : _wing = wing ?? WingService(merchant: merchant),
      _referer = merchant.referer;

  final WingService _wing;
  final String _referer;

  @override
  Future<CheckoutSession> createCheckout({
    required num amount,
    required String itemName,
  }) async {
    final order = 'demo${DateTime.now().millisecondsSinceEpoch}';
    final returnUrl = '$_referer/wing/return';
    final cancelUrl = '$_referer/wing/cancel';
    final WingAuthorizationResponse auth;
    try {
      auth = await _wing.authorize(
        WingPayment(
          orderReferenceNo: order,
          amount: amount,
          returnUrl: returnUrl,
          cancelUrl: cancelUrl,
          itemName: itemName,
        ),
      );
    } on WingException catch (e) {
      throw PaymentException(e.message);
    }
    if (!auth.isSuccess) {
      throw PaymentException(
        'Wing refused the payment: ${auth.status.code} ${auth.status.message}',
      );
    }
    return CheckoutSession(
      orderReferenceNo: order,
      amount: amount,
      confirmUrl: auth.confirmUrl!,
      returnUrl: returnUrl,
      cancelUrl: cancelUrl,
    );
  }

  @override
  Future<WingInquiryResponse> confirm(CheckoutSession session) async {
    try {
      return await _wing.inquiry(orderReferenceNo: session.orderReferenceNo);
    } on WingException catch (e) {
      throw PaymentException(e.message);
    }
  }
}

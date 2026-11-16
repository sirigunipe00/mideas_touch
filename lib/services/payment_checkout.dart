import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Server-created Razorpay order returned by `create-razorpay-order`.
@immutable
class PaymentOrder {
  const PaymentOrder({
    required this.orderId,
    required this.amountPaise,
    required this.currency,
    required this.keyId,
    required this.packName,
  });

  final String orderId;
  final int amountPaise;
  final String currency;
  final String keyId;
  final String packName;
}

/// Successful Razorpay checkout payload (still needs server verify).
@immutable
class PaymentSuccess {
  const PaymentSuccess({
    required this.orderId,
    required this.paymentId,
    required this.signature,
  });

  final String orderId;
  final String paymentId;
  final String signature;
}

/// Opens the native Razorpay checkout sheet.
abstract class PaymentCheckout {
  /// Returns [PaymentSuccess] on success, `null` when the user cancels.
  Future<PaymentSuccess?> open({
    required String keyId,
    required String orderId,
    required int amountPaise,
    required String name,
    required String description,
    String? email,
    String? contact,
  });

  void dispose();
}

/// Production checkout via the `razorpay_flutter` method channel.
///
/// Uses the channel directly (same as razorpay_flutter 1.4.x `open`) and avoids
/// the package's `on()` → `resync()` path, which throws an unhandled
/// [MissingPluginException] when the native plugin is not linked yet.
class RazorpayCheckout implements PaymentCheckout {
  static const _channel = MethodChannel('razorpay_flutter');

  // Response type codes from razorpay_flutter
  static const _codeSuccess = 0;
  static const _codeError = 1;
  static const _paymentCancelled = 2;

  @override
  Future<PaymentSuccess?> open({
    required String keyId,
    required String orderId,
    required int amountPaise,
    required String name,
    required String description,
    String? email,
    String? contact,
  }) async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      throw Exception(
          'Razorpay checkout works only on Android and iOS devices.');
    }

    final options = <String, Object?>{
      'key': keyId,
      'amount': amountPaise,
      'currency': 'INR',
      'name': name,
      'description': description,
      'order_id': orderId,
      'prefill': <String, String>{
        if (email != null && email.isNotEmpty) 'email': email,
        if (contact != null && contact.isNotEmpty) 'contact': contact,
      },
      'theme': <String, String>{'color': '#EFBF05'},
    };

    try {
      final raw = await _channel.invokeMethod<dynamic>('open', options);
      if (raw is! Map) return null;
      final response = Map<dynamic, dynamic>.from(raw);
      final type = response['type'];
      final data = response['data'] is Map
          ? Map<dynamic, dynamic>.from(response['data'] as Map)
          : <dynamic, dynamic>{};

      if (type == _codeSuccess) {
        // Native SDK returns razorpay_* keys (see PaymentSuccessResponse.fromMap).
        final parsedOrderId =
            '${data['razorpay_order_id'] ?? data['orderId'] ?? orderId}';
        final parsedPaymentId =
            '${data['razorpay_payment_id'] ?? data['paymentId'] ?? ''}';
        final parsedSignature =
            '${data['razorpay_signature'] ?? data['signature'] ?? ''}';
        return PaymentSuccess(
          orderId: parsedOrderId,
          paymentId: parsedPaymentId,
          signature: parsedSignature,
        );
      }

      if (type == _codeError) {
        final code = data['code'];
        if (code == _paymentCancelled) return null;
        final message = data['message']?.toString();
        throw Exception(
            (message == null || message.isEmpty) ? 'Payment failed' : message);
      }

      return null;
    } on MissingPluginException {
      throw Exception(
        'Razorpay is not linked in this build. '
        'Stop the app and do a full restart '
        '(flutter run --dart-define-from-file=config/supabase.json), '
        'not hot reload.',
      );
    } on PlatformException catch (e) {
      if (e.code == '2' ||
          (e.message?.toLowerCase().contains('cancel') ?? false)) {
        return null;
      }
      throw Exception(e.message ?? 'Payment failed');
    }
  }

  @override
  void dispose() {}
}

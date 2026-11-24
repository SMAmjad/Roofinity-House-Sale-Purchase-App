/// Payment details shown to agents on the "Upload Ad" screen.
///
/// The real account number is not stored in the repository. Pass it at build
/// time from a local, git-ignored `payment.json` (see `payment.example.json`):
///
/// ```sh
/// flutter run --dart-define-from-file=payment.json
/// flutter build apk --release --dart-define-from-file=payment.json
/// ```
///
/// Without that file the app still builds and runs, showing placeholder values.
class PaymentConfig {
  PaymentConfig._();

  static const String recipient =
      String.fromEnvironment('PAYMENT_RECIPIENT', defaultValue: 'Roofinity');

  static const String method =
      String.fromEnvironment('PAYMENT_METHOD', defaultValue: 'JazzCash');

  static const String accountNumber =
      String.fromEnvironment('PAYMENT_ACCOUNT_NO', defaultValue: '03XX-XXXXXXX');

  static const String adFeePkr =
      String.fromEnvironment('AD_FEE_PKR', defaultValue: '500');
}

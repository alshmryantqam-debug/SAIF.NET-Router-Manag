import 'dart:math';

class Voucher {
  const Voucher({
    required this.username, required this.password,
    this.profile = 'default', this.comment = '',
    this.limitUptime = '', this.limitBytes = 0,
  });
  final String username;
  final String password;
  final String profile;
  final String comment;
  final String limitUptime;
  final int limitBytes;
  String get line => password == username ? username : '$username\t$password';
}

class VoucherGenerator {
  static List<Voucher> generate({
    required int count, String profile = 'default',
    int nameLength = 6, int passwordLength = 4, String prefix = '',
    bool samePassword = false, bool numericOnly = false,
    String limitUptime = '', int limitBytes = 0, String comment = '',
  }) {
    final random = Random.secure();
    final alphabet = numericOnly ? '0123456789' : 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
    String token(int length) => List.generate(
      length.clamp(1, 32), (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
    return List.generate(count.clamp(1, 1000), (_) {
      final username = '$prefix${token(nameLength)}';
      return Voucher(
        username: username, password: samePassword ? username : token(passwordLength),
        profile: profile, comment: comment, limitUptime: limitUptime,
        limitBytes: limitBytes,
      );
    });
  }
}

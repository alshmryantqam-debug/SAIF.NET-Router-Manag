class Voucher {
  const Voucher({
    required this.username, required this.password,
    this.profile = 'default', this.comment = '',
    this.limitUptime = '', this.limitBytesTotal = 0,
  });
  final String username;
  final String password;
  final String profile;
  final String comment;
  final String limitUptime;
  final int limitBytesTotal;

  Map<String, dynamic> toJson() => {
    'username': username, 'password': password, 'profile': profile,
    'comment': comment, 'limitUptime': limitUptime,
    'limitBytesTotal': limitBytesTotal,
  };
  factory Voucher.fromJson(Map<String, dynamic> json) => Voucher(
    username: json['username'] as String? ?? '',
    password: json['password'] as String? ?? '',
    profile: json['profile'] as String? ?? 'default',
    comment: json['comment'] as String? ?? '',
    limitUptime: json['limitUptime'] as String? ?? '',
    limitBytesTotal: (json['limitBytesTotal'] as num?)?.toInt() ?? 0,
  );
}

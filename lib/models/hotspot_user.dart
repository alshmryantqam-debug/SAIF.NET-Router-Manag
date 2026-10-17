class HotspotUser {
  const HotspotUser({
    this.id = '',
    required this.name,
    this.password = '',
    this.profile = 'default',
    this.comment = '',
    this.disabled = false,
    this.limitUptime = '',
    this.limitBytesTotal = 0,
  });
  final String id;
  final String name;
  final String password;
  final String profile;
  final String comment;
  final bool disabled;
  final String limitUptime;
  final int limitBytesTotal;

  factory HotspotUser.fromRow(Map<String, String> row) => HotspotUser(
    id: row['.id'] ?? row['id'] ?? '',
    name: row['name'] ?? '',
    password: row['password'] ?? '',
    profile: row['profile'] ?? 'default',
    comment: row['comment'] ?? '',
    disabled: row['disabled'] == 'true',
    limitUptime: row['limit-uptime'] ?? '',
    limitBytesTotal: int.tryParse(row['limit-bytes-total'] ?? '') ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'password': password, 'profile': profile,
    'comment': comment, 'disabled': disabled, 'limitUptime': limitUptime,
    'limitBytesTotal': limitBytesTotal,
  };
}

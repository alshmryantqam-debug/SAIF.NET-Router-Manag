class HotspotUser {
  const HotspotUser({
    this.id = '', required this.name, this.password = '',
    this.profile = 'default', this.comment = '', this.disabled = false,
    this.limitUptime = '', this.limitBytesTotal = 0,
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
    id: row['.id'] ?? row['id'] ?? '', name: row['name'] ?? '',
    password: row['password'] ?? '', profile: row['profile'] ?? 'default',
    comment: row['comment'] ?? '',
    disabled: row['disabled'] == 'true' || row['disabled'] == 'yes',
    limitUptime: row['limit-uptime'] ?? '',
    limitBytesTotal: int.tryParse(row['limit-bytes-total'] ?? '') ?? 0,
  );

  Map<String, dynamic> toParams() {
    final params = <String, dynamic>{'name': name, 'password': password, 'profile': profile};
    if (comment.isNotEmpty) params['comment'] = comment;
    if (limitUptime.isNotEmpty) params['limit-uptime'] = limitUptime;
    if (limitBytesTotal > 0) params['limit-bytes-total'] = limitBytesTotal.toString();
    if (disabled) params['disabled'] = 'true';
    return params;
  }
}

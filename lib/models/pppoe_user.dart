class PppoeUser {
  const PppoeUser({
    this.id = '', required this.name, this.password = '',
    this.service = 'any', this.profile = 'default', this.comment = '',
    this.disabled = false, this.localAddress = '', this.remoteAddress = '',
  });
  final String id;
  final String name;
  final String password;
  final String service;
  final String profile;
  final String comment;
  final bool disabled;
  final String localAddress;
  final String remoteAddress;

  factory PppoeUser.fromRow(Map<String, String> row) => PppoeUser(
    id: row['.id'] ?? row['id'] ?? '', name: row['name'] ?? '',
    password: row['password'] ?? '', service: row['service'] ?? 'any',
    profile: row['profile'] ?? 'default', comment: row['comment'] ?? '',
    disabled: row['disabled'] == 'true' || row['disabled'] == 'yes',
    localAddress: row['local-address'] ?? '',
    remoteAddress: row['remote-address'] ?? '',
  );

  Map<String, dynamic> toParams() {
    final params = <String, dynamic>{
      'name': name, 'password': password, 'service': service, 'profile': profile,
    };
    if (comment.isNotEmpty) params['comment'] = comment;
    if (localAddress.isNotEmpty) params['local-address'] = localAddress;
    if (remoteAddress.isNotEmpty) params['remote-address'] = remoteAddress;
    if (disabled) params['disabled'] = 'true';
    return params;
  }
}

class PppoeActive {
  const PppoeActive({this.name = '', this.service = '', this.address = '', this.uptime = '', this.callerId = ''});
  final String name;
  final String service;
  final String address;
  final String uptime;
  final String callerId;
  factory PppoeActive.fromRow(Map<String, String> row) => PppoeActive(
    name: row['name'] ?? '', service: row['service'] ?? '',
    address: row['address'] ?? '', uptime: row['uptime'] ?? '',
    callerId: row['caller-id'] ?? '',
  );
}

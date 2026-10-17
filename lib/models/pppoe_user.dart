class PppoeUser {
  const PppoeUser({
    this.id = '',
    required this.name,
    this.password = '',
    this.service = 'any',
    this.profile = 'default',
    this.comment = '',
    this.disabled = false,
    this.localAddress = '',
    this.remoteAddress = '',
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
    id: row['.id'] ?? row['id'] ?? '',
    name: row['name'] ?? '',
    password: row['password'] ?? '',
    service: row['service'] ?? 'any',
    profile: row['profile'] ?? 'default',
    comment: row['comment'] ?? '',
    disabled: row['disabled'] == 'true',
    localAddress: row['local-address'] ?? '',
    remoteAddress: row['remote-address'] ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'password': password, 'service': service,
    'profile': profile, 'comment': comment, 'disabled': disabled,
    'localAddress': localAddress, 'remoteAddress': remoteAddress,
  };
}

class PppoeActive {
  const PppoeActive({
    this.name = '', this.service = '', this.address = '',
    this.uptime = '', this.callerId = '',
  });
  final String name;
  final String service;
  final String address;
  final String uptime;
  final String callerId;

  factory PppoeActive.fromRow(Map<String, String> row) => PppoeActive(
    name: row['name'] ?? '',
    service: row['service'] ?? '',
    address: row['address'] ?? '',
    uptime: row['uptime'] ?? '',
    callerId: row['caller-id'] ?? '',
  );
}

class HotspotUser {
  final String id;
  final String server;
  final String name;
  final String profile;
  final bool disabled;
  final String comment;
  final String uptime;
  final String bytesOut;

  HotspotUser({
    required this.id,
    required this.server,
    required this.name,
    required this.profile,
    required this.disabled,
    this.comment = '',
    this.uptime = '0s',
    this.bytesOut = '0',
  });

  factory HotspotUser.fromJson(Map<String, dynamic> json) {
    return HotspotUser(
      id: (json['.id'] ?? json['id'] ?? '').toString(),
      server: (json['server'] ?? 'all').toString(),
      name: (json['name'] ?? '').toString(),
      profile: (json['profile'] ?? 'default').toString(),
      disabled: json['disabled'] == 'true' || json['disabled'] == true,
      comment: (json['comment'] ?? '').toString(),
      uptime: (json['uptime'] ?? '0s').toString(),
      bytesOut: (json['bytes-out'] ?? '0').toString(),
    );
  }
}

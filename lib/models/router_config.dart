import 'package:uuid/uuid.dart';

enum RouterOsVersion { v6, v7 }

extension RouterOsVersionLabel on RouterOsVersion {
  String get label => this == RouterOsVersion.v6 ? 'RouterOS v6' : 'RouterOS v7';
}

class RouterProfile {
  RouterProfile({
    String? id,
    required this.name,
    required this.host,
    this.port = 8728,
    required this.username,
    required this.password,
    this.version = RouterOsVersion.v7,
    this.useTls = false,
  }) : id = id ?? const Uuid().v4();

  final String id;
  final String name;
  final String host;
  final int port;
  final String username;
  final String password;
  final RouterOsVersion version;
  final bool useTls;

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'host': host, 'port': port,
    'username': username, 'password': password,
    'version': version.name, 'useTls': useTls,
  };

  factory RouterProfile.fromJson(Map<String, dynamic> json) => RouterProfile(
    id: json['id'] as String?,
    name: json['name'] as String? ?? 'Router',
    host: json['host'] as String? ?? '192.168.88.1',
    port: (json['port'] as num?)?.toInt() ?? 8728,
    username: json['username'] as String? ?? 'admin',
    password: json['password'] as String? ?? '',
    version: json['version'] == 'v6' ? RouterOsVersion.v6 : RouterOsVersion.v7,
    useTls: json['useTls'] as bool? ?? false,
  );
}

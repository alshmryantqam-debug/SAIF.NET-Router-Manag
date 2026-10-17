import 'package:uuid/uuid.dart';

enum RouterVersion { auto, v6, v7 }

class RouterProfile {
  RouterProfile({
    String? id, required this.name, required this.host,
    this.username = 'admin', this.password = '',
    this.restPort = 80, this.apiPort = 8728,
    this.version = RouterVersion.auto, this.useSsl = false,
    this.lastDetected,
  }) : id = id ?? const Uuid().v4();

  final String id;
  final String name;
  final String host;
  final String username;
  final String password;
  final int restPort;
  final int apiPort;
  final RouterVersion version;
  final bool useSsl;
  final RouterVersion? lastDetected;
  String get displayName => name.trim().isEmpty ? host : name;

  RouterProfile copyWith({
    String? id, String? name, String? host, String? username,
    String? password, int? restPort, int? apiPort,
    RouterVersion? version, bool? useSsl, RouterVersion? lastDetected,
  }) => RouterProfile(
    id: id ?? this.id, name: name ?? this.name, host: host ?? this.host,
    username: username ?? this.username, password: password ?? this.password,
    restPort: restPort ?? this.restPort, apiPort: apiPort ?? this.apiPort,
    version: version ?? this.version, useSsl: useSsl ?? this.useSsl,
    lastDetected: lastDetected ?? this.lastDetected,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'host': host, 'username': username,
    'password': password, 'restPort': restPort, 'apiPort': apiPort,
    'version': version.name, 'useSsl': useSsl,
    'lastDetected': lastDetected?.name,
  };

  factory RouterProfile.fromJson(Map<String, dynamic> json) => RouterProfile(
    id: json['id'] as String?, name: json['name'] as String? ?? 'Router',
    host: json['host'] as String? ?? '192.168.88.1',
    username: json['username'] as String? ?? 'admin',
    password: json['password'] as String? ?? '',
    restPort: (json['restPort'] as num?)?.toInt() ?? 80,
    apiPort: (json['apiPort'] as num?)?.toInt() ?? 8728,
    version: RouterVersion.values.firstWhere(
      (v) => v.name == json['version'], orElse: () => RouterVersion.auto),
    useSsl: json['useSsl'] as bool? ?? false,
    lastDetected: RouterVersion.values.where((v) => v.name == json['lastDetected']).isEmpty
      ? null
      : RouterVersion.values.firstWhere((v) => v.name == json['lastDetected']),
  );
}

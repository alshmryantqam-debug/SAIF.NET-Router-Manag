class MikrotikSession {
  final String id;
  final String name;
  final String address;
  final String uptime;
  final String callerId;
  final String bytesIn;
  final String bytesOut;
  final bool isPppoe;

  const MikrotikSession({
    required this.id,
    required this.name,
    required this.address,
    required this.uptime,
    required this.callerId,
    required this.bytesIn,
    required this.bytesOut,
    required this.isPppoe,
  });

  factory MikrotikSession.fromMap(
    Map<String, dynamic> map, {
    required bool isPppoe,
  }) {
    String value(dynamic raw, String fallback) {
      if (raw == null) return fallback;
      final result = raw.toString().trim();
      return result.isEmpty ? fallback : result;
    }

    return MikrotikSession(
      id: value(map['.id'], ''),
      name: value(map['name'] ?? map['user'], 'مجهول'),
      address: value(map['address'], '0.0.0.0'),
      uptime: value(map['uptime'], '0s'),
      callerId: value(map['caller-id'] ?? map['mac-address'], 'غير متوفر'),
      bytesIn: value(map['bytes-in'], '0'),
      bytesOut: value(map['bytes-out'], '0'),
      isPppoe: isPppoe,
    );
  }
}

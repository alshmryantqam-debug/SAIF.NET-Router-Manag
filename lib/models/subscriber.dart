class Subscriber {
  final String id;
  final String name;
  final String profile;
  final bool disabled;
  final String? phone;
  final DateTime? expiry;
  final int? price;
  final bool online;
  final String? activeId; // معرّف الجلسة في /ppp/active
  final String? address;
  final String? uptime;

  const Subscriber({
    required this.id,
    required this.name,
    required this.profile,
    required this.disabled,
    this.phone,
    this.expiry,
    this.price,
    this.online = false,
    this.activeId,
    this.address,
    this.uptime,
  });

  int? get daysLeft => expiry?.difference(DateTime.now()).inDays;
  bool get expired => expiry != null && expiry!.isBefore(DateTime.now());

  /// البيانات الإضافية تُخزَّن في comment بصيغة: exp=2026-11-20;phone=09xxxx;price=15000
  static Map<String, String> parseComment(String? c) {
    final m = <String, String>{};
    for (final part in (c ?? '').split(';')) {
      final i = part.indexOf('=');
      if (i > 0) m[part.substring(0, i).trim()] = part.substring(i + 1).trim();
    }
    return m;
  }

  static String buildComment({DateTime? expiry, String? phone, int? price}) {
    final p = <String>[];
    if (expiry != null) p.add('exp=${expiry.toIso8601String().substring(0, 10)}');
    if (phone != null && phone.isNotEmpty) p.add('phone=$phone');
    if (price != null) p.add('price=$price');
    return p.join(';');
  }

  factory Subscriber.fromRos(Map secret, Map? active) {
    final c = parseComment(secret['comment']?.toString());
    return Subscriber(
      id: secret['.id'],
      name: secret['name'],
      profile: secret['profile'] ?? 'default',
      disabled: secret['disabled'] == 'true',
      phone: c['phone'],
      expiry: c['exp'] != null ? DateTime.tryParse(c['exp']!) : null,
      price: int.tryParse(c['price'] ?? ''),
      online: active != null,
      activeId: active?['.id'],
      address: active?['address'],
      uptime: active?['uptime'],
    );
  }
}

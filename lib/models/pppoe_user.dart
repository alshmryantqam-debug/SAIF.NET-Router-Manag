class PppoeUser {
  final String id;
  final String name;
  final String profile;
  final String service;
  final bool disabled;
  final String comment;

  /// Retained for compatibility with existing screens/services that use this
  /// model. Avoid displaying or logging this value.
  final String password;

  PppoeUser({
    required this.id,
    required this.name,
    required this.profile,
    required this.service,
    required this.disabled,
    this.comment = '',
    this.password = '',
  });

  factory PppoeUser.fromJson(Map<String, dynamic> json) {
    return PppoeUser(
      id: (json['.id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      profile: (json['profile'] ?? 'default').toString(),
      service: (json['service'] ?? 'any').toString(),
      disabled: json['disabled'] == 'true' || json['disabled'] == true,
      comment: (json['comment'] ?? '').toString(),
      password: (json['password'] ?? '').toString(),
    );
  }
}

/// Backward-compatible name used by existing app code.
typedef PPPoEUser = PppoeUser;

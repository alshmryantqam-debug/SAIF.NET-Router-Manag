class PPPoEUser {
  final String id;
  final String name;
  final String password;
  final String profile;
  final String service;
  final bool disabled;

  PPPoEUser({
    required this.id,
    required this.name,
    required this.password,
    required this.profile,
    required this.service,
    required this.disabled,
  });

  factory PPPoEUser.fromJson(Map<String, dynamic> json) {
    return PPPoEUser(
      id: json['.id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      password: json['password'] ?? '',
      profile: json['profile'] ?? 'default',
      service: json['service'] ?? 'any',
      disabled: json['disabled'] == 'true',
    );
  }
}
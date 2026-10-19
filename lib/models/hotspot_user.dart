class HotspotUser {
  final String id;
  final String name;
  final String password;
  final String profile;
  final bool disabled;

  HotspotUser({
    required this.id,
    required this.name,
    required this.password,
    required this.profile,
    required this.disabled,
  });

  factory HotspotUser.fromJson(Map<String, dynamic> json) {
    return HotspotUser(
      id: json['.id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      password: json['password'] ?? '',
      profile: json['profile'] ?? 'default',
      disabled: json['disabled'] == 'true',
    );
  }
}
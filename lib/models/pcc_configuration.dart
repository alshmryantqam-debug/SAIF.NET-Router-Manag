class PccWanConfig {
  const PccWanConfig({
    required this.interfaceName,
    required this.gateway,
    required this.weight,
  });

  final String interfaceName;
  final String gateway;
  final double weight;

  PccWanConfig copyWith({
    String? interfaceName,
    String? gateway,
    double? weight,
  }) {
    return PccWanConfig(
      interfaceName: interfaceName ?? this.interfaceName,
      gateway: gateway ?? this.gateway,
      weight: weight ?? this.weight,
    );
  }
}

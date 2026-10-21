class MikrotikTorch {
  final String srcAddress;
  final String dstAddress;
  final String protocol;
  final String port;
  final String txSpeed;
  final String rxSpeed;

  const MikrotikTorch({required this.srcAddress, required this.dstAddress, required this.protocol, required this.port, required this.txSpeed, required this.rxSpeed});

  factory MikrotikTorch.fromMap(Map<String, dynamic> map) => MikrotikTorch(
    srcAddress: (map['src-address'] ?? map['src-address4'] ?? map['src'] ?? 'غير معروف').toString(),
    dstAddress: (map['dst-address'] ?? map['dst-address4'] ?? map['dst'] ?? 'غير معروف').toString(),
    protocol: (map['protocol'] ?? 'any').toString(),
    port: (map['dst-port'] ?? map['port'] ?? 'any').toString(),
    txSpeed: (map['tx-rate'] ?? map['tx'] ?? '0').toString(),
    rxSpeed: (map['rx-rate'] ?? map['rx'] ?? '0').toString(),
  );
}

/// Normalized read-only summary of network inventory returned by RouterOS.
class NetworkOverview {
  final int interfacesTotal;
  final int interfacesRunning;
  final int hotspotSessions;
  final int pppSessions;
  final int dhcpLeases;
  final int simpleQueues;

  const NetworkOverview({
    required this.interfacesTotal,
    required this.interfacesRunning,
    required this.hotspotSessions,
    required this.pppSessions,
    required this.dhcpLeases,
    required this.simpleQueues,
  });

  factory NetworkOverview.fromRows({
    required List<dynamic> interfaces,
    required List<dynamic> hotspotActive,
    required List<dynamic> pppActive,
    required List<dynamic> dhcpLeases,
    required List<dynamic> simpleQueues,
  }) {
    final running = interfaces.where((row) {
      if (row is! Map) return false;
      final value = row['running']?.toString().toLowerCase();
      return value == 'true' || value == 'yes';
    }).length;
    return NetworkOverview(
      interfacesTotal: interfaces.length,
      interfacesRunning: running,
      hotspotSessions: hotspotActive.length,
      pppSessions: pppActive.length,
      dhcpLeases: dhcpLeases.length,
      simpleQueues: simpleQueues.length,
    );
  }
}

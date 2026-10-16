/// Resolves conventional RouterOS REST and Binary API ports without silently downgrading TLS.
class RouterOsPortResolver {
  const RouterOsPortResolver._();

  static int restPort({required int configuredPort, required bool tls}) {
    if ([80, 443, 8728, 8729].contains(configuredPort)) return tls ? 443 : 80;
    return configuredPort;
  }

  static int binaryPort({required int configuredPort, required bool tls}) {
    if ([80, 443, 8728, 8729].contains(configuredPort)) return tls ? 8729 : 8728;
    return configuredPort;
  }
}

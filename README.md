# SAIF.NET / TikPlus ULTRA

Arabic-first Flutter application for managing MikroTik RouterOS devices.

## Current architecture

- Flutter UI with Arabic RTL defaults.
- Riverpod state providers and GoRouter navigation.
- Direct RouterOS REST API client and Binary API client.
- Router connection configuration stored with `flutter_secure_storage`.
- Current screens include dashboard, Hotspot, PPPoE, vouchers, settings, router list, and terminal.

## Development

Requirements: Flutter stable compatible with Dart SDK `>=3.2.0 <4.0.0`.

```sh
flutter pub get
flutter test
flutter analyze
```

## Security notes

- Do not connect this app to production routers during development tests.
- TLS certificate validation in the current RouterOS REST and Binary API clients needs remediation before relying on TLS for untrusted networks.
- Do not add plaintext router credentials to logs, fixtures, screenshots, or repository files.
- Router-changing operations must be reviewed and protected before enabling remote or automated execution.

## Planned staged work

1. Establish regression tests for current model and service behavior.
2. Harden RouterOS transport and command validation.
3. Add subscription-plan and usage-limit foundations with a replaceable payment interface; no live payment provider until explicitly configured.
4. Add sanitized encrypted configuration backups, diff, and safe restore flows.
5. Add organization roles, invitations, audit history, and two-factor authentication.
6. Continue with alerts, guided configuration, rollout controls, drift/compliance, AI-assisted diagnostics, topology, traffic analytics, and optional ISP/MSP features.

Features requiring a server, external provider, deployment secrets, or real RouterOS v6/v7 validation must be reported as incomplete until those dependencies are available and tested.

# Secure MikroTik access for SAIF.NET

This guide is intentionally conservative. Do not expose router management services directly to the public internet.

## RouterOS v7 REST API

- Prefer HTTPS through the router's `www-ssl` service.
- Install a certificate signed by a CA you trust and trust that CA on the Android device. The certificate name or IP subject alternative name must match the host entered in SAIF.NET.
- Do not bypass TLS certificate validation to make a self-signed certificate work. Import/trust the correct CA instead.
- Disable the plain HTTP REST endpoint with `/ip/service/webserver/set rest-plain=no` after confirming HTTPS access works.
- Restrict the web service with `/ip/service/set www-ssl available-from=<management-subnet>` and firewall rules. Use the actual management/VPN subnet; do not copy a placeholder literally.
- Give the application a dedicated RouterOS account with the minimum policies required. Avoid `sensitive` access unless a specific feature truly requires it.

## RouterOS v6 Binary API

- Prefer API-SSL on TCP 8729 with a valid, trusted certificate.
- Do not send credentials or management traffic across untrusted networks using plain API on TCP 8728.
- Keep API/API-SSL restricted to a management subnet or VPN. Do not create a public WAN port-forward for the API.

## Remote management

Use a VPN such as WireGuard to reach remote routers. Keep WinBox, SSH, WebFig, REST and API services unavailable from the public WAN. Maintain a tested out-of-band recovery method before changing access controls.

## SAIF.NET safety notes

- TLS validation must remain enabled in the app.
- A certificate error is a trust/configuration issue to fix, not a reason to disable verification.
- Treat exported configurations as sensitive. Redact passwords, tokens, private keys and shared secrets before sharing diagnostics.
- Review a proposed change and confirm a fresh backup before any future write-capable workflow.
- The current Safe Apply plan model is preview/validation only; it is not yet a transactional executor or a substitute for RouterOS validation and rollback testing.

## Source references

- MikroTik RouterOS REST API: https://manual.mikrotik.com/docs/developer-guides/rest-api/
- MikroTik RouterOS API: https://manual.mikrotik.com/docs/developer-guides/api/
- MikroTik securing your router: https://manual.mikrotik.com/docs/getting-started/securing-your-router/

# SAIF.NET encrypted router backups

## Current implementation

The local backup vault encrypts the complete supplied RouterOS configuration text using AES-256-GCM before writing the envelope to the app support directory. The 32-byte key is generated with a cryptographically secure random generator and stored using Android's secure storage integration. The envelope includes a random nonce and authentication tag; tampering should fail decryption.

The vault supports listing metadata, decrypting a backup for inspection/export, and deleting a local backup. It deliberately does **not** connect to RouterOS, fetch an export, execute commands, or restore configuration to a router.

## Important limitations

- The caller must obtain configuration through a separately authorized read operation and pass it to the vault.
- The encryption key is device-local. Clearing app data, uninstalling the app, or losing secure-storage material can make backups unrecoverable. A future release needs an explicit encrypted key export/recovery flow with a user-held recovery secret.
- Backups can contain router credentials and network topology. Do not share them casually or upload them to a third-party service.
- Restore-to-router must remain disabled until it has a reviewed diff, verified target/version, fresh pre-change backup, explicit approval, audit record and tested rollback path on CHR for RouterOS v6/v7.

## References

- MikroTik REST API and export sensitivity: https://manual.mikrotik.com/docs/developer-guides/rest-api/
- Dart cryptography package: https://pub.dev/packages/cryptography
- Flutter secure storage: https://pub.dev/packages/flutter_secure_storage

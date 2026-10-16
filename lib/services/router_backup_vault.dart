import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'encrypted_backup_codec.dart';

class RouterBackupRecord {
  final String id;
  final String label;
  final DateTime createdAt;
  final int fileSize;
  final bool readable;

  const RouterBackupRecord({
    required this.id,
    required this.label,
    required this.createdAt,
    required this.fileSize,
    required this.readable,
  });
}

class RouterBackupVault {
  static const _storage = FlutterSecureStorage();
  static const _keyName = 'saifnet.backup.aes256.key.v1';
  static const _folderName = 'saifnet_encrypted_backups';
  static const _uuid = Uuid();

  Future<Directory> _directory() async {
    final root = await getApplicationSupportDirectory();
    final directory = Directory('${root.path}/$_folderName');
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  Future<List<int>> _key({bool create = true}) async {
    var encoded = await _storage.read(key: _keyName);
    if (encoded == null) {
      if (!create) throw StateError('مفتاح النسخ الاحتياطي غير موجود على هذا الجهاز');
      final random = Random.secure();
      final bytes = List<int>.generate(32, (_) => random.nextInt(256));
      encoded = base64Encode(bytes);
      await _storage.write(key: _keyName, value: encoded);
    }
    final bytes = base64Decode(encoded);
    if (bytes.length != 32) throw StateError('مفتاح النسخ الاحتياطي غير صالح');
    return bytes;
  }

  Future<RouterBackupRecord> createBackup({
    required String label,
    required String configurationText,
  }) async {
    if (label.trim().isEmpty) throw ArgumentError('اسم النسخة الاحتياطية مطلوب');
    if (configurationText.trim().isEmpty) throw ArgumentError('محتوى النسخة الاحتياطية فارغ');

    final id = _uuid.v4();
    final createdAt = DateTime.now().toUtc();
    final payload = jsonEncode({
      'id': id,
      'label': label.trim(),
      'createdAt': createdAt.toIso8601String(),
      'configuration': configurationText,
    });
    final encrypted = await EncryptedBackupCodec.encrypt(
      keyBytes: await _key(),
      plaintext: payload,
    );
    final file = File('${(await _directory()).path}/$id.snbak');
    await file.writeAsString(encrypted, flush: true);
    return RouterBackupRecord(
      id: id,
      label: label.trim(),
      createdAt: createdAt,
      fileSize: await file.length(),
      readable: true,
    );
  }

  Future<List<RouterBackupRecord>> listBackups() async {
    final directory = await _directory();
    final files = await directory
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.snbak'))
        .cast<File>()
        .toList();
    final records = <RouterBackupRecord>[];
    for (final file in files) {
      final id = file.uri.pathSegments.last.replaceAll('.snbak', '');
      try {
        final payload = jsonDecode(await EncryptedBackupCodec.decrypt(
          keyBytes: await _key(create: false),
          envelope: await file.readAsString(),
        )) as Map<String, dynamic>;
        records.add(RouterBackupRecord(
          id: id,
          label: payload['label']?.toString() ?? 'نسخة بدون اسم',
          createdAt: DateTime.tryParse(payload['createdAt']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          fileSize: await file.length(),
          readable: true,
        ));
      } catch (_) {
        records.add(RouterBackupRecord(
          id: id,
          label: 'نسخة غير قابلة للتحقق',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          fileSize: await file.length(),
          readable: false,
        ));
      }
    }
    records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return records;
  }

  Future<String> readBackupConfiguration(String id) async {
    if (!_validId(id)) throw ArgumentError.value(id, 'id', 'Invalid backup id');
    final file = File('${(await _directory()).path}/$id.snbak');
    final payload = jsonDecode(await EncryptedBackupCodec.decrypt(
      keyBytes: await _key(create: false),
      envelope: await file.readAsString(),
    ));
    if (payload is! Map<String, dynamic> ||
        payload['id'] != id ||
        payload['configuration'] is! String) {
      throw const FormatException('محتوى النسخة الاحتياطية غير صالح');
    }
    return payload['configuration'] as String;
  }

  Future<void> deleteBackup(String id) async {
    if (!_validId(id)) throw ArgumentError.value(id, 'id', 'Invalid backup id');
    final file = File('${(await _directory()).path}/$id.snbak');
    if (await file.exists()) await file.delete();
  }

  bool _validId(String id) => RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id);
}

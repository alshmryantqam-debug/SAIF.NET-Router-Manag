# SAIF.NET Router Manager
منصة Flutter لإدارة ومراقبة أجهزة MikroTik بواجهة عربية RTL.

## مبادئ أساسية
- المراقبة أولاً والقراءة فقط افتراضياً.
- عدم حفظ كلمات المرور أو أسرار الاتصال داخل Git.
- دعم REST في RouterOS v7 وBinary API للعمليات المتوافقة مع الإصدارات الأقدم.
- لا تعديل تلقائي لـ PCC أو Queue أو Hotspot أو Firewall. أي تعديل مستقبلي يتطلب تأكيداً ونسخة احتياطية وخطة تراجع.

## التطوير
```bash
flutter pub get
flutter analyze
flutter test
```

راجع [المعمارية](docs/architecture/README.md)، [الأمان](docs/security/README.md)، و[توافق RouterOS](docs/routeros-compatibility/README.md).
الهيكل الجديد يُضاف تدريجياً؛ وجود مجلد لا يعني أن الميزة مكتملة أو موصولة بالواجهة.
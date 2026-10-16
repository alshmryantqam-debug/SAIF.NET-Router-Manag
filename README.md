# SAIF.NET Router Manager · ULTRA v1.1

منصة Flutter عربية لإدارة ومراقبة **MikroTik RouterOS** — واجهة RTL داكنة، أمان أولاً، وتشخيصات قراءة فقط.

## ما يشمله `main` الآن

- اتصال **REST (v7)** + **Binary API (v6)** مع كشف تلقائي
- لوحة قيادة + Hotspot / PPPoE / كروت
- **مركز مراقبة الشبكة** (واجهات، جلسات، DHCP، Queues، Firewall، Routes، Logs)
- تنبيهات WAN و CPU / ذاكرة / حرارة
- **خزنة نسخ مشفّرة AES-256-GCM** محلية
- **Safe Apply** (معاينة خطط فقط)
- تحذير TLS / عدم قبول الشهادات التالفة تلقائياً في Binary API
- شاشة طرفية مقفلة عمداً
- `local_auth` + workflow بناء APK

## تشغيل

```bash
flutter pub get
flutter test
flutter run
```

## APK

Actions → **SAIF.NET Android APK** → Run workflow على `main`.

Artifact: `saif-net-router-manager-debug-apk`

## أمان

- لا أوامر طرفية حرة
- Safe Apply لا ينفّذ على الراوتر
- النسخ المشفّرة محلية على الجهاز

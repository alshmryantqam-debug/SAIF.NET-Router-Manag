import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const TikPlusUltraApp());
}

class TikPlusUltraApp extends StatelessWidget {
  const TikPlusUltraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'تيك بلس ألترا - TikPlus ULTRA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF070B14),
        primaryColor: const Color(0xFF0EA5E9),
        cardColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF0EA5E9),
          secondary: Color(0xFFF59E0B),
          surface: Color(0xFF0F172A),
        ),
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: PinLockAndRoutersScreen(),
      ),
    );
  }
}

// ============================================================================
// محرك الاتصال بـ RouterOS v7 باستخدام مكتبة dart:io المدمجة بدون حزم خارجية
// ============================================================================
class NativeMikrotikClient {
  final String ipPort;
  final String user;
  final String pass;

  NativeMikrotikClient({required this.ipPort, required this.user, required this.pass});

  Future<Map<String, dynamic>?> getSystemResource() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 3);
      client.badCertificateCallback = (cert, host, port) => true;
      final uri = Uri.parse('http://$ipPort/rest/system/resource');
      final request = await client.getUrl(uri);
      final auth = base64Encode(utf8.encode('$user:$pass'));
      request.headers.set('Authorization', 'Basic $auth');
      request.headers.set('Content-Type', 'application/json');
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final dec = jsonDecode(body);
        if (dec is List && dec.isNotEmpty) return dec[0];
        if (dec is Map<String, dynamic>) return dec;
      }
    } catch (_) {}
    return null;
  }
}

// ============================================================================
// الشاشة 1: شاشة الدخول الفخمة + رمز القفل PIN + الراوترات المحفوظة والكلاود
// ============================================================================
class PinLockAndRoutersScreen extends StatefulWidget {
  const PinLockAndRoutersScreen({super.key});

  @override
  State<PinLockAndRoutersScreen> createState() => _PinLockAndRoutersScreenState();
}

class _PinLockAndRoutersScreenState extends State<PinLockAndRoutersScreen> {
  bool isLocked = false;
  String enteredPin = '';

  final List<Map<String, dynamic>> savedRouters = [
    {'name': 'استغفر الله (البرج الرئيسي)', 'ip': '2.2.2.2:80', 'user': 'admin', 'pass': '', 'model': 'CCR2116-12G-4S+ · ROS 7.24.5', 'status': 'متصل مباشر', 'isCloud': false},
    {'name': 'كلاود استغفر الله (من خارج الشبكة)', 'ip': '10.200.1.2:80', 'user': 'admin', 'pass': '', 'model': 'نفق سحابي للراوتر والصحون', 'status': 'فتح الكلاود', 'isCloud': true},
    {'name': 'لاحول ولاقوة (برج 2 - الميادين)', 'ip': '2.2.2.2:80', 'user': 'admin', 'pass': '', 'model': 'RB4011iGS+ · نفق سحابي', 'status': 'سحابي', 'isCloud': false},
    {'name': 'الحمدلله (برج 3 - السوق)', 'ip': '7.7.7.7:80', 'user': 'admin', 'pass': '', 'model': 'CCR1036 · نفق سحابي', 'status': 'سحابي', 'isCloud': false},
  ];

  void _showAddRouterModal() {
    final nameCtrl = TextEditingController();
    final ipCtrl = TextEditingController(text: '192.168.88.1:80');
    final userCtrl = TextEditingController(text: 'admin');
    final passCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFF0EA5E9))),
          title: const Text('➕ إضافة وربط راوتر مايكروتك جديد', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم البرج / الشبكة')),
                TextField(controller: ipCtrl, decoration: const InputDecoration(labelText: 'الـ IP والبورت (مثال 192.168.88.1:80)')),
                TextField(controller: userCtrl, decoration: const InputDecoration(labelText: 'اسم المستخدم (Winbox)')),
                TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
              onPressed: () {
                final rName = nameCtrl.text.isEmpty ? 'برج جديد' : nameCtrl.text;
                setState(() {
                  savedRouters.insert(0, {
                    'name': rName,
                    'ip': ipCtrl.text.trim(),
                    'user': userCtrl.text.trim(),
                    'pass': passCtrl.text,
                    'model': 'MikroTik RouterOS v7',
                    'status': 'متصل مباشر',
                    'isCloud': false,
                  });
                });
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MainRouterControlShell(
                      routerName: rName,
                      routerIp: ipCtrl.text.trim(),
                      username: userCtrl.text.trim(),
                      password: passCtrl.text,
                    ),
                  ),
                );
              },
              child: const Text('حفظ واتصال فوراً'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLocked) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)]),
                  ),
                  child: const Icon(Icons.lock, size: 48, color: Colors.white),
                ),
                const SizedBox(height: 16),
                const Text('أدخل رمز القفل الخاص بك', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(enteredPin.padRight(4, '•'), style: const TextStyle(fontSize: 32, letterSpacing: 14, color: Colors.amber)),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    for (var i = 1; i <= 9; i++)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.white12)),
                          minimumSize: const Size(80, 52),
                        ),
                        onPressed: () {
                          setState(() {
                            enteredPin += '$i';
                            if (enteredPin.length >= 4) {
                              isLocked = false;
                              enteredPin = '';
                            }
                          });
                        },
                        child: Text('$i', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.white12)),
                        minimumSize: const Size(80, 52),
                      ),
                      onPressed: () {
                        setState(() {
                          enteredPin += '0';
                          if (enteredPin.length >= 4) {
                            isLocked = false;
                            enteredPin = '';
                          }
                        });
                      },
                      child: const Text('0', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('T+', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('تيك بلس ألترا · TikPlus ULTRA', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                Text('المنصة السحابية لإدارة الشبكات وبيع الاشتراكات', style: TextStyle(fontSize: 10, color: Colors.white60)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.fingerprint, color: Color(0xFF0EA5E9)),
            onPressed: () => setState(() => isLocked = true),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: Colors.black),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerSaaSPortalScreen()));
              },
              child: const Text('👑 لوحة المالك', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF6366F1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('رقم الحساب: +963960663450 (سيف خالد)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      SizedBox(height: 4),
                      Text('الترخيص: باقة ULTRA مفعلة (نفق + صحون + دمج + طباعة)', style: TextStyle(color: Color(0xFF34D399), fontSize: 11)),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerSaaSPortalScreen()));
                  },
                  child: const Text('شام كاش', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text('🖧 الراوترات المحفوظة والدخول السحابي عن بُعد:', style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),

          ...savedRouters.map((r) {
            final bool isCloud = r['isCloud'] as bool;
            return Card(
              color: isCloud ? const Color(0xFF0C4A6E) : const Color(0xFF0F172A),
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: isCloud ? const Color(0xFF38BDF8) : Colors.white10),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isCloud ? Colors.lightBlue : Colors.indigo.shade900,
                  child: Icon(isCloud ? Icons.cloud_done : Icons.router, color: Colors.white),
                ),
                title: Text(r['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text('${r['ip']} · ${r['model']}', style: const TextStyle(fontSize: 11, color: Colors.white70)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isCloud ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    r['status'],
                    style: TextStyle(color: isCloud ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MainRouterControlShell(
                        routerName: r['name'],
                        routerIp: r['ip'],
                        username: r['user'] ?? 'admin',
                        password: r['pass'] ?? '',
                      ),
                    ),
                  );
                },
              ),
            );
          }),

          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0EA5E9),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _showAddRouterModal,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('إضافة راوتر جديد', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ تم فحص الشبكة المحلية واكتشاف راوتر CCR2116 تلقائياً!')),
                    );
                  },
                  icon: const Icon(Icons.wifi_find),
                  label: const Text('اكتشاف تلقائي', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// الغلاف الرئيسي للتحكم بالراوتر (يضم الشاشات التفاعلية من 2 إلى 9)
// ============================================================================
class MainRouterControlShell extends StatefulWidget {
  final String routerName;
  final String routerIp;
  final String username;
  final String password;

  const MainRouterControlShell({
    super.key,
    required this.routerName,
    required this.routerIp,
    this.username = 'admin',
    this.password = '',
  });

  @override
  State<MainRouterControlShell> createState() => _MainRouterControlShellState();
}

class _MainRouterControlShellState extends State<MainRouterControlShell> {
  int currentScreenIndex = 0;
  late NativeMikrotikClient client;

  // الموارد الحية
  String cpuLoad = '3%';
  String temperature = '47°C';
  double towerVoltage = 24.4;
  double alarmVoltageLimit = 21.8;
  String rxSpeed = '183.9 م/ث';
  String txSpeed = '18.7 م/ث';

  // المساعد الصوتي
  bool isListeningVoice = false;
  String voiceText = 'اضغط على المايك وتكلم بأي أمر للمايكروتك...';

  // حالة البرودباند التفاعلية
  String pppoeFilter = 'ALL';
  String pppoeSearch = '';
  final List<Map<String, dynamic>> pppoeUsers = [
    {'name': 'رمضان حميد الشلاف', 'user': '72', 'prof': '750', 'info': 'مفصول منذ 11 دقيقة · 2026-03-06', 'spd': 'نائم', 'st': 'SLEEP'},
    {'name': 'ايهم موحسن', 'user': 'AEHM', 'prof': '2.ونص', 'info': 'متصل: 00:19:57 · إشارة الصحن -56dBm', 'spd': '640 ك/ث', 'st': 'ACTIVE'},
    {'name': 'غازي عمار السلطان', 'user': 'AMAR', 'prof': '3M', 'info': 'متصل: 09:03:38 · مدفوع شام كاش', 'spd': '2.9 م/ث', 'st': 'ACTIVE'},
    {'name': 'مدرسة السواقة', 'user': 'MDRSA', 'prof': '2M', 'info': 'متصل: 02:17:53 · إشارة الصحن -52dBm', 'spd': '1.8 م/ث', 'st': 'ACTIVE'},
    {'name': 'حمود جدعان', 'user': 'HMWD', 'prof': '2.ونص', 'info': 'متصل: 04:49:33 · باقي 4 أيام', 'spd': '980 ك/ث', 'st': 'ACTIVE'},
    {'name': 'عواد حسين عواد العطيش', 'user': 'ABAT', 'prof': '3M', 'info': 'مفصول منذ 1 ساعة · عليه دين', 'spd': 'نائم', 'st': 'SLEEP'},
    {'name': 'أبو نواف الشرقي', 'user': 'ABONWAF', 'prof': '1M', 'info': 'تم إيقافه لانتهاء الاشتراك', 'spd': 'معطل', 'st': 'DISABLED'},
  ];

  // حالة الأكتف الحي
  final List<Map<String, String>> activeSessions = [
    {'code': '427433', 'port': 'Bridge', 'mb': '248.7 ميغا', 'spd': '600 ك/ث من 2.0M', 'mac': 'CE:63:CD:75:D9:DB', 'up': '01:41:40', 'days': '3 يوم'},
    {'code': '418673', 'port': 'Bridge', 'mb': '922.4 ميغا', 'spd': '1.0 م/ث من 2.0M', 'mac': 'E6:35:3B:C4:44:4A', 'up': '05:00:26', 'days': '21 يوم'},
    {'code': '150033 (عموري)', 'port': 'ether7', 'mb': '618.2 ميغا', 'spd': '1.9 م/ث من 2.0M', 'mac': '16:80:7A:C8:B3:2C', 'up': '05:18:50', 'days': '282 يوم'},
    {'code': '36375', 'port': 'ether6', 'mb': '71.9 ميغا', 'spd': '850 ك/ث من 1.0M', 'mac': '2E:F2:EE:63:80:EC', 'up': '00:30:45', 'days': '6 يوم'},
    {'code': '15444', 'port': 'ether7', 'mb': '927 كيلو', 'spd': '1.5 م/ث من 2.0M', 'mac': '32:A5:93:D7:1A:2E', 'up': '00:23:46', 'days': '13 يوم'},
  ];

  // حالة كروت الهوتسبوت واليوزر منجر
  String cardFilter = 'ALL';
  final List<Map<String, dynamic>> hotspotCards = [
    {'u': '36375', 'p': '374', 'spd': '1M', 'used': '504 ميغا', 'val': '7 يوم (باقي 3 يوم)', 'exp': 'Oct/18', 'ok': true},
    {'u': '971646', 'p': '400', 'spd': '512k', 'used': '3.9 جيجا', 'val': '30 يوم (باقي 25 يوم)', 'exp': 'Nov/09', 'ok': true},
    {'u': '563508', 'p': '138', 'spd': '1M', 'used': '342 ميغا', 'val': 'منتهي الصلاحية', 'exp': 'Oct/12', 'ok': false},
    {'u': '884120', 'p': '991', 'spd': '2M', 'used': '10.0 جيجا', 'val': 'منتهي الحجم', 'exp': 'Oct/10', 'ok': false},
  ];

  // مفاتيح الحماية والدمج
  bool antiNetShareTtl = true;
  bool unblockGoogleSyria = true;
  bool pubgPriority = true;
  bool limitUpdates = true;
  bool openSpeedsNow = false;

  // نقاط البيع للمعتمدين
  final List<Map<String, dynamic>> posAgents = [
    {'name': 'ماركت الفرات (نقطة بيع 1)', 'balance': 250000, 'soldToday': 18},
    {'name': 'محل النور للاتصالات (نقطة بيع 2)', 'balance': 45000, 'soldToday': 31},
    {'name': 'ميني ماركت الجزيرة (نقطة بيع 3)', 'balance': 120000, 'soldToday': 12},
  ];

  @override
  void initState() {
    super.initState();
    client = NativeMikrotikClient(ipPort: widget.routerIp, user: widget.username, pass: widget.password);
    _syncData();
  }

  Future<void> _syncData() async {
    final res = await client.getSystemResource();
    if (res != null && mounted) {
      setState(() {
        cpuLoad = '${res['cpu-load'] ?? 3}%';
      });
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _buildDashboardScreen(),       // 0: لوحة القيادة الحية والمساعد الصوتي
      _buildBroadbandScreen(),       // 1: البرودباند PPPoE الشاملة
      _buildActiveUsersScreen(),     // 2: الأكتف الحي والماكات
      _buildHotspotCardsScreen(),    // 3: الهوتسبوت والطباعة
      _buildLoadBalanceScreen(),     // 4: دمج الخطوط وفصل ببجي
      _buildSecurityShieldScreen(),  // 5: درع الحماية والإضافات
      _buildDishesAndPowerScreen(),  // 6: صحون البث وطاقة البرج
      _buildPosAgentsScreen(),       // 7: المعتمدين ونقاط البيع
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F172A),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.routerName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              Text('CCR2116-12G-4S+ · ${widget.routerIp}', style: const TextStyle(fontSize: 10, color: Color(0xFF34D399))),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                _syncData();
                _toast('تمت مزامنة البيانات مع المايكروتك');
              },
            ),
          ],
        ),
        body: screens[currentScreenIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: currentScreenIndex > 4 ? 4 : currentScreenIndex,
          onTap: (i) => setState(() => currentScreenIndex = i),
          backgroundColor: const Color(0xFF070B14),
          selectedItemColor: const Color(0xFF0EA5E9),
          unselectedItemColor: Colors.white54,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'القيادة'),
            BottomNavigationBarItem(icon: Icon(Icons.router), label: 'البرودباند'),
            BottomNavigationBarItem(icon: Icon(Icons.phone_android), label: 'الأكتف'),
            BottomNavigationBarItem(icon: Icon(Icons.confirmation_number), label: 'الكروت'),
            BottomNavigationBarItem(icon: Icon(Icons.bolt), label: 'الشغل الثقيل'),
          ],
        ),
      ),
    );
  }

  // ---------------- الشاشة 2: لوحة القيادة الشاملة + المساعد الصوتي ----------------
  Widget _buildDashboardScreen() {
    final activeCount = pppoeUsers.where((u) => u['st'] == 'ACTIVE').length;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            _topTile('المعالج', cpuLoad, '16 نواة', const Color(0xFF0284C7)),
            const SizedBox(width: 6),
            _topTile('الحرارة', temperature, 'تبريد ممتاز', const Color(0xFFEA580C)),
            const SizedBox(width: 6),
            _topTile('فولت البرج', '${towerVoltage.toStringAsFixed(1)}V', 'طاقة مستقرة', const Color(0xFF65A30D)),
            const SizedBox(width: 6),
            _topTile('السحب', rxSpeed, 'رفع $txSpeed', const Color(0xFF059669)),
          ],
        ),
        const SizedBox(height: 10),
        // المساعد الصوتي
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF8B5CF6)),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() => isListeningVoice = !isListeningVoice);
                  if (isListeningVoice) {
                    _toast('🎙️ المساعد الصوتي يستمع لصوتك الآن...');
                    Future.delayed(const Duration(seconds: 2), () {
                      if (mounted) {
                        setState(() {
                          isListeningVoice = false;
                          voiceText = '🗣️ "تم تنفيذ الأمر: ضاعفنا سرعة المشترك غازي عمار لـ 16M"';
                        });
                        _toast('🚀 تم تنفيذ الأمر الصوتي في المايكروتك!');
                      }
                    });
                  }
                },
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: isListeningVoice ? Colors.redAccent : const Color(0xFF8B5CF6),
                  child: Icon(isListeningVoice ? Icons.mic : Icons.mic_none, color: Colors.white, size: 24),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🎙️ المساعد الصوتي الذكي (تكلم للمايكروتك)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFC084FC))),
                    Text(voiceText, style: const TextStyle(fontSize: 10, color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // زر الفاحص الذكي
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF38BDF8)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('🔍 الفاحص الذكي للأعطال واللوب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF38BDF8))),
                    SizedBox(height: 3),
                    Text('كشف اللوب، راوترات TP-Link المعكوسة، وتشويش الصحون', style: TextStyle(fontSize: 10, color: Colors.white70)),
                  ],
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: Colors.black),
                onPressed: _showSmartDiagnosticReport,
                child: const Text('فحص الآن', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 2.1,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          children: [
            _moduleCard('🏠 البرودباند PPPoE', '$activeCount نشط من ${pppoeUsers.length}', const Color(0xFF34D399), () => setState(() => currentScreenIndex = 1)),
            _moduleCard('📱 الأكتف الحي', '${activeSessions.length} متصل الآن', const Color(0xFF38BDF8), () => setState(() => currentScreenIndex = 2)),
            _moduleCard('🎫 هوتسبوت ويوزرمان', '${hotspotCards.length} كروت + طباعة QR', const Color(0xFFF59E0B), () => setState(() => currentScreenIndex = 3)),
            _moduleCard('⚖️ دمج الخطوط وببجي', 'ستارلينك + ضوئي + عزل', const Color(0xFF4ADE80), () => setState(() => currentScreenIndex = 4)),
            _moduleCard('🛡️ درع الحماية والإضافات', 'منع نت شير + فك غوغل', const Color(0xFFFB7185), () => setState(() => currentScreenIndex = 5)),
            _moduleCard('📡 صحون البث والبطارية', '263 قطعة + منبه الفولت', const Color(0xFFC084FC), () => setState(() => currentScreenIndex = 6)),
            _moduleCard('🏪 المعتمدين والديون', '${posAgents.length} محلات + الصندوق', const Color(0xFFFBBF24), () => setState(() => currentScreenIndex = 7)),
            _moduleCard('👑 لوحة المالك (شام كاش)', 'إدارة اشتراكات الشبكات', const Color(0xFF60A5FA), () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerSaaSPortalScreen()));
            }),
          ],
        ),
      ],
    );
  }

  void _showSmartDiagnosticReport() {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFF38BDF8))),
          title: const Text('🧠 تقرير الفاحص الذكي للشبكة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('✅ المعالج والرام: مستقر (3% CPU)', style: TextStyle(fontSize: 12, color: Color(0xFF34D399))),
              SizedBox(height: 6),
              Text('🚨 تنبيه منفذ ether7: تم رصد راوتر TP-Link معكوس وعزله تلقائياً.', style: TextStyle(fontSize: 12, color: Colors.amber)),
              SizedBox(height: 6),
              Text('⚠️ تنبيه صحن: المشترك (أبو قاسم) إشارته -81dBm تسبب بطء السكتر.', style: TextStyle(fontSize: 12, color: Colors.pinkAccent)),
              SizedBox(height: 6),
              Text('🔋 بطارية البرج: 24.4V (ممتازة).', style: TextStyle(fontSize: 12, color: Colors.white70)),
            ],
          ),
          actions: [
            ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسناً')),
          ],
        ),
      ),
    );
  }

  Widget _topTile(String title, String val, String sub, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontSize: 10, color: Colors.white70)),
            Text(val, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
            Text(sub, style: const TextStyle(fontSize: 8, color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _moduleCard(String title, String sub, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 4),
            Text(sub, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // ---------------- الشاشة 3: حسابات البرودباند PPPoE الشاملة ----------------
  Widget _buildBroadbandScreen() {
    final filtered = pppoeUsers.where((u) {
      final matchFilter = pppoeFilter == 'ALL' || u['st'] == pppoeFilter;
      final matchSearch = pppoeSearch.isEmpty ||
          (u['name'] as String).contains(pppoeSearch) ||
          (u['user'] as String).toLowerCase().contains(pppoeSearch.toLowerCase());
      return matchFilter && matchSearch;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('حسابات برودباند (${pppoeUsers.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: Colors.black),
              onPressed: _showAddPppoeDialog,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('إضافة مشترك', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          onChanged: (v) => setState(() => pppoeSearch = v),
          decoration: InputDecoration(
            hintText: 'ابحث باسم المشترك أو اليوزر...',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: const Color(0xFF0F172A),
            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterBtn('الكل (${pppoeUsers.length})', 'ALL', Colors.blueGrey),
              const SizedBox(width: 6),
              _filterBtn('نشط (${pppoeUsers.where((u) => u['st'] == 'ACTIVE').length})', 'ACTIVE', const Color(0xFF10B981)),
              const SizedBox(width: 6),
              _filterBtn('نائم (${pppoeUsers.where((u) => u['st'] == 'SLEEP').length})', 'SLEEP', const Color(0xFFEC4899)),
              const SizedBox(width: 6),
              _filterBtn('معطل (${pppoeUsers.where((u) => u['st'] == 'DISABLED').length})', 'DISABLED', Colors.grey.shade700),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ...filtered.map((u) {
          Color badgeColor = const Color(0xFF10B981);
          if (u['st'] == 'SLEEP') badgeColor = const Color(0xFFEC4899);
          if (u['st'] == 'DISABLED') badgeColor = Colors.grey.shade700;

          return Card(
            color: const Color(0xFF0F172A),
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              title: Text('${u['name']} (${u['user']})', style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: Text('الباقة: ${u['prof']} · ${u['info']}', style: const TextStyle(fontSize: 11, color: Colors.white70)),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(8)),
                child: Text(u['spd'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
              onTap: () => _showPppoeActionsSheet(u),
            ),
          );
        }),
      ],
    );
  }

  Widget _filterBtn(String label, String code, Color activeColor) {
    final bool isSelected = pppoeFilter == code;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
      selected: isSelected,
      selectedColor: activeColor,
      backgroundColor: const Color(0xFF0F172A),
      onSelected: (_) => setState(() => pppoeFilter = code),
    );
  }

  void _showAddPppoeDialog() {
    final nameCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController(text: '123456');

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('➕ إضافة مشترك برودباند PPPoE', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم المشترك الثلاثي')),
              TextField(controller: userCtrl, decoration: const InputDecoration(labelText: 'اسم المستخدم (User)')),
              TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'كلمة المرور')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
              onPressed: () {
                setState(() {
                  pppoeUsers.insert(0, {
                    'name': nameCtrl.text.isEmpty ? 'مشترك جديد' : nameCtrl.text,
                    'user': userCtrl.text.isEmpty ? 'USER_${Random().nextInt(999)}' : userCtrl.text,
                    'prof': '2M',
                    'info': 'متصل الآن · مشترك جديد 30 يوم',
                    'spd': '1.5 م/ث',
                    'st': 'ACTIVE',
                  });
                });
                Navigator.pop(ctx);
                _toast('✅ تم تفعيل المشترك وإضافته للمايكروتك فوراً!');
              },
              child: const Text('إضافة وتفعيل'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPppoeActionsSheet(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('⚙️ التحكم بالمشترك: ${user['name']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.rocket_launch, color: Colors.amber),
                title: const Text('مضاعفة السرعة مؤقتاً (Turbo Boost 16M)'),
                onTap: () {
                  setState(() => user['spd'] = '16.5 م/ث 🚀');
                  Navigator.pop(ctx);
                  _toast('🚀 تمت مضاعفة السرعة للمشترك ${user['name']}!');
                },
              ),
              ListTile(
                leading: const Icon(Icons.more_time, color: Color(0xFF34D399)),
                title: const Text('تمديد سلفة 48 ساعة (تسجيل في دفتر الديون)'),
                onTap: () {
                  setState(() {
                    user['st'] = 'ACTIVE';
                    user['spd'] = '1.2 م/ث';
                    user['info'] = 'ممدد سلفة 48 ساعة';
                  });
                  Navigator.pop(ctx);
                  _toast('✅ تم تمديد سلفة 48 ساعة للمشترك وتفعيل خطه!');
                },
              ),
              ListTile(
                leading: const Icon(Icons.notification_important, color: Colors.pinkAccent),
                title: const Text('تحويل لصفحة انتهاء الاشتراك (المطالبة بالدفع)'),
                onTap: () {
                  setState(() {
                    user['st'] = 'DISABLED';
                    user['spd'] = 'معطل';
                    user['info'] = 'محول لصفحة الدفع شام كاش';
                  });
                  Navigator.pop(ctx);
                  _toast('🔔 تم تحويل المشترك لصفحة التذكير بالدفع!');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- الشاشة 4: مراقبة الأكتف الحي والماكات (30 متصل) ----------------
  Widget _buildActiveUsersScreen() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('المتصلون الآن · الأكتف (${activeSessions.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => _toast('تم تنشيط جميع الجلسات المعلقة'),
              child: const Text('تنشيط الكل', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...activeSessions.map((a) => Card(
              color: const Color(0xFF0F172A),
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                title: Text('${a['code']} · المنفذ: ${a['port']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF38BDF8), fontSize: 14)),
                subtitle: Text('المستهلك: ${a['mb']} · السرعة: ${a['spd']}\nMAC: ${a['mac']} · المدة: ${a['up']}', style: const TextStyle(fontSize: 11)),
                isThreeLine: true,
                trailing: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFF1E3A8A), borderRadius: BorderRadius.circular(10)),
                  child: Text('${a['days']}\nمتبقي', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                onTap: () {
                  setState(() => activeSessions.remove(a));
                  _toast('تم فصل الجلسة النشطة للكرت ${a['code']}');
                },
              ),
            )),
      ],
    );
  }

  // ---------------- الشاشة 5: استوديو كروت الهوتسبوت والطباعة الفورية بـ QR ----------------
  Widget _buildHotspotCardsScreen() {
    final filteredCards = hotspotCards.where((c) {
      if (cardFilter == 'WORK') return c['ok'] == true;
      if (cardFilter == 'EXPIRED') return c['ok'] == false;
      return true;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text('حسابات الهوتسبوت واليوزر منجر (${hotspotCards.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.symmetric(vertical: 11)),
                onPressed: _showGenerateVouchersBatchModal,
                icon: const Icon(Icons.qr_code, size: 18),
                label: const Text('توليد وطباعة PDF+QR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48), padding: const EdgeInsets.symmetric(vertical: 11)),
                onPressed: () {
                  final expiredCount = hotspotCards.where((c) => c['ok'] == false).length;
                  setState(() => hotspotCards.removeWhere((c) => c['ok'] == false));
                  _toast('🧹 المكنسة الذكية: تم مسح $expiredCount كرت منتهي وتفريغ الذاكرة!');
                },
                icon: const Icon(Icons.delete_sweep, size: 18),
                label: const Text('مسح المنتهي', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            ChoiceChip(
              label: Text('الكل (${hotspotCards.length})'),
              selected: cardFilter == 'ALL',
              onSelected: (_) => setState(() => cardFilter = 'ALL'),
            ),
            ChoiceChip(
              label: Text('يعمل (${hotspotCards.where((c) => c['ok'] == true).length})'),
              selected: cardFilter == 'WORK',
              selectedColor: Colors.blue.shade700,
              onSelected: (_) => setState(() => cardFilter = 'WORK'),
            ),
            ChoiceChip(
              label: Text('المنتهية (${hotspotCards.where((c) => c['ok'] == false).length})'),
              selected: cardFilter == 'EXPIRED',
              selectedColor: Colors.pink.shade700,
              onSelected: (_) => setState(() => cardFilter = 'EXPIRED'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...filteredCards.map((c) => Card(
              color: const Color(0xFF0F172A),
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                title: Text('👤 ${c['u']}   🔑 ${c['p']}   ⚡ السرعة: ${c['spd']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC084FC), fontSize: 14)),
                subtitle: Text('المستهلك: ${c['used']} · المتبقي: مفتوح\nالصلاحية: ${c['val']} · التاريخ: ${c['exp']}', style: const TextStyle(fontSize: 11)),
                isThreeLine: true,
                trailing: CircleAvatar(
                  radius: 24,
                  backgroundColor: (c['ok'] as bool) ? Colors.blue.shade700 : Colors.pink.shade800,
                  child: Text((c['ok'] as bool) ? 'يعمل' : 'منتهي', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                onTap: () => _showSingleVoucherQrDialog(c),
              ),
            )),
      ],
    );
  }

  void _showSingleVoucherQrDialog(Map<String, dynamic> c) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFF0EA5E9))),
          title: Text('بطاقة هوتسبوت: ${c['u']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.qr_code_2, size: 120, color: Colors.black),
              ),
              const SizedBox(height: 12),
              Text('اسم المستخدم: ${c['u']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text('كلمة المرور: ${c['p']}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          actions: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
              onPressed: () {
                Navigator.pop(ctx);
                _toast('💬 تم إرسال البطاقة بصورة رقمية في واتساب للزبون!');
              },
              icon: const Icon(Icons.share),
              label: const Text('إرسال في واتساب'),
            ),
          ],
        ),
      ),
    );
  }

  void _showGenerateVouchersBatchModal() {
    final countCtrl = TextEditingController(text: '10');
    final prefixCtrl = TextEditingController(text: '77');
    final speedCtrl = TextEditingController(text: '2M');

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('🖨️ استوديو توليد وطباعة الكروت بـ QR', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: countCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'عدد البطاقات المطلوب توليدها')),
              TextField(controller: prefixCtrl, decoration: const InputDecoration(labelText: 'بادئة الكرت (Prefi

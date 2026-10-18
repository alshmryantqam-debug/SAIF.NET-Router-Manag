import 'package:flutter/material.dart';

class AiVoiceAssistantScreen extends StatefulWidget {
  const AiVoiceAssistantScreen({super.key});

  @override
  State<AiVoiceAssistantScreen> createState() => _AiVoiceAssistantScreenState();
}

class _AiVoiceAssistantScreenState extends State<AiVoiceAssistantScreen> {
  bool isListening = false;
  String voiceText = 'اضغط على المايكروفون وتكلم بأي أمر للمايكروتك...';
  String resultAction = '';

  final List<String> voiceSuggestions = [
    '🗣️ "افصل المشترك رمضان حميد"',
    '🗣️ "ضاعف سرعة مدرسة السواقة"',
    '🗣️ "اطبع 10 كروت هوتسبوت 2 ميغا"',
    '🗣️ "كم مشترك نائم في البرودباند؟"',
    '🗣️ "افحص اللوب وراوترات TP-Link"',
  ];

  void _simulateVoiceCommand(String cmd) {
    setState(() {
      isListening = false;
      voiceText = cmd;
    });

    if (cmd.contains('افصل المشترك')) {
      setState(() => resultAction = '✅ تم تنفيذ الأمر: تم فصل جلسة المشترك وإعادة تنشيط خطه بنجاح.');
    } else if (cmd.contains('ضاعف سرعة')) {
      setState(() => resultAction = '🚀 تم تنفيذ الأمر: تم تفعيل السرعة المضاعفة Turbo (16 Mbps) لمدة ساعتين.');
    } else if (cmd.contains('اطبع')) {
      setState(() => resultAction = '🖨️ تم تنفيذ الأمر: تم توليد 10 بطاقات هوتسبوت مع باركود QR وجاهزة للطباعة PDF.');
    } else if (cmd.contains('كم مشترك')) {
      setState(() => resultAction = '📊 تقرير فوري: يوجد 195 مشتركاً نشطاً، 62 نائماً، و 30 في الأكتف.');
    } else {
      setState(() => resultAction = '🛡️ الفاحص الذكي: الشبكة مستقرة 100% ولا يوجد أي لوب أو تشويش.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF080D1A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF111A2E),
          title: const Text('🎙️ المساعد الصوتي والذكاء الاصطناعي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // بطاقة التحدث والتسجيل
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)]),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF38BDF8)),
              ),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        isListening = !isListening;
                        if (isListening) {
                          voiceText = 'جاري الاستماع لصوتك الآن...';
                          resultAction = '';
                        }
                      });
                      if (isListening) {
                        Future.delayed(const Duration(seconds: 3), () {
                          if (mounted) _simulateVoiceCommand('🗣️ "ضاعف سرعة مدرسة السواقة"');
                        });
                      }
                    },
                    child: CircleAvatar(
                      radius: 45,
                      backgroundColor: isListening ? Colors.redAccent : const Color(0xFF0EA5E9),
                      child: Icon(
                        isListening ? Icons.mic : Icons.mic_none,
                        size: 45,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    isListening ? 'تكلم الآن، أستمع إليك...' : 'اضغط على المايكروفون للأوامر الصوتية',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.amber),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    voiceText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                ],
              ),
            ),

            if (resultAction.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF064E3B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF10B981)),
                ),
                child: Text(
                  resultAction,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                ),
              ),
            ],

            const SizedBox(height: 20),
            const Text('💡 أمثلة لأوامر صوتية يمكنك قولها للراوتر:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF38BDF8))),
            const SizedBox(height: 8),
            ...voiceSuggestions.map((s) => Card(
                  color: const Color(0xFF131C31),
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    title: Text(s, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.play_circle_fill, color: Color(0xFF38BDF8), size: 22),
                    onTap: () => _simulateVoiceCommand(s),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

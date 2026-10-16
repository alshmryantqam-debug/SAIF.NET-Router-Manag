import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tikplus_ultra/app.dart';

void main() {
  testWidgets('app starts and reaches the Arabic login screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TikPlusApp()));

    // First frame must render the splash screen without a framework exception.
    expect(find.text('TikPlus ULTRA'), findsOneWidget);

    // The splash screen navigates to login after 2.5 seconds.
    await tester.pump(const Duration(milliseconds: 2600));
    await tester.pump();

    expect(find.text('المنصة الاحترافية لإدارة MikroTik'), findsOneWidget);
    expect(find.text('اختبار الاتصال والدخول'), findsOneWidget);
  });
}

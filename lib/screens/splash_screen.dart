import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/connection_provider.dart';

const _ink = Color(0xFF080D17);
const _cyan = Color(0xFF73E5F2);
const _muted = Color(0xFF9AA9BA);

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: .94, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
    _continue();
  }

  Future<void> _continue() async {
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    context.go(ref.read(connectedProvider) ? '/dashboard' : '/login');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _ink,
        body: Stack(
          children: [
            const Positioned(top: -120, right: -90, child: _SoftGlow(size: 300, color: Color(0x223BC9E0))),
            const Positioned(bottom: -160, left: -100, child: _SoftGlow(size: 320, color: Color(0x1B8A70E8))),
            Center(
              child: FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: const Color(0xFF111C2A),
                          borderRadius: BorderRadius.circular(27),
                          border: Border.all(color: _cyan.withOpacity(.32)),
                          boxShadow: [
                            BoxShadow(color: _cyan.withOpacity(.10), blurRadius: 36, spreadRadius: 2),
                          ],
                        ),
                        child: const Icon(Icons.hub_rounded, color: _cyan, size: 42),
                      ),
                      const SizedBox(height: 26),
                      const Text(
                        'نـوڨـا',
                        style: TextStyle(color: Colors.white, fontSize: 39, fontWeight: FontWeight.w800, height: 1.1),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'مركز إدارة الشبكات',
                        style: TextStyle(color: _muted, fontSize: 14, letterSpacing: .2),
                      ),
                      const SizedBox(height: 42),
                      SizedBox(
                        width: 110,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: const LinearProgressIndicator(
                            minHeight: 2,
                            backgroundColor: Color(0xFF1B2938),
                            valueColor: AlwaysStoppedAnimation<Color>(_cyan),
                          ),
                        ),
                      ),
                      const SizedBox(height: 13),
                      const Text('جارٍ تجهيز النظام', style: TextStyle(color: _muted, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 28,
              left: 0,
              right: 0,
              child: Text(
                'إدارة دقيقة • اتصال موثوق',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted.withOpacity(.65), fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoftGlow extends StatelessWidget {
  const _SoftGlow({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 65, sigmaY: 65),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
        ),
      );
}

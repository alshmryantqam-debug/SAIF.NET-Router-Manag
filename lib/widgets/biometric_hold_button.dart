import 'package:flutter/material.dart';

/// Two-second press-and-hold confirmation control. It is not a real biometric
/// authentication mechanism; callers must still authorize commands server-side.
class BiometricHoldButton extends StatefulWidget {
  const BiometricHoldButton({
    super.key,
    required this.text,
    required this.color,
    required this.onExecute,
    this.enabled = true,
  });

  final String text;
  final Color color;
  final VoidCallback onExecute;
  final bool enabled;

  @override
  State<BiometricHoldButton> createState() => _BiometricHoldButtonState();
}

class _BiometricHoldButtonState extends State<BiometricHoldButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isHolding = false;
  bool _hasExecuted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _controller.addStatusListener(_handleStatus);
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _isHolding && !_hasExecuted) {
      _hasExecuted = true;
      _isHolding = false;
      widget.onExecute();
      if (mounted) setState(() {});
      _controller.reset();
    }
  }

  void _startHold() {
    if (!widget.enabled || _isHolding) return;
    setState(() {
      _isHolding = true;
      _hasExecuted = false;
    });
    _controller.forward(from: 0);
  }

  void _cancelHold() {
    if (!_isHolding) return;
    setState(() => _isHolding = false);
    _controller.reverse();
  }

  @override
  void didUpdateWidget(covariant BiometricHoldButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _isHolding) {
      _isHolding = false;
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_handleStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.text,
      hint: 'اضغط باستمرار لمدة ثانيتين للتأكيد',
      child: GestureDetector(
        onTapDown: widget.enabled ? (_) => _startHold() : null,
        onTapUp: widget.enabled ? (_) => _cancelHold() : null,
        onTapCancel: _cancelHold,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Container(
            height: 80,
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.black54,
              border: Border.all(
                color: widget.color.withOpacity(widget.enabled ? 0.7 : 0.2),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: _isHolding
                  ? [
                      BoxShadow(
                        color: widget.color.withOpacity(0.35),
                        blurRadius: 20,
                      ),
                    ]
                  : const [],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: _controller.value,
                    child: ColoredBox(
                      color: widget.color.withOpacity(0.28),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.fingerprint_rounded,
                      color: _isHolding ? Colors.white : widget.color,
                      size: 35,
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        _isHolding ? 'جارٍ تأكيد الضغط...' : widget.text,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: widget.enabled
                              ? (_isHolding ? Colors.white : widget.color)
                              : Colors.white38,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

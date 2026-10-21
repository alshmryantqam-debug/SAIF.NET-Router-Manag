import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Glass-like Cyber-Core input with a focused neon outline.
class CyberTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool isPassword;
  final TextInputType keyboardType;
  final Color accentColor;
  final bool enabled;
  final String? hint;
  final String? helper;
  final String? Function(String?)? validator;
  final Widget? suffix;
  final List<TextInputFormatter>? inputFormatters;

  const CyberTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.accentColor = const Color(0xFF00E5FF),
    this.enabled = true,
    this.hint,
    this.helper,
    this.validator,
    this.suffix,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: TextFormField(
            controller: controller,
            enabled: enabled,
            validator: validator,
            obscureText: isPassword,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
            cursorColor: accentColor,
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              helperText: helper,
              labelStyle: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontFamily: 'monospace',
                letterSpacing: 1.2,
              ),
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.35),
                fontSize: 12,
              ),
              helperStyle: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 11,
              ),
              prefixIcon: Icon(icon, color: accentColor.withOpacity(0.8)),
              suffixIcon: suffix,
              filled: true,
              fillColor: Colors.black.withOpacity(0.4),
              errorStyle: const TextStyle(
                color: Color(0xFFFF5370),
                fontSize: 11,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                  width: 1.5,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withOpacity(0.06),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: accentColor, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFFFF5370),
                  width: 1.5,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFFFF5370),
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 20,
                horizontal: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

class UltraInput extends StatelessWidget {
  const UltraInput({
    super.key,
    required this.controller,
    required this.label,
    this.icon,
    this.hint,
    this.keyboardType,
    this.obscure = false,
    this.enabled = true,
    this.suffix,
    this.prefix,
    this.validator,
    this.textInputAction,
    this.onSubmitted,
    this.maxLines = 1,
    this.autofocus = false,
    this.formatters,
    this.helper,
  });

  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final String? hint;
  final TextInputType? keyboardType;
  final bool obscure;
  final bool enabled;
  final Widget? suffix;
  final Widget? prefix;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final void Function(String)? onSubmitted;
  final int maxLines;
  final bool autofocus;
  final List<TextInputFormatter>? formatters;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          obscureText: obscure,
          enabled: enabled,
          autofocus: autofocus,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onFieldSubmitted: onSubmitted,
          maxLines: obscure ? 1 : maxLines,
          inputFormatters: formatters,
          validator: validator,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            helperText: helper,
            prefixIcon: icon != null ? Icon(icon, size: 20) : prefix,
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}
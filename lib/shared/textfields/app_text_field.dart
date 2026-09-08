import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';

/// A standardized text field for JonkStore POS.
/// Hardened for production use with support for validation and constraints.
class AppTextField extends StatelessWidget {
  final String? label;
  final String? hintText;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final Widget? prefix;
  final String? prefixText;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final bool readOnly;
  final bool enabled;
  final VoidCallback? onTap;
  final int maxLines;
  final int? maxLength;
  final bool autoFocus;
  final TextCapitalization textCapitalization;

  const AppTextField({
    super.key,
    this.label,
    this.hintText,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
    this.prefix,
    this.prefixText,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.readOnly = false,
    this.enabled = true,
    this.onTap,
    this.maxLines = 1,
    this.maxLength,
    this.autoFocus = false,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: AppTextStyles.subtitle.copyWith(
              fontSize: 14,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.grey300
                  : AppColors.grey700,
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
          readOnly: readOnly,
          enabled: enabled,
          onTap: onTap,
          maxLines: maxLines,
          maxLength: maxLength,
          autofocus: autoFocus,
          textCapitalization: textCapitalization,
          style: AppTextStyles.body,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            prefix: prefix,
            prefixText: prefixText,
            counterText: "", // Hide default counter for a cleaner look
          ),
        ),
      ],
    );
  }
}

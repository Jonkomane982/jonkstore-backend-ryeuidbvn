import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import 'app_text_field.dart';

/// A specialized text field for search functionality.
class SearchTextField extends StatelessWidget {
  final String hintText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;

  const SearchTextField({
    super.key,
    this.hintText = 'Search...',
    this.controller,
    this.onChanged,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      hintText: hintText,
      onChanged: onChanged,
      prefixIcon: const Icon(Icons.search, color: AppColors.grey500),
      suffixIcon: controller != null && controller!.text.isNotEmpty
          ? IconButton(
              icon: const Icon(Icons.clear, color: AppColors.grey500),
              onPressed: () {
                controller?.clear();
                if (onClear != null) onClear!();
              },
            )
          : null,
    );
  }
}

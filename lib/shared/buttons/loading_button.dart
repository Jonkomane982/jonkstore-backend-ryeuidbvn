import 'package:flutter/material.dart';
import 'primary_button.dart';

/// A button that is permanently in a loading state or toggles to one.
///
/// Use this when an action is expected to take time and you want to 
/// prevent further user interaction while providing visual feedback.
class LoadingButton extends StatelessWidget {
  final String text;
  final bool isLoading;
  final VoidCallback? onPressed;

  const LoadingButton({
    super.key,
    required this.text,
    this.isLoading = true,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return PrimaryButton(
      text: text,
      isLoading: isLoading,
      onPressed: onPressed,
    );
  }
}

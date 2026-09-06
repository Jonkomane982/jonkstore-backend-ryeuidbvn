import 'package:flutter/material.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../buttons/primary_button.dart';
import '../buttons/outline_button.dart';

/// A standard confirmation dialog for JonkStore POS.
class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;
  final bool isDanger;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    required this.onConfirm,
    this.onCancel,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.borderRadiusLg),
      title: Text(title, style: AppTextStyles.title),
      content: Text(message, style: AppTextStyles.bodyLarge),
      actionsPadding: const EdgeInsets.all(AppSpacing.md),
      actions: [
        Row(
          children: [
            Expanded(
              child: AppOutlineButton(
                text: cancelLabel,
                onPressed: () {
                  Navigator.of(context).pop();
                  if (onCancel != null) onCancel!();
                },
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: PrimaryButton(
                text: confirmLabel,
                backgroundColor: isDanger ? Theme.of(context).colorScheme.error : null,
                onPressed: () {
                  Navigator.of(context).pop();
                  onConfirm();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Static method to show the dialog easily.
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    required VoidCallback onConfirm,
    VoidCallback? onCancel,
    bool isDanger = false,
  }) {
    return showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        onConfirm: onConfirm,
        onCancel: onCancel,
        isDanger: isDanger,
      ),
    );
  }
}

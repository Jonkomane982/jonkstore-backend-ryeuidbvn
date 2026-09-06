import 'package:flutter/material.dart';
import '../app/theme/app_colors.dart';
import '../app/theme/app_spacing.dart';
import '../app/theme/app_text_styles.dart';
import 'buttons/primary_button.dart';
import 'buttons/secondary_button.dart';
import 'buttons/danger_button.dart';
import 'buttons/outline_button.dart';
import 'buttons/loading_button.dart';
import 'cards/primary_card.dart';
import 'cards/dashboard_card.dart';
import 'cards/stat_card.dart';
import 'cards/notification_card.dart';
import 'textfields/app_text_field.dart';
import 'textfields/search_text_field.dart';
import 'textfields/password_text_field.dart';
import 'dialogs/confirmation_dialog.dart';
import 'loading/loading_indicator.dart';
import 'loading/empty_state.dart';
import 'snackbars/custom_snack_bar.dart';

/// A development-only screen to preview all Design System components.
class DesignSystemPreview extends StatelessWidget {
  const DesignSystemPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('JonkStore Design System'),
        actions: [
          IconButton(
            icon: const Icon(Icons.lightbulb_outline),
            onPressed: () {
              // Toggle theme logic would go here if using a provider
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Section(
              title: 'Typography',
              children: [
                Text('Display Large', style: AppTextStyles.displayLarge),
                Text('Display Medium', style: AppTextStyles.displayMedium),
                Text('Headline', style: AppTextStyles.headline),
                Text('Title', style: AppTextStyles.title),
                Text('Subtitle', style: AppTextStyles.subtitle),
                Text('Body Large', style: AppTextStyles.bodyLarge),
                Text('Body', style: AppTextStyles.body),
                Text('Body Small', style: AppTextStyles.bodySmall),
                Text('Caption', style: AppTextStyles.caption),
              ],
            ),
            _Section(
              title: 'Colors',
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _ColorBox(color: AppColors.primary, name: 'Primary'),
                    _ColorBox(color: AppColors.secondary, name: 'Secondary'),
                    _ColorBox(color: AppColors.success, name: 'Success'),
                    _ColorBox(color: AppColors.warning, name: 'Warning'),
                    _ColorBox(color: AppColors.error, name: 'Error'),
                    _ColorBox(color: AppColors.info, name: 'Info'),
                  ],
                ),
              ],
            ),
            _Section(
              title: 'Buttons',
              children: [
                PrimaryButton(text: 'Primary Button', onPressed: () {}),
                const SizedBox(height: AppSpacing.md),
                SecondaryButton(text: 'Secondary Button', onPressed: () {}),
                const SizedBox(height: AppSpacing.md),
                DangerButton(text: 'Danger Button', onPressed: () {}),
                const SizedBox(height: AppSpacing.md),
                AppOutlineButton(text: 'Outline Button', onPressed: () {}),
                const SizedBox(height: AppSpacing.md),
                const LoadingButton(text: 'Loading...'),
                const SizedBox(height: AppSpacing.md),
                PrimaryButton(
                  text: 'Button with Icon',
                  icon: Icons.add,
                  onPressed: () {},
                ),
              ],
            ),
            _Section(
              title: 'TextFields',
              children: [
                const AppTextField(
                  label: 'Standard Field',
                  hintText: 'Enter some text',
                ),
                const SizedBox(height: AppSpacing.md),
                const SearchTextField(hintText: 'Search products...'),
                const SizedBox(height: AppSpacing.md),
                const PasswordTextField(),
              ],
            ),
            _Section(
              title: 'Cards',
              children: [
                const PrimaryCard(
                  child: Text('This is a primary card with default styling.'),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        title: 'Total Sales',
                        value: '\$12,450',
                        trend: '+12.5%',
                        icon: Icons.attach_money,
                        iconColor: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: StatCard(
                        title: 'Orders',
                        value: '156',
                        trend: '-2.4%',
                        isPositiveTrend: false,
                        icon: Icons.shopping_bag_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                DashboardCard(
                  title: 'Inventory Management',
                  icon: Icons.inventory_2_outlined,
                  iconColor: AppColors.secondary,
                  badgeText: '5 Low Stock',
                  onTap: () {},
                ),
                const SizedBox(height: AppSpacing.md),
                NotificationCard(
                  title: 'New Update Available',
                  message: 'Version 2.0 is now available with new POS features.',
                  icon: Icons.system_update,
                  time: DateTime.now(),
                ),
              ],
            ),
            _Section(
              title: 'Dialogs & Feedback',
              children: [
                PrimaryButton(
                  text: 'Show Confirmation Dialog',
                  onPressed: () => ConfirmationDialog.show(
                    context,
                    title: 'Delete Item?',
                    message: 'Are you sure you want to remove this item from the cart?',
                    isDanger: true,
                    onConfirm: () {},
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    SecondaryButton(
                      text: 'Success Snack',
                      onPressed: () => CustomSnackBar.showSuccess(context, 'Operation successful!'),
                    ),
                    SecondaryButton(
                      text: 'Error Snack',
                      onPressed: () => CustomSnackBar.showError(context, 'Something went wrong.'),
                    ),
                  ],
                ),
              ],
            ),
            _Section(
              title: 'Loading & States',
              children: [
                const AppLoadingIndicator(),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  height: 300,
                  child: EmptyState(
                    title: 'No Products Found',
                    message: 'Try searching for something else or add a new product.',
                    icon: Icons.search_off_rounded,
                    actionLabel: 'Add Product',
                    onActionPressed: () {},
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: AppColors.primary,
                ),
              ),
              const Divider(),
            ],
          ),
        ),
        ...children,
      ],
    );
  }
}

class _ColorBox extends StatelessWidget {
  final Color color;
  final String name;

  const _ColorBox({required this.color, required this.name});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black12),
          ),
        ),
        const SizedBox(height: 4),
        Text(name, style: AppTextStyles.caption),
      ],
    );
  }
}

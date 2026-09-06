import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jonkstore/app/theme/app_colors.dart';
import 'package:jonkstore/app/theme/app_spacing.dart';
import 'package:jonkstore/app/theme/app_text_styles.dart';
import 'package:jonkstore/core/domain/models/settings.dart';
import 'package:jonkstore/features/settings/controllers/settings_controller.dart';
import 'package:jonkstore/features/dashboard/providers/dashboard_providers.dart';
import 'package:jonkstore/shared/loading/loading_indicator.dart';
import 'package:jonkstore/shared/buttons/primary_button.dart';
import 'package:jonkstore/shared/textfields/app_text_field.dart';
import 'package:jonkstore/shared/snackbars/custom_snack_bar.dart';
import 'package:jonkstore/core/auth/session_manager.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers for editable settings
  final _currencyController = TextEditingController();
  final _taxNameController = TextEditingController();
  final _taxRateController = TextEditingController();
  final _receiptFooterController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(settingsControllerProvider.notifier).loadSettings());
  }

  @override
  void dispose() {
    _currencyController.dispose();
    _taxNameController.dispose();
    _taxRateController.dispose();
    _receiptFooterController.dispose();
    super.dispose();
  }

  void _updateControllers(Settings? s) {
    if (s == null) return;
    _currencyController.text = s.currencyCode;
    _taxNameController.text = s.taxName;
    _taxRateController.text = s.taxRate.toString();
    _receiptFooterController.text = s.receiptFooter;
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    final current = ref.read(settingsControllerProvider).settings;
    if (current == null) return;

    final updated = current.copyWith(
      currencyCode: _currencyController.text.trim(),
      taxName: _taxNameController.text.trim(),
      taxRate: double.tryParse(_taxRateController.text) ?? 0,
      receiptFooter: _receiptFooterController.text.trim(),
    );

    await ref.read(settingsControllerProvider.notifier).updateSettings(updated);
    
    if (mounted) {
      CustomSnackBar.showSuccess(context, 'Settings updated successfully');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingsControllerProvider);
    final businessAsync = ref.watch(currentBusinessProvider);

    // Sync controllers with state when data arrives
    ref.listen(settingsControllerProvider, (prev, next) {
      if (prev?.settings == null && next.settings != null) {
        _updateControllers(next.settings);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('System Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.error),
            onPressed: () => ref.read(sessionManagerProvider.notifier).logout(),
          ),
        ],
      ),
      body: state.isLoading && state.settings == null
          ? const Center(child: AppLoadingIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBusinessInfoSection(businessAsync),
                    const SizedBox(height: AppSpacing.xl),
                    
                    Text('Localization & Currency', style: AppTextStyles.subtitle),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Currency Code',
                      hintText: 'e.g. KES, USD',
                      controller: _currencyController,
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    Text('Taxation', style: AppTextStyles.subtitle),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: 'Tax Name',
                            hintText: 'e.g. VAT',
                            controller: _taxNameController,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: AppTextField(
                            label: 'Tax Rate (%)',
                            hintText: '0.00',
                            controller: _taxRateController,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    Text('Receipt Configuration', style: AppTextStyles.subtitle),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Receipt Footer Message',
                      hintText: 'Displayed at the bottom of printed receipts',
                      controller: _receiptFooterController,
                      maxLines: 2,
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    PrimaryButton(
                      text: 'Save All Changes',
                      isLoading: state.isLoading,
                      onPressed: _saveSettings,
                    ),
                    const SizedBox(height: AppSpacing.xxxl),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBusinessInfoSection(AsyncValue businessAsync) {
    return businessAsync.when(
      data: (business) => Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: Icon(Icons.storefront, color: Colors.white),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(business?.name ?? 'No Business', style: AppTextStyles.subtitle),
                        Text(business?.email ?? 'No email set', style: AppTextStyles.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              _InfoTile(label: 'Business Type', value: business?.businessType ?? 'N/A'),
              _InfoTile(label: 'Country', value: business?.country ?? 'N/A'),
              _InfoTile(label: 'Timezone', value: business?.timezone ?? 'N/A'),
            ],
          ),
        ),
      ),
      loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
      error: (_, _) => const Text('Error loading business info'),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.grey500)),
          Text(value, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

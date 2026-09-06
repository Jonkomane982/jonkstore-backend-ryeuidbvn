import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/validators/app_validators.dart';
import '../../../shared/buttons/primary_button.dart';
import '../../../shared/textfields/app_text_field.dart';
import '../../../shared/snackbars/custom_snack_bar.dart';
import '../controllers/business_setup_controller.dart';

class BusinessSetupScreen extends ConsumerStatefulWidget {
  const BusinessSetupScreen({super.key});

  @override
  ConsumerState<BusinessSetupScreen> createState() => _BusinessSetupScreenState();
}

class _BusinessSetupScreenState extends ConsumerState<BusinessSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _countryController = TextEditingController(text: 'Kenya');
  final _currencyController = TextEditingController(text: 'KES');
  final _businessTypeController = TextEditingController();
  final _timezoneController = TextEditingController(text: 'Africa/Nairobi');
  final _receiptFooterController = TextEditingController(text: 'Thank you for shopping with us!');

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _countryController.dispose();
    _currencyController.dispose();
    _businessTypeController.dispose();
    _timezoneController.dispose();
    _receiptFooterController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      ref.read(businessSetupControllerProvider.notifier).createBusiness(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            phone: _phoneController.text.trim(),
            address: _addressController.text.trim(),
            country: _countryController.text.trim(),
            currency: _currencyController.text.trim(),
            businessType: _businessTypeController.text.trim(),
            timezone: _timezoneController.text.trim(),
            receiptFooter: _receiptFooterController.text.trim(),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(businessSetupControllerProvider);

    ref.listen(businessSetupControllerProvider, (previous, next) {
      if (next.isSuccess) {
        CustomSnackBar.showSuccess(context, 'Business setup successfully!');
        context.goNamed(RouteNames.dashboard);
      }
      if (next.errorMessage != null) {
        CustomSnackBar.showError(context, next.errorMessage!);
      }
    });

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  'Setup Your Business',
                  style: AppTextStyles.headline,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Enter your business details to get started with JonkStore POS.',
                  style: AppTextStyles.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.xxl),
                
                // Business Name
                AppTextField(
                  label: 'Business Name *',
                  hintText: 'e.g. Jonk General Store',
                  controller: _nameController,
                  validator: (value) => AppValidators.required(value, 'Business Name'),
                ),
                const SizedBox(height: AppSpacing.md),

                // Business Type
                AppTextField(
                  label: 'Business Type',
                  hintText: 'e.g. Retail, Restaurant',
                  controller: _businessTypeController,
                ),
                const SizedBox(height: AppSpacing.md),

                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: 'Email',
                        hintText: 'business@example.com',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) => value != null && value.isNotEmpty ? AppValidators.email(value) : null,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppTextField(
                        label: 'Phone',
                        hintText: '+254...',
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                AppTextField(
                  label: 'Address',
                  hintText: 'Physical address',
                  controller: _addressController,
                  maxLines: 2,
                ),
                const SizedBox(height: AppSpacing.md),

                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: 'Country',
                        controller: _countryController,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppTextField(
                        label: 'Currency',
                        controller: _currencyController,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                AppTextField(
                  label: 'Receipt Footer',
                  hintText: 'Message at bottom of receipts',
                  controller: _receiptFooterController,
                ),
                const SizedBox(height: AppSpacing.xxl),

                PrimaryButton(
                  text: 'Create Business',
                  isLoading: state.isLoading,
                  onPressed: _submit,
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

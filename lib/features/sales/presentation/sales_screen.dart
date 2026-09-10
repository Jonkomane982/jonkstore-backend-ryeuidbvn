import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jonkstore/app/theme/app_colors.dart';
import 'package:jonkstore/app/theme/app_spacing.dart';
import 'package:jonkstore/app/theme/app_text_styles.dart';
import 'package:jonkstore/core/domain/models/product.dart';
import 'package:jonkstore/core/domain/enums/payment_method.dart';
import 'package:jonkstore/features/sales/controllers/sales_controller.dart';
import 'package:jonkstore/features/products/controllers/product_controller.dart';
import 'package:jonkstore/shared/buttons/primary_button.dart';
import 'package:jonkstore/shared/textfields/search_text_field.dart';
import 'package:jonkstore/shared/loading/loading_indicator.dart';
import 'package:jonkstore/shared/loading/empty_state.dart';
import 'package:jonkstore/shared/snackbars/custom_snack_bar.dart';

class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(productControllerProvider.notifier).loadProducts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onCheckout() {
    final state = ref.read(salesControllerProvider);
    if (state.cart.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CheckoutBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productState = ref.watch(productControllerProvider);
    final salesState = ref.watch(salesControllerProvider);

    ref.listen(salesControllerProvider, (previous, next) {
      if (next.isSuccess) {
        CustomSnackBar.showSuccess(context, 'Sale completed successfully');
        ref.read(salesControllerProvider.notifier).reset();
      }
      if (next.errorMessage != null) {
        CustomSnackBar.showError(context, next.errorMessage!);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Point of Sale'),
        actions: [
          IconButton(
            onPressed: () => ref.read(salesControllerProvider.notifier).reset(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset Cart',
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 900) {
            return Row(
              children: [
                Expanded(flex: 2, child: _buildProductSection(productState)),
                const VerticalDivider(width: 1),
                SizedBox(width: 400, child: _buildCartSection(salesState)),
              ],
            );
          }
          return Column(
            children: [
              Expanded(child: _buildProductSection(productState)),
              _buildMobileCartSummary(salesState),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProductSection(ProductState state) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: SearchTextField(
            controller: _searchController,
            hintText: 'Search products by name or SKU...',
            onChanged: (val) => ref.read(productControllerProvider.notifier).searchProducts(val),
          ),
        ),
        Expanded(
          child: state.isLoading
              ? const Center(child: AppLoadingIndicator())
              : state.filteredProducts.isEmpty
                  ? const EmptyState(
                      title: 'No Products',
                      message: 'Add products to inventory to start selling.',
                      icon: Icons.inventory_2_outlined,
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 180,
                        mainAxisSpacing: AppSpacing.md,
                        crossAxisSpacing: AppSpacing.md,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: state.filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = state.filteredProducts[index];
                        return _ProductGridTile(product: product);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildCartSection(SalesState state) {
    return Column(
      children: [
        Expanded(
          child: state.cart.isEmpty
              ? const EmptyState(
                  title: 'Empty Cart',
                  message: 'Select products to start a sale.',
                  icon: Icons.shopping_cart_outlined,
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: state.cart.length,
                  itemBuilder: (context, index) {
                    final item = state.cart[index];
                    return _CartItemTile(item: item);
                  },
                ),
        ),
        _buildTotalsSection(state),
      ],
    );
  }

  Widget _buildTotalsSection(SalesState state) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Subtotal', style: AppTextStyles.body),
              Text('KES ${state.subtotal.toStringAsFixed(2)}', style: AppTextStyles.subtitle),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: AppTextStyles.title),
              Text(
                'KES ${state.total.toStringAsFixed(2)}',
                style: AppTextStyles.title.copyWith(color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            text: 'Checkout',
            onPressed: state.cart.isEmpty ? null : _onCheckout,
          ),
        ],
      ),
    );
  }

  Widget _buildMobileCartSummary(SalesState state) {
    if (state.cart.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primary,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${state.cart.length} Items',
                  style: AppTextStyles.caption.copyWith(color: Colors.white70),
                ),
                Text(
                  'KES ${state.total.toStringAsFixed(2)}',
                  style: AppTextStyles.title.copyWith(color: Colors.white),
                ),
              ],
            ),
            const Spacer(),
            TextButton(
              onPressed: _onCheckout,
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              ),
              child: const Text('CHECKOUT', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductGridTile extends ConsumerWidget {
  final Product product;
  const _ProductGridTile({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => ref.read(salesControllerProvider.notifier).addToCart(product),
      borderRadius: BorderRadius.circular(12),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                color: AppColors.primary.withValues(alpha: 0.05),
                child: const Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 32),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'KES ${product.price.toStringAsFixed(2)}',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartItemTile extends ConsumerWidget {
  final CartItem item;
  const _CartItemTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.product.name, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
                  Text('KES ${item.product.price.toStringAsFixed(2)}', style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  onPressed: () => ref.read(salesControllerProvider.notifier).updateQuantity(item.product.id, item.quantity - 1),
                ),
                Text(item.quantity.toStringAsFixed(0), style: AppTextStyles.body),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  onPressed: () => ref.read(salesControllerProvider.notifier).updateQuantity(item.product.id, item.quantity + 1),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Text('KES ${item.total.toStringAsFixed(0)}', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _CheckoutBottomSheet extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(salesControllerProvider);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Finalize Sale', style: AppTextStyles.headline),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Total Amount Due',
              style: AppTextStyles.bodyLarge,
              textAlign: TextAlign.center,
            ),
            Text(
              'KES ${state.total.toStringAsFixed(2)}',
              style: AppTextStyles.displayMedium.copyWith(color: AppColors.primary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Payment Method', style: AppTextStyles.subtitle),
            const SizedBox(height: AppSpacing.md),
            _buildPaymentMethodButton(context, ref, PaymentMethod.cash, Icons.money, 'Cash'),
            const SizedBox(height: AppSpacing.sm),
            _buildPaymentMethodButton(context, ref, PaymentMethod.mpesa, Icons.phone_android, 'M-Pesa'),
            const SizedBox(height: AppSpacing.sm),
            _buildPaymentMethodButton(context, ref, PaymentMethod.card, Icons.credit_card, 'Card'),
            const SizedBox(height: AppSpacing.xl),
            if (state.isLoading)
              const Center(child: AppLoadingIndicator())
            else
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodButton(BuildContext context, WidgetRef ref, PaymentMethod method, IconData icon, String label) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      onTap: () {
        ref.read(salesControllerProvider.notifier).checkout(method);
        Navigator.pop(context);
      },
    );
  }
}

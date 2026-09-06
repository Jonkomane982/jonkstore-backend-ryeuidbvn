import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jonkstore/app/theme/app_colors.dart';
import 'package:jonkstore/app/theme/app_spacing.dart';
import 'package:jonkstore/core/routing/route_names.dart';
import 'package:jonkstore/features/products/controllers/product_controller.dart';
import 'package:jonkstore/features/products/presentation/widgets/product_item_card.dart';
import 'package:jonkstore/shared/textfields/search_text_field.dart';
import 'package:jonkstore/shared/loading/loading_indicator.dart';
import 'package:jonkstore/shared/loading/empty_state.dart';

class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key});

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(productControllerProvider.notifier).loadProducts(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            onPressed: () => ref.read(productControllerProvider.notifier).loadProducts(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SearchTextField(
              controller: _searchController,
              hintText: 'Search products...',
              onChanged: (value) => ref.read(productControllerProvider.notifier).searchProducts(value),
              onClear: () => ref.read(productControllerProvider.notifier).searchProducts(''),
            ),
          ),
          Expanded(
            child: _buildContent(state),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed(RouteNames.productAdd),
        icon: const Icon(Icons.add),
        label: const Text('New Product'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildContent(ProductState state) {
    if (state.isLoading) {
      return const Center(child: AppLoadingIndicator());
    }

    if (state.errorMessage != null) {
      return Center(child: Text(state.errorMessage!));
    }

    if (state.filteredProducts.isEmpty) {
      return EmptyState(
        title: state.searchQuery.isEmpty ? 'No Products' : 'No Results Found',
        message: state.searchQuery.isEmpty
            ? 'Add your first product to get started.'
            : 'Try searching for a different product name or SKU.',
        icon: Icons.inventory_2_outlined,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      itemCount: state.filteredProducts.length,
      itemBuilder: (context, index) {
        final product = state.filteredProducts[index];
        return ProductItemCard(
          product: product,
          onTap: () => context.pushNamed(
            RouteNames.productEdit,
            pathParameters: {'id': product.id},
          ),
        );
      },
    );
  }
}

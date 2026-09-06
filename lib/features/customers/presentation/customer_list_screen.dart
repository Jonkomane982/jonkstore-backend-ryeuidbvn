import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jonkstore/app/theme/app_colors.dart';
import 'package:jonkstore/app/theme/app_spacing.dart';
import 'package:jonkstore/app/theme/app_text_styles.dart';
import 'package:jonkstore/core/routing/route_names.dart';
import 'package:jonkstore/features/customers/controllers/customer_controller.dart';
import 'package:jonkstore/shared/loading/loading_indicator.dart';
import 'package:jonkstore/shared/loading/empty_state.dart';
import 'package:jonkstore/shared/textfields/search_text_field.dart';

class CustomerListScreen extends ConsumerStatefulWidget {
  const CustomerListScreen({super.key});

  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(customerControllerProvider.notifier).loadCustomers(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customerControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SearchTextField(
              controller: _searchController,
              hintText: 'Search by name or phone...',
              onChanged: (val) => ref.read(customerControllerProvider.notifier).search(val),
              onClear: () => ref.read(customerControllerProvider.notifier).search(''),
            ),
          ),
          Expanded(
            child: _buildContent(state),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.pushNamed('${RouteNames.customers}-add'),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildContent(CustomerState state) {
    if (state.isLoading) return const Center(child: AppLoadingIndicator());
    if (state.errorMessage != null) return Center(child: Text(state.errorMessage!));

    final customers = state.filteredCustomers;

    if (customers.isEmpty) {
      return EmptyState(
        title: state.searchQuery.isEmpty ? 'No Customers' : 'No Results',
        message: 'Add customers to track their purchase history and loyalty.',
        icon: Icons.people_outline,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      itemCount: customers.length,
      itemBuilder: (context, index) {
        final customer = customers[index];
        return Card(
          child: ListTile(
            onTap: () => context.pushNamed(
              '${RouteNames.customers}-edit',
              pathParameters: {'id': customer.id},
            ),
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withOpacity(0.1),
              child: Text(
                customer.name.substring(0, 1).toUpperCase(),
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(customer.name, style: AppTextStyles.subtitle),
            subtitle: Text(customer.phone ?? customer.email ?? 'No contact info'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Points', style: AppTextStyles.caption),
                Text(
                  customer.loyaltyPoints.toStringAsFixed(0),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

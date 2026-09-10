import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jonkstore/app/theme/app_colors.dart';
import 'package:jonkstore/app/theme/app_spacing.dart';
import 'package:jonkstore/app/theme/app_text_styles.dart';
import 'package:jonkstore/features/reports/controllers/reports_controller.dart';
import 'package:jonkstore/shared/loading/loading_indicator.dart';
import 'package:jonkstore/shared/cards/primary_card.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(reportsControllerProvider.notifier).loadReports(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics & Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_rounded),
            onPressed: _selectDateRange,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(reportsControllerProvider.notifier).loadReports(),
        child: state.isLoading
            ? const Center(child: AppLoadingIndicator())
            : Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _buildDateRangeHeader(state),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
                    
                    // Top Products Section
                    SliverToBoxAdapter(
                      child: _buildSectionTitle('Top Selling Products'),
                    ),
                    _buildTopProductsList(state),
                    
                    const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
                    
                    // Sales by Category Section
                    SliverToBoxAdapter(
                      child: _buildSectionTitle('Sales by Category'),
                    ),
                    _buildCategorySales(state),
                    
                    const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
                    
                    // Daily Revenue Section
                    SliverToBoxAdapter(
                      child: _buildSectionTitle('Revenue Trend'),
                    ),
                    _buildRevenueTrend(state),
                    
                    const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxxl)),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildDateRangeHeader(ReportsState state) {
    final df = DateFormat('dd MMM yyyy');
    return PrimaryCard(
      color: AppColors.primary.withValues(alpha: 0.05),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.date_range, color: AppColors.primary, size: 20),
          const SizedBox(width: AppSpacing.md),
          Text(
            '${df.format(state.startDate)} - ${df.format(state.endDate)}',
            style: AppTextStyles.subtitle.copyWith(color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Text(title, style: AppTextStyles.title.copyWith(fontSize: 18)),
    );
  }

  Widget _buildTopProductsList(ReportsState state) {
    if (state.topProducts.isEmpty) {
      return const SliverToBoxAdapter(
        child: Center(child: Text('No sales data for this period.')),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final product = state.topProducts[index];
          return Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Text('${index + 1}', style: const TextStyle(color: AppColors.primary)),
              ),
              title: Text(product.productName, style: AppTextStyles.subtitle),
              subtitle: Text('${product.quantitySold.toStringAsFixed(0)} units sold'),
              trailing: Text(
                'KES ${product.totalRevenue.toStringAsFixed(2)}',
                style: AppTextStyles.subtitle.copyWith(color: AppColors.primary),
              ),
            ),
          );
        },
        childCount: state.topProducts.length,
      ),
    );
  }

  Widget _buildCategorySales(ReportsState state) {
    if (state.categorySales.isEmpty) {
      return const SliverToBoxAdapter(child: Center(child: Text('No categories data.')));
    }

    final totalSales = state.categorySales.fold(0.0, (sum, item) => sum + item.totalSales);

    return SliverToBoxAdapter(
      child: PrimaryCard(
        child: Column(
          children: state.categorySales.map((cat) {
            final percentage = totalSales > 0 ? cat.totalSales / totalSales : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(cat.categoryName, style: AppTextStyles.bodyLarge),
                      Text('KES ${cat.totalSales.toStringAsFixed(0)}', style: AppTextStyles.subtitle),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: percentage,
                    backgroundColor: AppColors.grey100,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildRevenueTrend(ReportsState state) {
    if (state.dailyRevenue.isEmpty) {
      return const SliverToBoxAdapter(child: Center(child: Text('No revenue history available.')));
    }

    return SliverToBoxAdapter(
      child: PrimaryCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: state.dailyRevenue.map((day) {
            return ListTile(
              title: Text(day['date']),
              trailing: Text(
                'KES ${day['revenue'].toStringAsFixed(2)}',
                style: AppTextStyles.subtitle.copyWith(color: AppColors.success),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final state = ref.read(reportsControllerProvider);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: state.startDate, end: state.endDate),
    );

    if (picked != null) {
      ref.read(reportsControllerProvider.notifier).updateDateRange(picked.start, picked.end);
    }
  }
}

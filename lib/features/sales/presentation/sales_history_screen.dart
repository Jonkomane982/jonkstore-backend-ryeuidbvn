import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jonkstore/app/theme/app_colors.dart';
import 'package:jonkstore/app/theme/app_spacing.dart';
import 'package:jonkstore/app/theme/app_text_styles.dart';
import 'package:jonkstore/shared/loading/loading_indicator.dart';
import 'package:jonkstore/shared/loading/empty_state.dart';
import 'package:jonkstore/providers/repository_providers.dart';
import 'package:jonkstore/core/domain/models/sale.dart';

class SalesHistoryScreen extends ConsumerStatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  ConsumerState<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends ConsumerState<SalesHistoryScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final salesRepo = ref.watch(salesRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildDateHeader(),
          Expanded(
            child: FutureBuilder<List<Sale>>(
              future: _fetchSales(salesRepo),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: AppLoadingIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final sales = snapshot.data ?? [];

                if (sales.isEmpty) {
                  return const EmptyState(
                    title: 'No Sales Found',
                    message: 'Transactions for the selected period will appear here.',
                    icon: Icons.receipt_long_rounded,
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: sales.length,
                  itemBuilder: (context, index) {
                    final sale = sales[index];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.receipt_outlined),
                        ),
                        title: Text('Sale #${sale.id.substring(0, 8).toUpperCase()}'),
                        subtitle: Text(DateFormat('dd MMM yyyy, hh:mm a').format(sale.createdAt)),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'KES ${sale.totalAmount.toStringAsFixed(2)}',
                              style: AppTextStyles.subtitle.copyWith(color: AppColors.primary),
                            ),
                            Text(
                              sale.paymentMethod.name.toUpperCase(),
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateHeader() {
    final df = DateFormat('dd MMM');
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: AppColors.primary.withValues(alpha: 0.05),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            '${df.format(_startDate)} - ${df.format(_endDate)}',
            style: AppTextStyles.subtitle.copyWith(color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Future<List<Sale>> _fetchSales(dynamic repo) async {
    final result = await repo.findByDateRange(_startDate, _endDate);
    return result.fold((list) => list, (failure) => []);
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }
}

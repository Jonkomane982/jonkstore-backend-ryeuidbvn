import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:jonkstore/app/theme/app_colors.dart';
import 'package:jonkstore/app/theme/app_spacing.dart';
import 'package:jonkstore/app/theme/app_text_styles.dart';
import 'package:jonkstore/core/routing/route_names.dart';
import 'package:jonkstore/features/dashboard/controllers/dashboard_controller.dart';
import 'package:jonkstore/features/dashboard/models/dashboard_data.dart';
import 'package:jonkstore/features/dashboard/providers/dashboard_providers.dart';
import 'package:jonkstore/providers/auth_providers.dart';
import 'package:jonkstore/shared/cards/stat_card.dart';
import 'package:jonkstore/shared/cards/notification_card.dart';
import 'package:jonkstore/shared/cards/primary_card.dart';
import 'package:jonkstore/shared/loading/loading_indicator.dart';
import 'package:jonkstore/shared/loading/empty_state.dart';
import 'package:jonkstore/features/ai/presentation/widgets/jonkai_entry_point.dart';

/// The primary production dashboard for JonkStore POS.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(dashboardControllerProvider.notifier).loadDashboardData(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardControllerProvider);
    final businessAsync = ref.watch(currentBusinessProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.grey50,
      // JonkAI entry point integrated like Meta AI (positioned above the FAB area)
      floatingActionButton: const JonkAIEntryPoint(),
      body: RefreshIndicator(
        onRefresh: () => ref.read(dashboardControllerProvider.notifier).loadDashboardData(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _DashboardAppBar(businessAsync: businessAsync, user: user),
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (state.isLoading && state.data == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 100),
                      child: AppLoadingIndicator(),
                    )
                  else if (state.errorMessage != null && state.data == null)
                    EmptyState(
                      title: 'Error Loading Dashboard',
                      message: state.errorMessage!,
                      icon: Icons.error_outline,
                      actionLabel: 'Retry',
                      onActionPressed: () => ref.read(dashboardControllerProvider.notifier).loadDashboardData(),
                    )
                  else if (state.data != null) ...[
                    _buildGreeting(user?.name ?? 'Partner'),
                    const SizedBox(height: AppSpacing.xl),
                    _buildStatsGrid(state.data!),
                    const SizedBox(height: AppSpacing.xl),
                    _buildQuickActions(context),
                    const SizedBox(height: AppSpacing.xl),
                    _buildAICard(state.data!),
                    const SizedBox(height: AppSpacing.xl),
                    _buildNotificationsSection(state.data!),
                    const SizedBox(height: AppSpacing.xl),
                    _buildRecentSalesSection(state.data!),
                    const SizedBox(height: AppSpacing.xl),
                    _buildLowStockSection(state.data!),
                    const SizedBox(height: AppSpacing.xxxl),
                  ] else
                    const EmptyState(
                      title: 'Welcome to JonkStore',
                      message: 'Setup your business to see real-time performance metrics.',
                      icon: Icons.analytics_outlined,
                    ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGreeting(String name) {
    final hour = DateTime.now().hour;
    String greeting = 'Good Morning';
    if (hour >= 12 && hour < 17) greeting = 'Good Afternoon';
    if (hour >= 17) greeting = 'Good Evening';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting, $name',
          style: AppTextStyles.headline.copyWith(
            color: AppColors.grey900,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
          style: AppTextStyles.bodyLarge.copyWith(color: AppColors.grey500),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(DashboardData data) {
    final summary = data.summary;
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: 1.6,
          children: [
            StatCard(
              title: 'Revenue',
              value: 'KES ${summary.totalRevenue.toStringAsFixed(0)}',
              icon: Icons.payments_outlined,
              iconColor: AppColors.primary,
            ),
            StatCard(
              title: 'Net Profit',
              value: 'KES ${summary.totalProfit.toStringAsFixed(0)}',
              icon: Icons.account_balance_wallet_outlined,
              iconColor: AppColors.success,
            ),
            StatCard(
              title: 'Transactions',
              value: '${summary.totalSalesCount}',
              icon: Icons.receipt_long_outlined,
              iconColor: AppColors.info,
            ),
            StatCard(
              title: 'Low Stock',
              value: '${summary.lowStockCount}',
              icon: Icons.warning_amber_rounded,
              iconColor: summary.lowStockCount > 0 ? AppColors.error : AppColors.grey400,
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions', style: AppTextStyles.subtitle),
        const SizedBox(height: AppSpacing.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _ActionCard(
                label: 'New Sale',
                icon: Icons.add_shopping_cart,
                color: AppColors.primary,
                onTap: () => context.pushNamed(RouteNames.sales),
              ),
              _ActionCard(
                label: 'Products',
                icon: Icons.inventory_2_outlined,
                color: AppColors.secondary,
                onTap: () => context.pushNamed(RouteNames.products),
              ),
              _ActionCard(
                label: 'Inventory',
                icon: Icons.warehouse_outlined,
                color: AppColors.warning,
                onTap: () => context.pushNamed(RouteNames.inventory),
              ),
              _ActionCard(
                label: 'Customers',
                icon: Icons.people_outline,
                color: AppColors.info,
                onTap: () => context.pushNamed(RouteNames.customers),
              ),
              _ActionCard(
                label: 'Categories',
                icon: Icons.category_outlined,
                color: Colors.orange,
                onTap: () => context.pushNamed(RouteNames.categories),
              ),
              _ActionCard(
                label: 'Reports',
                icon: Icons.bar_chart_rounded,
                color: Colors.purple,
                onTap: () => context.pushNamed(RouteNames.reports),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAICard(DashboardData data) {
    final recommendation = data.topRecommendation;
    final healthScore = (data.healthScore * 100).toInt();

    return PrimaryCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.1),
                  AppColors.secondary.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text('AI Insights', style: AppTextStyles.subtitle),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Health Score: $healthScore%',
                    style: AppTextStyles.caption.copyWith(
                      color: healthScore > 70 ? AppColors.successDark : AppColors.warningDark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (recommendation != null) ...[
                  Text(recommendation.title, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(recommendation.content, style: AppTextStyles.body.copyWith(color: AppColors.grey600)),
                ] else
                  Text(
                    'No AI insights available. Process more sales to generate performance optimization tips.',
                    style: AppTextStyles.body.copyWith(color: AppColors.grey500),
                  ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: () => context.pushNamed(RouteNames.aiAssistant),
                    child: const Text('View Full Analysis'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsSection(DashboardData data) {
    if (data.recentNotifications.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        _SectionHeader(title: 'Recent Notifications', onSeeAll: () => context.pushNamed(RouteNames.notifications)),
        const SizedBox(height: AppSpacing.md),
        ...data.recentNotifications.map((n) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: NotificationCard(
                title: n.title,
                message: n.message,
                icon: Icons.notifications_none,
                time: n.createdAt,
              ),
            )),
      ],
    );
  }

  Widget _buildRecentSalesSection(DashboardData data) {
    if (data.recentSales.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        _SectionHeader(title: 'Recent Sales', onSeeAll: () => context.pushNamed(RouteNames.sales)),
        const SizedBox(height: AppSpacing.md),
        PrimaryCard(
          padding: EdgeInsets.zero,
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: data.recentSales.length,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, endIndent: 16),
            itemBuilder: (context, index) {
              final sale = data.recentSales[index];
              return ListTile(
                title: Text('Sale #${sale.id.substring(0, 5).toUpperCase()}', style: AppTextStyles.subtitle.copyWith(fontSize: 14)),
                subtitle: Text(DateFormat('hh:mm a').format(sale.createdAt)),
                trailing: Text('KES ${sale.totalAmount.toStringAsFixed(2)}', style: AppTextStyles.subtitle.copyWith(color: AppColors.primary)),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLowStockSection(DashboardData data) {
    if (data.lowStockProducts.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        _SectionHeader(title: 'Low Stock Alerts', onSeeAll: () => context.pushNamed(RouteNames.inventory)),
        const SizedBox(height: AppSpacing.md),
        PrimaryCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: data.lowStockProducts.map((p) => ListTile(
              leading: const Icon(Icons.inventory_2_outlined, color: AppColors.error),
              title: Text(p.name, style: AppTextStyles.subtitle.copyWith(fontSize: 14)),
              subtitle: Text('SKU: ${p.sku ?? 'N/A'}'),
              trailing: const Text('RESTOCK', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 10)),
            )).toList(),
          ),
        ),
      ],
    );
  }
}

class _DashboardAppBar extends StatelessWidget {
  final AsyncValue businessAsync;
  final dynamic user;

  const _DashboardAppBar({required this.businessAsync, this.user});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      floating: true,
      backgroundColor: AppColors.white,
      title: businessAsync.when(
        data: (business) => Row(
          children: [
            Container(
              height: 36,
              width: 36,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.storefront, color: Colors.white, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(business?.name ?? 'JonkStore', style: AppTextStyles.subtitle.copyWith(color: AppColors.grey900)),
                Text(business?.businessType ?? 'Main Branch', style: AppTextStyles.caption.copyWith(color: AppColors.grey500)),
              ],
            ),
          ],
        ),
        loading: () => const SizedBox(),
        error: (_, _) => const Text('Error'),
      ),
      actions: [
        IconButton(onPressed: () {}, icon: const Icon(Icons.search, color: AppColors.grey700)),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.grey200,
            child: Text(user?.name?.substring(0, 1).toUpperCase() ?? 'U', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: AppSpacing.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Container(
              height: 64,
              width: 64,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(label, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onSeeAll;

  const _SectionHeader({required this.title, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppTextStyles.subtitle),
        TextButton(onPressed: onSeeAll, child: const Text('See All')),
      ],
    );
  }
}

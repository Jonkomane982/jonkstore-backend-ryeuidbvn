import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:jonkstore/app/theme/app_colors.dart';
import 'package:jonkstore/app/theme/app_spacing.dart';
import 'package:jonkstore/app/theme/app_text_styles.dart';
import 'package:jonkstore/core/domain/models/category.dart';
import 'package:jonkstore/core/domain/enums/sync_status.dart';
import 'package:jonkstore/core/validators/app_validators.dart';
import 'package:jonkstore/core/auth/app_permission.dart';
import 'package:jonkstore/core/auth/authorization_service.dart';
import 'package:jonkstore/features/products/controllers/category_controller.dart';
import 'package:jonkstore/providers/auth_providers.dart';
import 'package:jonkstore/shared/buttons/primary_button.dart';
import 'package:jonkstore/shared/textfields/app_text_field.dart';
import 'package:jonkstore/shared/snackbars/custom_snack_bar.dart';
import 'package:jonkstore/shared/loading/loading_indicator.dart';
import 'package:jonkstore/shared/loading/empty_state.dart';
import 'package:jonkstore/shared/cards/primary_card.dart';
import 'package:jonkstore/shared/cards/stat_card.dart';

class CategoryListScreen extends ConsumerStatefulWidget {
  const CategoryListScreen({super.key});

  @override
  ConsumerState<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends ConsumerState<CategoryListScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(categoryControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(categoryControllerProvider);
    final stats = ref.watch(categoryStatsProvider);
    final user = ref.watch(currentUserProvider);
    
    final authService = AuthorizationService();
    final canManage = user != null && authService.hasPermission(user.role, AppPermission.manageCategories);

    return Scaffold(
      backgroundColor: AppColors.grey50,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildAppBar(context, ref, state),
          SliverToBoxAdapter(
            child: _buildStatsSection(stats),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            sliver: SliverToBoxAdapter(
              child: _buildSearchAndFilterBar(ref, state),
            ),
          ),
          _buildMainContent(context, ref, state, canManage),
          if (state.isLoadMoreLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Center(child: AppLoadingIndicator(size: 24)),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: canManage && !state.includeDeleted
        ? FloatingActionButton.extended(
            onPressed: () => _showCategoryDialog(context, ref, null),
            backgroundColor: AppColors.primary,
            elevation: 2,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('New Category', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ).animate().scale(delay: 400.ms, curve: Curves.easeOutBack)
        : null,
    );
  }

  Widget _buildAppBar(BuildContext context, WidgetRef ref, CategoryState state) {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: true,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          state.includeDeleted ? 'Trash (Categories)' : 'Categories', 
          style: AppTextStyles.title.copyWith(color: AppColors.grey900)
        ),
        centerTitle: false,
        titlePadding: const EdgeInsetsDirectional.only(start: 16, bottom: 16),
      ),
      actions: [
        IconButton(
          icon: Icon(
            state.includeDeleted ? Icons.delete_outline_rounded : Icons.delete_sweep_outlined,
            color: state.includeDeleted ? AppColors.error : AppColors.grey600
          ),
          tooltip: state.includeDeleted ? 'View Active' : 'View Deleted',
          onPressed: () => ref.read(categoryControllerProvider.notifier).setIncludeDeleted(!state.includeDeleted),
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
          onPressed: () => ref.read(categoryControllerProvider.notifier).loadCategories(),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildStatsSection(AsyncValue<Map<String, dynamic>> stats) {
    return stats.when(
      data: (data) => Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: StatCard(
                title: 'Active Categories',
                value: data['active'].toString(),
                icon: Icons.category_rounded,
                iconColor: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: StatCard(
                title: 'Total Records',
                value: data['total'].toString(),
                icon: Icons.storage_rounded,
                iconColor: AppColors.grey600,
              ),
            ),
          ],
        ).animate().fadeIn().slideY(begin: 0.1),
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildSearchAndFilterBar(WidgetRef ref, CategoryState state) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: AppTextField(
            hintText: 'Search by name or description...',
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.grey400),
            onChanged: (value) => ref.read(categoryControllerProvider.notifier).setSearchQuery(value),
            suffixIcon: state.searchQuery.isNotEmpty 
              ? IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => ref.read(categoryControllerProvider.notifier).setSearchQuery(''),
                )
              : null,
          ),
        ),
        Row(
          children: [
            Text('Sort by:', style: AppTextStyles.caption.copyWith(color: AppColors.grey500)),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Name'),
              selected: state.sortBy == 'name',
              onSelected: (_) => ref.read(categoryControllerProvider.notifier).setSorting('name', state.ascending),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Date'),
              selected: state.sortBy == 'created_at',
              onSelected: (_) => ref.read(categoryControllerProvider.notifier).setSorting('created_at', false),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => ref.read(categoryControllerProvider.notifier).setSorting(state.sortBy, !state.ascending),
              icon: Icon(state.ascending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 16),
              label: Text(state.ascending ? 'Asc' : 'Desc'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  Widget _buildMainContent(BuildContext context, WidgetRef ref, CategoryState state, bool canManage) {
    if (state.isLoading && state.categories.isEmpty) {
      return const SliverFillRemaining(
        child: Center(child: AppLoadingIndicator()),
      );
    }

    if (state.errorMessage != null) {
      return SliverFillRemaining(
        child: EmptyState(
          title: 'Error Occurred',
          message: state.errorMessage!,
          icon: Icons.error_outline_rounded,
          actionLabel: 'Retry',
          onActionPressed: () => ref.read(categoryControllerProvider.notifier).loadCategories(),
        ),
      );
    }

    if (state.categories.isEmpty) {
      return SliverFillRemaining(
        child: EmptyState(
          title: state.includeDeleted ? 'Trash is Empty' : 'No Categories',
          message: state.includeDeleted 
            ? 'No deleted categories found.'
            : 'Begin by adding product categories to your inventory.',
          icon: state.includeDeleted ? Icons.delete_outline_rounded : Icons.category_outlined,
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final category = state.categories[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _CategoryListItem(category: category, canManage: canManage)
                  .animate()
                  .fadeIn(delay: (index * 30).ms)
                  .slideX(begin: 0.05),
            );
          },
          childCount: state.categories.length,
        ),
      ),
    );
  }

  void _showCategoryDialog(BuildContext context, WidgetRef ref, Category? category) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CategoryFormDialog(category: category),
    );
  }
}

class _CategoryListItem extends ConsumerWidget {
  final Category category;
  final bool canManage;
  const _CategoryListItem({required this.category, required this.canManage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PrimaryCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: canManage && !category.isDeleted ? () => _showEditDialog(context, ref) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: (category.isDeleted ? AppColors.grey400 : AppColors.primary).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  category.isDeleted ? Icons.delete_outline_rounded : Icons.inventory_2_rounded, 
                  color: category.isDeleted ? AppColors.grey500 : AppColors.primary, 
                  size: 24
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name, 
                      style: AppTextStyles.subtitle.copyWith(
                        fontWeight: FontWeight.bold,
                        decoration: category.isDeleted ? TextDecoration.lineThrough : null,
                        color: category.isDeleted ? AppColors.grey500 : AppColors.grey900,
                      )
                    ),
                    if (category.description != null && category.description!.isNotEmpty)
                      Text(
                        category.description!,
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.grey600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _SyncStatusBadge(status: category.syncStatus),
                  const SizedBox(height: 8),
                  if (canManage)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!category.isDeleted) ...[
                          IconButton(
                            icon: const Icon(Icons.edit_note_rounded, color: AppColors.info, size: 22),
                            onPressed: () => _showEditDialog(context, ref),
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Edit',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_sweep_rounded, color: AppColors.error, size: 22),
                            onPressed: () => _showDeleteConfirmation(context, ref),
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Delete',
                          ),
                        ] else
                          IconButton(
                            icon: const Icon(Icons.restore_from_trash_rounded, color: AppColors.success, size: 22),
                            onPressed: () => _showRestoreConfirmation(context, ref),
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Restore',
                          ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CategoryFormDialog(category: category),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Delete "${category.name}"? This will not remove products, but they will become uncategorized.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final result = await ref.read(categoryControllerProvider.notifier).deleteCategory(category.id);
              result.fold(
                (_) => CustomSnackBar.showSuccess(context, 'Category moved to trash'),
                (f) => CustomSnackBar.showError(context, f.message),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showRestoreConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Category'),
        content: Text('Do you want to restore "${category.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final result = await ref.read(categoryControllerProvider.notifier).restoreCategory(category.id);
              result.fold(
                (_) => CustomSnackBar.showSuccess(context, 'Category restored'),
                (f) => CustomSnackBar.showError(context, f.message),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }
}

class _CategoryFormDialog extends ConsumerStatefulWidget {
  final Category? category;
  const _CategoryFormDialog({this.category});

  @override
  ConsumerState<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends ConsumerState<_CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name);
    _descController = TextEditingController(text: widget.category?.description);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final user = ref.read(currentUserProvider);
    
    final result = widget.category == null
        ? await ref.read(categoryControllerProvider.notifier).createCategory(
            name: _nameController.text.trim(),
            description: _descController.text.trim(),
            businessId: user?.businessId,
          )
        : await ref.read(categoryControllerProvider.notifier).updateCategory(
            widget.category!.copyWith(
              name: _nameController.text.trim(),
              description: _descController.text.trim(),
              updatedBy: user?.id,
            ),
          );

    result.fold(
      (_) {
        Navigator.pop(context);
        CustomSnackBar.showSuccess(context, 'Category saved successfully');
      },
      (failure) {
        setState(() => _isSaving = false);
        CustomSnackBar.showError(context, failure.message);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.category == null ? 'New Category' : 'Edit Category',
                style: AppTextStyles.title,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Category Name',
                controller: _nameController,
                validator: (v) => AppValidators.required(v, 'Name'),
                maxLength: 50,
                autoFocus: true,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Description',
                controller: _descController,
                maxLines: 3,
                maxLength: 250,
                hintText: 'Optional notes about this category',
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  PrimaryButton(
                    text: 'Save',
                    isLoading: _isSaving,
                    onPressed: _submit,
                    width: 120,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncStatusBadge extends StatelessWidget {
  final SyncStatus status;
  const _SyncStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    switch (status) {
      case SyncStatus.synced:
        color = AppColors.success;
        icon = Icons.check_circle_rounded;
        break;
      case SyncStatus.pending:
      case SyncStatus.updated:
        color = AppColors.warning;
        icon = Icons.sync_rounded;
        break;
      case SyncStatus.failed:
        color = AppColors.error;
        icon = Icons.error_rounded;
        break;
      case SyncStatus.deleted:
        color = AppColors.grey400;
        icon = Icons.delete_outline_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            status.name.toUpperCase(),
            style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}

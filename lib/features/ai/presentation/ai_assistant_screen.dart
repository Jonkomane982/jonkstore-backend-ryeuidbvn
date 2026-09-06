import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jonkstore/app/theme/app_colors.dart';
import 'package:jonkstore/app/theme/app_spacing.dart';
import 'package:jonkstore/app/theme/app_text_styles.dart';
import 'package:jonkstore/features/ai/controllers/ai_controller.dart';
import 'package:jonkstore/shared/loading/loading_indicator.dart';
import 'package:jonkstore/shared/loading/empty_state.dart';
import 'package:jonkstore/shared/cards/primary_card.dart';
import 'package:jonkstore/shared/buttons/primary_button.dart';
import 'package:jonkstore/shared/snackbars/custom_snack_bar.dart';

class AIAssistantScreen extends ConsumerStatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  ConsumerState<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends ConsumerState<AIAssistantScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(aiControllerProvider.notifier).loadRecommendations(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jonk AI Assistant'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(aiControllerProvider.notifier).loadRecommendations(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(aiControllerProvider.notifier).loadRecommendations(),
        child: _buildContent(state),
      ),
    );
  }

  Widget _buildContent(AIState state) {
    if (state.isLoading && state.recommendations.isEmpty) {
      return const Center(child: AppLoadingIndicator());
    }

    if (state.errorMessage != null) {
      return Center(child: Text(state.errorMessage!));
    }

    if (state.recommendations.isEmpty) {
      return const EmptyState(
        title: 'Gathering Insights...',
        message: 'Your AI assistant is analyzing your business data. Recommendations will appear here shortly.',
        icon: Icons.auto_awesome_outlined,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: state.recommendations.length,
      itemBuilder: (context, index) {
        final rec = state.recommendations[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: PrimaryCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        rec.category.toUpperCase(),
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${(rec.confidenceScore * 100).toInt()}% Confidence',
                      style: AppTextStyles.caption.copyWith(color: AppColors.grey500),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(rec.title, style: AppTextStyles.title),
                const SizedBox(height: 8),
                Text(rec.content, style: AppTextStyles.bodyLarge),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => ref.read(aiControllerProvider.notifier).dismissRecommendation(rec.id),
                        child: const Text('Dismiss'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: PrimaryButton(
                        text: rec.isApplied ? 'Applied' : 'Apply Insight',
                        onPressed: rec.isApplied 
                          ? null 
                          : () {
                              ref.read(aiControllerProvider.notifier).applyRecommendation(rec.id);
                              CustomSnackBar.showSuccess(context, 'Recommendation applied!');
                            },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

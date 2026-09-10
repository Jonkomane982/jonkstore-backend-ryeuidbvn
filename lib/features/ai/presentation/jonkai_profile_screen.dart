import 'package:flutter/material.dart';
import 'package:jonkstore/app/theme/app_colors.dart';
import 'package:jonkstore/app/theme/app_spacing.dart';
import 'package:jonkstore/app/theme/app_text_styles.dart';
import 'package:jonkstore/features/ai/models/jonkai_config.dart';

class JonkAIProfileScreen extends StatelessWidget {
  const JonkAIProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const config = JonkAIConfig.current;

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.white),
        title: Text(
          'AI Profile',
          style: AppTextStyles.subtitle.copyWith(color: AppColors.white),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.xl),
            // Profile Image
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2),
                  image: const DecorationImage(
                    image: AssetImage('assets/JonkAI.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              config.name,
              style: AppTextStyles.headline.copyWith(color: AppColors.white),
            ),
            Text(
              config.type,
              style: AppTextStyles.body.copyWith(color: AppColors.primary),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Info Sections
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection('About', config.description),
                  _buildSection('Version', config.version),
                  _buildSection('Status', config.status, valueColor: AppColors.success),
                  _buildCapabilities(config.capabilities),
                  _buildSection('Data & Privacy', config.dataAccessDescription),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: AppTextStyles.caption.copyWith(
              color: AppColors.grey500,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: AppTextStyles.bodyLarge.copyWith(
              color: valueColor ?? AppColors.grey300,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapabilities(List<String> capabilities) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CAPABILITIES',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.grey500,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: capabilities.map((cap) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Text(
                cap,
                style: AppTextStyles.caption.copyWith(color: AppColors.primary),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

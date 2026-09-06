import 'package:flutter/foundation.dart';

/// Centralized configuration for JonkAI Assistant.
@immutable
class JonkAIConfig {
  final String name;
  final String type;
  final String description;
  final String version;
  final String status;
  final List<String> capabilities;
  final String dataAccessDescription;

  const JonkAIConfig({
    this.name = 'JonkAI',
    this.type = 'AI Business Assistant',
    this.description = 'Your Smart Business Assistant',
    this.version = '1.0.0',
    this.status = 'Online',
    this.capabilities = const [
      'Real-time Business Analytics',
      'Sales & Revenue Forecasting',
      'Inventory Stock-out Prediction',
      'Anomaly & Security Detection',
      'Product Performance Insights',
      'Intelligent Recommendations',
    ],
    this.dataAccessDescription = 'JonkAI accesses your historical operational data securely from the analytical mirror to provide insights without affecting your daily transactions.',
  });

  static const JonkAIConfig current = JonkAIConfig();
}

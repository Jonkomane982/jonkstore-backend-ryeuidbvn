import '../enums/sync_status.dart';

/// Represents an AI-generated insight or recommendation for the business.
class AIRecommendation {
  final String id;
  final String businessId;
  final String branchId;
  final String title;
  final String content;
  final String category; // Inventory, Sales, Staffing, etc.
  final double confidenceScore;
  final Map<String, dynamic>? metadata;
  final bool isApplied;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncStatus syncStatus;

  AIRecommendation({
    required this.id,
    required this.businessId,
    required this.branchId,
    required this.title,
    required this.content,
    required this.category,
    required this.confidenceScore,
    this.metadata,
    this.isApplied = false,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = SyncStatus.pending,
  });

  AIRecommendation copyWith({
    String? id,
    String? businessId,
    String? branchId,
    String? title,
    String? content,
    String? category,
    double? confidenceScore,
    Map<String, dynamic>? metadata,
    bool? isApplied,
    DateTime? createdAt,
    DateTime? updatedAt,
    SyncStatus? syncStatus,
  }) {
    return AIRecommendation(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      branchId: branchId ?? this.branchId,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      metadata: metadata ?? this.metadata,
      isApplied: isApplied ?? this.isApplied,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'businessId': businessId,
      'branchId': branchId,
      'title': title,
      'content': content,
      'category': category,
      'confidenceScore': confidenceScore,
      'metadata': metadata?.toString(),
      'isApplied': isApplied ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sync_status': syncStatus.name,
    };
  }

  factory AIRecommendation.fromJson(Map<String, dynamic> json) {
    return AIRecommendation(
      id: json['id'],
      businessId: json['businessId'],
      branchId: json['branchId'],
      title: json['title'],
      content: json['content'],
      category: json['category'],
      confidenceScore: (json['confidenceScore'] as num).toDouble(),
      isApplied: json['isApplied'] == 1,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      syncStatus: SyncStatus.values.firstWhere(
        (e) => e.name == json['sync_status'],
        orElse: () => SyncStatus.pending,
      ),
    );
  }
}

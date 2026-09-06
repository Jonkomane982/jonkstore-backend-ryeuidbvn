import '../enums/sync_status.dart';

/// Represents an image associated with a product.
class ProductImage {
  final String id;
  final String productId;
  final String imageUrl;
  final bool isPrimary;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncStatus syncStatus;

  ProductImage({
    required this.id,
    required this.productId,
    required this.imageUrl,
    this.isPrimary = false,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = SyncStatus.pending,
  });

  ProductImage copyWith({
    String? id,
    String? productId,
    String? imageUrl,
    bool? isPrimary,
    DateTime? createdAt,
    DateTime? updatedAt,
    SyncStatus? syncStatus,
  }) {
    return ProductImage(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      imageUrl: imageUrl ?? this.imageUrl,
      isPrimary: isPrimary ?? this.isPrimary,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productId': productId,
      'imageUrl': imageUrl,
      'isPrimary': isPrimary,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'syncStatus': syncStatus.name,
    };
  }

  factory ProductImage.fromJson(Map<String, dynamic> json) {
    return ProductImage(
      id: json['id'],
      productId: json['productId'],
      imageUrl: json['imageUrl'],
      isPrimary: json['isPrimary'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      syncStatus: SyncStatus.values.firstWhere((e) => e.name == json['syncStatus']),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductImage &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          productId == other.productId &&
          imageUrl == other.imageUrl &&
          isPrimary == other.isPrimary;

  @override
  int get hashCode =>
      id.hashCode ^ productId.hashCode ^ imageUrl.hashCode ^ isPrimary.hashCode;
}

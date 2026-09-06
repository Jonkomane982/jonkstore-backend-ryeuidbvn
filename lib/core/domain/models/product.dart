import '../enums/sync_status.dart';

enum ProductType { physical, service, digital }

/// Represents a product in the JonkStore system.
/// Aligned with the commercial 3NF schema (006_products.sql).
class Product {
  final String id;
  final String businessId;
  final String? brandId;
  final String unitId;
  final String name;
  final String? description;
  final String? sku;
  final String? barcode;
  final ProductType type;
  final double buyingPrice;  // cost_price in schema
  final double sellingPrice; // price in schema
  final String? categoryId; 
  final String? supplierId; 
  final double lowStockThreshold;
  final bool trackInventory;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final bool isDeleted;
  final SyncStatus syncStatus;
  final int version;
  final String? createdBy;
  final String? updatedBy;

  // Transient field for UI display, fetched from Inventory module logic
  final double? currentStock;

  Product({
    required this.id,
    required this.businessId,
    this.brandId,
    required this.unitId,
    required this.name,
    this.description,
    this.sku,
    this.barcode,
    this.type = ProductType.physical,
    this.buyingPrice = 0.0,
    required this.sellingPrice,
    this.categoryId,
    this.supplierId,
    this.lowStockThreshold = 0.0,
    this.trackInventory = true,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.isDeleted = false,
    this.syncStatus = SyncStatus.pending,
    this.version = 1,
    this.createdBy,
    this.updatedBy,
    this.currentStock,
  });

  // Aliases for compatibility with existing Sales, Purchases, and Onboarding modules
  double get price => sellingPrice;
  double get costPrice => buyingPrice;

  Product copyWith({
    String? id,
    String? businessId,
    String? brandId,
    String? unitId,
    String? name,
    String? description,
    String? sku,
    String? barcode,
    ProductType? type,
    double? buyingPrice,
    double? sellingPrice,
    String? categoryId,
    String? supplierId,
    double? lowStockThreshold,
    bool? trackInventory,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool? isDeleted,
    SyncStatus? syncStatus,
    int? version,
    String? createdBy,
    String? updatedBy,
    double? currentStock,
  }) {
    return Product(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      brandId: brandId ?? this.brandId,
      unitId: unitId ?? this.unitId,
      name: name ?? this.name,
      description: description ?? this.description,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      type: type ?? this.type,
      buyingPrice: buyingPrice ?? this.buyingPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      categoryId: categoryId ?? this.categoryId,
      supplierId: supplierId ?? this.supplierId,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      trackInventory: trackInventory ?? this.trackInventory,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
      version: version ?? this.version,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      currentStock: currentStock ?? this.currentStock,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'brand_id': brandId,
      'unit_id': unitId,
      'name': name,
      'description': description,
      'sku': sku,
      'barcode': barcode,
      'type': type.name.toUpperCase(),
      'buying_price': buyingPrice,
      'selling_price': sellingPrice,
      'category_id': categoryId,
      'supplier_id': supplierId,
      'low_stock_threshold': lowStockThreshold,
      'track_inventory': trackInventory ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
      'sync_status': syncStatus.name.toUpperCase(),
      'version': version,
      'created_by': createdBy,
      'updated_by': updatedBy,
    };
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      businessId: json['business_id'],
      brandId: json['brand_id'],
      unitId: json['unit_id'] ?? 'default',
      name: json['name'],
      description: json['description'],
      sku: json['sku'],
      barcode: json['barcode'],
      type: ProductType.values.firstWhere(
        (e) => e.name.toUpperCase() == (json['type'] ?? 'PHYSICAL'),
        orElse: () => ProductType.physical,
      ),
      buyingPrice: (json['buying_price'] ?? 0.0).toDouble(),
      sellingPrice: (json['selling_price'] ?? 0.0).toDouble(),
      categoryId: json['category_id'],
      supplierId: json['supplier_id'],
      lowStockThreshold: (json['low_stock_threshold'] ?? 0.0).toDouble(),
      trackInventory: (json['track_inventory'] ?? 1) == 1,
      isActive: (json['is_active'] ?? 1) == 1,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      deletedAt: json['deleted_at'] != null ? DateTime.parse(json['deleted_at']) : null,
      isDeleted: (json['is_deleted'] ?? 0) == 1,
      syncStatus: SyncStatus.values.firstWhere(
        (e) => e.name.toUpperCase() == (json['sync_status'] ?? 'PENDING'),
        orElse: () => SyncStatus.pending,
      ),
      version: json['version'] ?? 1,
      createdBy: json['created_by'],
      updatedBy: json['updated_by'],
      currentStock: (json['current_stock'] as num?)?.toDouble(),
    );
  }
}

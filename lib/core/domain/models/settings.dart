import '../enums/sync_status.dart';

/// Represents application and business-level settings.
class Settings {
  final String id;
  final String businessId;
  final String? branchId;
  final String currencyCode;
  final String currencySymbol;
  final String taxName;
  final double taxRate;
  final bool enableInventoryTracking;
  final bool enableLowStockNotifications;
  final String receiptFooter;
  final String? timeZone;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncStatus syncStatus;

  Settings({
    required this.id,
    required this.businessId,
    this.branchId,
    this.currencyCode = 'USD',
    this.currencySymbol = '\$',
    this.taxName = 'VAT',
    this.taxRate = 0.0,
    this.enableInventoryTracking = true,
    this.enableLowStockNotifications = true,
    this.receiptFooter = 'Thank you for shopping with us!',
    this.timeZone,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = SyncStatus.pending,
  });

  Settings copyWith({
    String? id,
    String? businessId,
    String? branchId,
    String? currencyCode,
    String? currencySymbol,
    String? taxName,
    double? taxRate,
    bool? enableInventoryTracking,
    bool? enableLowStockNotifications,
    String? receiptFooter,
    String? timeZone,
    DateTime? createdAt,
    DateTime? updatedAt,
    SyncStatus? syncStatus,
  }) {
    return Settings(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      branchId: branchId ?? this.branchId,
      currencyCode: currencyCode ?? this.currencyCode,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      taxName: taxName ?? this.taxName,
      taxRate: taxRate ?? this.taxRate,
      enableInventoryTracking: enableInventoryTracking ?? this.enableInventoryTracking,
      enableLowStockNotifications: enableLowStockNotifications ?? this.enableLowStockNotifications,
      receiptFooter: receiptFooter ?? this.receiptFooter,
      timeZone: timeZone ?? this.timeZone,
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
      'currencyCode': currencyCode,
      'currencySymbol': currencySymbol,
      'taxName': taxName,
      'taxRate': taxRate,
      'enableInventoryTracking': enableInventoryTracking,
      'enableLowStockNotifications': enableLowStockNotifications,
      'receiptFooter': receiptFooter,
      'timeZone': timeZone,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'syncStatus': syncStatus.name,
    };
  }

  factory Settings.fromJson(Map<String, dynamic> json) {
    return Settings(
      id: json['id'],
      businessId: json['businessId'],
      branchId: json['branchId'],
      currencyCode: json['currencyCode'] ?? 'USD',
      currencySymbol: json['currencySymbol'] ?? '\$',
      taxName: json['taxName'] ?? 'VAT',
      taxRate: (json['taxRate'] as num).toDouble(),
      enableInventoryTracking: json['enableInventoryTracking'] ?? true,
      enableLowStockNotifications: json['enableLowStockNotifications'] ?? true,
      receiptFooter: json['receiptFooter'] ?? '',
      timeZone: json['timeZone'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      syncStatus: SyncStatus.values.firstWhere((e) => e.name == json['syncStatus']),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Settings &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          businessId == other.businessId &&
          taxRate == other.taxRate &&
          currencyCode == other.currencyCode;

  @override
  int get hashCode => id.hashCode ^ businessId.hashCode ^ taxRate.hashCode ^ currencyCode.hashCode;
}

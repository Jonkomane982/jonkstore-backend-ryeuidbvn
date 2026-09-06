/// Defines all granular permissions within the JonkStore POS system.
enum AppPermission {
  viewDashboard,
  manageProducts,
  manageCategories,
  
  // Inventory
  manageInventory, // Added as a catch-all or high-level permission
  viewInventory,
  adjustInventory,
  performStockCount,
  transferStock,
  viewInventoryCost,

  manageSales,
  manageCustomers,
  manageSuppliers,
  managePurchases,
  manageReports,
  manageNotifications,
  manageEmployees,
  manageSettings,
  viewProfit,
  useAi,
}

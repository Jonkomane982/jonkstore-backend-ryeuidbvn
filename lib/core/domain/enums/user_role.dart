/// Defines the various access levels within the JonkStore POS system.
enum UserRole {
  /// Full system access, typically for technical support or super admins.
  admin,

  /// The owner of the business, has access to all business-wide data and settings.
  owner,

  /// Branch-level administrator with permissions to manage staff and inventory.
  manager,

  /// Front-line staff responsible for processing sales and handling customers.
  cashier,

  /// General staff with access to inventory and stock management.
  storeAssistant,
}

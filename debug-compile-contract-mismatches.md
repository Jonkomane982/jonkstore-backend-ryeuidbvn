# [OPEN] debug-compile-contract-mismatches
## Session: compile-contract-mismatches | Date: 2026-08-28
## Hypotheses (Falsifiable)

| ID | Hypothesis | Falsification Criteria |
|----|------------|-------------------------|
| H1 | InventoryRepository declares 4 methods (createStockTransfer, findByBarcode, getInventoryValuation, getStockTransfers) not implemented in InventoryRepositoryImpl → analyzer reports `Missing concrete implementation` | Analyzer output lists exactly those 4 method names for InventoryRepositoryImpl |
| H2 | InventoryRepository.findAll() named params (includes `categoryId`) ≠ InventoryRepositoryImpl.findAll() params → analyzer reports `Inconsistent method signature` / `Invalid override` | Analyzer reports `@override` mismatch on findAll with `categoryId` param name |
| H3 | InventoryController, SalesController, PurchaseController call `repository.recordTransaction(...)` but InventoryRepository lacks this member → analyzer reports `The method 'recordTransaction' isn't defined for the type 'InventoryRepository'` | Analyzer reports the method not defined at those call sites |
| H4 | InventoryRepositoryImpl constructor has no `localDataSource:` named param (may use different name/positional) but repository_providers passes `localDataSource:` → analyzer reports `The named parameter 'localDataSource' isn't defined` | Analyzer flags provider with that exact named-param error |
| H5 | owner_providers passes N positional/named args to OwnerService constructor but OwnerService.constructor requires M args (different count/types) → analyzer reports constructor arg mismatch at provider construction | Analyzer flags provider line with wrong-number/name-of-params |
| H6 | InventoryTransaction model exposes canonical fields (e.g. `quantity`+`balanceAfter` or similar) but 4 consumers (history, adjustment, sales, purchase) use stale names `quantityChanged` / `resultingQuantity` → analyzer reports `Getter not found: 'quantityChanged'/'resultingQuantity'` on those 4 files | Analyzer reports getter not found for those exact identifiers on InventoryTransaction |
| H7 | Customer model has canonical fields (e.g. `fullName`, `loyaltyPointsBalance`, etc) but list/form use `customer.loyaltyPoints` / constructor param `name:` → analyzer reports getter not found + named param not defined | Analyzer reports loyaltyPoints getter missing + Customer constructor `name:` param not defined |
| H8 | InventoryTransactionType enum has case `supplierReturn` and at least one Dart 3 switch statement in inventory_history/adjustment or controllers does not cover it → analyzer reports `Missing case clause for 'supplierReturn'` or `non-exhaustive` | Analyzer reports supplierReturn missing case on InventoryTransactionType switch |
| H9 | InventoryTransactionDao missing method `findByProductId(productId)` called by InventoryRepositoryImpl → analyzer reports `The method 'findByProductId' isn't defined for the type 'InventoryTransactionDao'` | Analyzer flags that exact identifier in InventoryRepositoryImpl |
| H10 | Cross-cutting: other interface/impl mismatches exist in payments, reports, notifications, etc., beyond user's 10-item list → flutter analyze reports additional errors outside the 10 categories | Additional analyzer errors outside Inventory/Customers/Providers surfaces |

## Evidence Log (Pre-fix) — All 9 Hypotheses CONFIRMED via static inspection

| H# | Status | Evidence Location & Finding |
|----|--------|------------------------------|
| H1 | ✅ CONFIRMED | `inventory_repository.dart` interface declares `findByBarcode` (L15), `createStockTransfer` (L40), `getStockTransfers` (L41), `getInventoryValuation` (L44) — none implemented in `inventory_repository_impl.dart` |
| H2 | ✅ CONFIRMED | `InventoryRepository.findAll` I/F params: `{branchId, lowStockOnly, outOfStockOnly, searchQuery, categoryId, supplierId, limit, offset}` (L16-25). Impl `findAll` (L78-85) missing `outOfStockOnly / categoryId / supplierId`. Underlying `_inventoryDao.getInventoryWithProductInfo` ALREADY accepts these 3 params (InventoryDao L69-79). |
| H3 | ✅ CONFIRMED | `inventory_controller.dart` L61 calls `_repository.recordTransaction(transaction)`. `sales_controller.dart` L185 calls same. `purchase_controller.dart` L194 calls same. `InventoryRepository` interface (L8-48) has NO `recordTransaction` method. |
| H4 | ✅ CONFIRMED | `repository_providers.dart` L208-214 constructs `InventoryRepositoryImpl(localDataSource:, remoteDataSource:, syncQueue:)`. But real constructor `InventoryRepositoryImpl` (L37-45) requires `inventoryDao, transactionDao, adjustmentDao, countDao, transferDao, databaseService, syncQueue` — completely different parameter names/types. |
| H5 | ✅ CONFIRMED | `owner_providers.dart` L21-26 calls `OwnerService(FirebaseAuth.instance, ownerRepo)` — 2 positional args. Real constructor `OwnerService` (L60-65) requires 3 positional: `(this._firebaseAuth, this._ownerRepository, this._otpService, {PasswordService? passwordService})`. Missing 3rd arg `OtpService`. |
| H6 | ✅ CONFIRMED | `InventoryTransaction` model (L12-15) canonical fields: `quantityChange`, `previousQuantity`, `newQuantity`. But consumers use stale names `quantityChanged` / `resultingQuantity` at: `inventory_history_screen.dart` L66,68,87; `inventory_adjustment_screen.dart` L66-67; `sales_controller.dart` L176-177; `purchase_controller.dart` L185-186. Additionally, `InventoryTransaction` constructor REQUIRES `previousQuantity` + `transactionDate` (L33+L39), which are MISSING in adjustment_screen, sales_controller, purchase_controller. |
| H7 | ✅ CONFIRMED | `Customer` model (L6-L38) uses ALL snake_case constructor params (`first_name`, `business_id`, `loyalty_points`, `created_at`, `updated_at`, `sync_status`). Compatibility getter `name` exists at L41 (OK for list screen). Failures: (a) `customer_list_screen.dart` L109 uses `customer.loyaltyPoints` → no such getter; field is `loyalty_points`. (b) `customer_form_screen.dart` L89/93/97 uses `name:` / `businessId:` / `syncStatus:` constructor params but the model exposes `first_name:` / `business_id:` / `sync_status:`. |
| H8 | ✅ CONFIRMED | `inventory_repository_impl.dart` L144 calls `_transactionDao.findByProductId(productId)`. `InventoryTransactionDao` (L7-39) has methods `insert`, `findByInventoryId`, `findRecent`. `findByProductId` is not implemented. DatabaseConstants L85 has `columnProductId` ready for the WHERE clause. |
| H9 | ✅ CONFIRMED | `InventoryTransactionType` enum has 9 values (L2-28): purchase, sale, adjustment, returnItem, supplierReturn, damage, stockCount, transferIn, transferOut. `inventory_history_screen.dart` L101-122 `_buildTypeIcon` switch covers only 5 (missing supplierReturn, stockCount, transferIn, transferOut). `inventory_history_screen.dart` L135-141 `_getDefaultNote` switch covers only 5 (same 4 missing). |

## Fixes Applied
| File | Change |
|------|--------|
| (pending) | (populated during Phase 2) |

## Verification (Post-fix)
| Check | Result |
|-------|--------|
| flutter analyze | (pending) |
| flutter test | (pending) |
| flutter build apk --debug | (pending) |

## Status
[OPEN]

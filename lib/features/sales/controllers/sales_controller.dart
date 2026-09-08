import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:jonkstore/core/domain/models/sale.dart';
import 'package:jonkstore/core/domain/models/sale_item.dart';
import 'package:jonkstore/core/domain/models/product.dart';
import 'package:jonkstore/core/domain/models/customer.dart';
import 'package:jonkstore/core/domain/enums/payment_method.dart';
import 'package:jonkstore/core/domain/enums/sync_status.dart';
import 'package:jonkstore/core/domain/enums/inventory_transaction_type.dart';
import 'package:jonkstore/core/domain/models/inventory_transaction.dart';
import 'package:jonkstore/repositories/sales_repository.dart';
import 'package:jonkstore/repositories/inventory_repository.dart';
import 'package:jonkstore/providers/repository_providers.dart';
import 'package:jonkstore/providers/auth_providers.dart';
import 'package:jonkstore/features/dashboard/providers/dashboard_providers.dart';

class CartItem {
  final Product product;
  final double quantity;

  CartItem({required this.product, required this.quantity});

  double get total => product.price * quantity;

  CartItem copyWith({double? quantity}) {
    return CartItem(
      product: product,
      quantity: quantity ?? this.quantity,
    );
  }
}

class SalesState {
  final List<CartItem> cart;
  final Customer? selectedCustomer;
  final bool isLoading;
  final String? errorMessage;
  final bool isSuccess;

  SalesState({
    this.cart = const [],
    this.selectedCustomer,
    this.isLoading = false,
    this.errorMessage,
    this.isSuccess = false,
  });

  double get subtotal => cart.fold(0, (sum, item) => sum + item.total);
  double get total => subtotal; // Simplified (tax/discount can be added later)

  SalesState copyWith({
    List<CartItem>? cart,
    Customer? selectedCustomer,
    bool? isLoading,
    String? errorMessage,
    bool? isSuccess,
  }) {
    return SalesState(
      cart: cart ?? this.cart,
      selectedCustomer: selectedCustomer ?? this.selectedCustomer,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

class SalesController extends StateNotifier<SalesState> {
  final SalesRepository _salesRepository;
  final InventoryRepository _inventoryRepository;
  final Ref _ref;

  SalesController(this._salesRepository, this._inventoryRepository, this._ref)
      : super(SalesState());

  void addToCart(Product product) {
    final index = state.cart.indexWhere((item) => item.product.id == product.id);
    if (index >= 0) {
      final updatedCart = List<CartItem>.from(state.cart);
      updatedCart[index] = updatedCart[index].copyWith(quantity: updatedCart[index].quantity + 1);
      state = state.copyWith(cart: updatedCart);
    } else {
      state = state.copyWith(cart: [...state.cart, CartItem(product: product, quantity: 1)]);
    }
  }

  void removeFromCart(String productId) {
    state = state.copyWith(
      cart: state.cart.where((item) => item.product.id != productId).toList(),
    );
  }

  void updateQuantity(String productId, double quantity) {
    if (quantity <= 0) {
      removeFromCart(productId);
      return;
    }
    final updatedCart = state.cart.map((item) {
      return item.product.id == productId ? item.copyWith(quantity: quantity) : item;
    }).toList();
    state = state.copyWith(cart: updatedCart);
  }

  void selectCustomer(Customer? customer) {
    state = state.copyWith(selectedCustomer: customer);
  }

  Future<void> checkout(PaymentMethod method) async {
    if (state.cart.isEmpty) return;

    state = state.copyWith(isLoading: true, errorMessage: null);

    final user = _ref.read(currentUserProvider);
    final business = await _ref.read(currentBusinessProvider.future);

    if (user == null || business == null) {
      state = state.copyWith(isLoading: false, errorMessage: 'Session error');
      return;
    }

    final saleId = const Uuid().v4();
    final now = DateTime.now();

    final sale = Sale(
      id: saleId,
      businessId: business.id,
      branchId: business.id, // Defaults to main for now
      userId: user.id,
      customerId: state.selectedCustomer?.id,
      subtotal: state.subtotal,
      taxAmount: 0,
      discountAmount: 0,
      totalAmount: state.total,
      receivedAmount: state.total,
      changeAmount: 0,
      paymentMethod: method,
      status: 'completed',
      createdAt: now,
      updatedAt: now,
      syncStatus: SyncStatus.pending,
    );

    final saleItems = state.cart.map((item) {
      return SaleItem(
        id: const Uuid().v4(),
        saleId: saleId,
        productId: item.product.id,
        productName: item.product.name,
        quantity: item.quantity,
        unitPrice: item.product.price,
        subtotal: item.total,
        taxAmount: 0,
        discountAmount: 0,
        totalAmount: item.total,
        createdAt: now,
        updatedAt: now,
        syncStatus: SyncStatus.pending,
      );
    }).toList();

    final result = await _salesRepository.createSale(sale, saleItems);

    result.fold(
      (success) async {
        // Update Inventory levels
        for (final item in state.cart) {
          if (item.product.trackInventory) {
            final invResult = await _inventoryRepository.findByProductId(item.product.id, business.id);
            invResult.fold((inv) async {
              if (inv != null) {
                final tx = InventoryTransaction(
                  id: const Uuid().v4(),
                  inventoryId: inv.id,
                  productId: item.product.id,
                  branchId: business.id,
                  quantityChange: -item.quantity,
                  previousQuantity: inv.quantity,
                  newQuantity: inv.quantity - item.quantity,
                  type: InventoryTransactionType.sale,
                  referenceId: saleId,
                  userId: user.id,
                  transactionDate: now,
                  createdAt: now,
                  updatedAt: now,
                  syncStatus: SyncStatus.pending,
                );
                await _inventoryRepository.recordTransaction(tx);
              }
            }, (f) => null);
          }
        }
        state = state.copyWith(isLoading: false, isSuccess: true, cart: []);
      },
      (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
      },
    );
  }

  void reset() {
    state = SalesState();
  }
}

final salesControllerProvider = StateNotifierProvider<SalesController, SalesState>((ref) {
  return SalesController(
    ref.watch(salesRepositoryProvider),
    ref.watch(inventoryRepositoryProvider),
    ref,
  );
});

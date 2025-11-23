import 'package:jolt_surge/jolt_surge.dart';
import '../models/cart_item.dart';
import '../models/product.dart';

class CartState {
  final List<CartItem> items;

  CartState({List<CartItem>? items}) : items = items ?? [];

  CartState copyWith({List<CartItem>? items}) {
    return CartState(items: items ?? this.items);
  }

  // Total quantity
  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);

  // Total price
  double get totalPrice =>
      items.fold(0.0, (sum, item) => sum + item.totalPrice);

  // Is empty
  bool get isEmpty => items.isEmpty;

  // Get quantity of product in cart
  int getQuantity(String productId) {
    try {
      final item = items.firstWhere(
        (item) => item.product.id == productId,
      );
      return item.quantity;
    } catch (e) {
      return 0;
    }
  }

  // Contains product
  bool contains(String productId) {
    return items.any((item) => item.product.id == productId);
  }
}

class CartSurge extends Surge<CartState> {
  CartSurge() : super(CartState());

  // Add product to cart
  void addProduct(Product product) {
    final currentItems = List<CartItem>.from(state.items);
    final existingIndex = currentItems.indexWhere(
      (item) => item.product.id == product.id,
    );

    if (existingIndex >= 0) {
      // If product exists, increment quantity
      final existingItem = currentItems[existingIndex];
      currentItems[existingIndex] = existingItem.copyWith(
        quantity: existingItem.quantity + 1,
      );
    } else {
      // If product doesn't exist, add new item
      currentItems.add(CartItem(product: product, quantity: 1));
    }

    emit(state.copyWith(items: currentItems));
  }

  // Remove product from cart
  void removeProduct(String productId) {
    final currentItems = List<CartItem>.from(state.items);
    currentItems.removeWhere((item) => item.product.id == productId);
    emit(state.copyWith(items: currentItems));
  }

  // Update product quantity
  void updateQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      removeProduct(productId);
      return;
    }

    final currentItems = List<CartItem>.from(state.items);
    final index = currentItems.indexWhere(
      (item) => item.product.id == productId,
    );

    if (index >= 0) {
      final item = currentItems[index];
      currentItems[index] = item.copyWith(quantity: quantity);
      emit(state.copyWith(items: currentItems));
    }
  }

  // Increment product quantity
  void incrementQuantity(String productId) {
    final currentItems = List<CartItem>.from(state.items);
    final index = currentItems.indexWhere(
      (item) => item.product.id == productId,
    );

    if (index >= 0) {
      final item = currentItems[index];
      currentItems[index] = item.copyWith(quantity: item.quantity + 1);
      emit(state.copyWith(items: currentItems));
    }
  }

  // Decrement product quantity
  void decrementQuantity(String productId) {
    final currentItems = List<CartItem>.from(state.items);
    final index = currentItems.indexWhere(
      (item) => item.product.id == productId,
    );

    if (index >= 0) {
      final item = currentItems[index];
      if (item.quantity > 1) {
        currentItems[index] = item.copyWith(quantity: item.quantity - 1);
      } else {
        currentItems.removeAt(index);
      }
      emit(state.copyWith(items: currentItems));
    }
  }

  // Clear cart
  void clear() {
    emit(CartState());
  }
}

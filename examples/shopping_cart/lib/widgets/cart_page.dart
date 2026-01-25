import 'package:flutter/material.dart';
import 'package:jolt_surge/jolt_surge.dart';
import '../surges/cart_surge.dart';
import 'cart_item_tile.dart';
import 'empty_cart.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping Cart'),
      ),
      body: SurgeBuilder<CartSurge, CartState>.full(
        builder: (context, cartState, surge) {
          if (cartState.isEmpty) {
            return const EmptyCart();
          }

          return Column(
            children: [
              // Cart item list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: cartState.items.length,
                  itemBuilder: (context, index) {
                    final item = cartState.items[index];
                    return CartItemTile(
                      item: item,
                      onRemove: () => surge.removeProduct(item.product.id),
                      onIncrement: () =>
                          surge.incrementQuantity(item.product.id),
                      onDecrement: () =>
                          surge.decrementQuantity(item.product.id),
                    );
                  },
                ),
              ),
              // Bottom total bar - Use SurgeSelector to only listen to total price changes
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SurgeSelector<CartSurge, CartState, double>.full(
                      selector: (state, _) => state.totalPrice,
                      builder: (context, totalPrice, _) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '\$${totalPrice.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => surge.clear(),
                            child: const Text('Clear Cart'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () {
                              // Navigate to checkout page
                              Navigator.of(context).pushNamed('/checkout');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text(
                              'Checkout',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

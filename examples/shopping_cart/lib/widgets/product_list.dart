import 'package:flutter/material.dart';
import 'package:jolt_surge/jolt_surge.dart';
import '../models/product.dart';
import '../surges/product_surge.dart';
import '../surges/cart_surge.dart';
import 'product_card.dart';
import 'cart_badge.dart';

class ProductList extends StatelessWidget {
  const ProductList({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          // Use SurgeSelector to only listen to cart item quantity changes
          SurgeSelector<CartSurge, CartState, int>.full(
            selector: (state, surge) => state.totalQuantity,
            builder: (context, quantity, _) => CartBadge(
              count: quantity,
              child: IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: () {
                  Navigator.of(context).pushNamed('/cart');
                },
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search box
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SurgeBuilder<ProductSurge, List<Product>>.full(
              builder: (context, products, surge) {
                return TextField(
                  decoration: InputDecoration(
                    hintText: 'Search products...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: products.length != surge.state.length
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => surge.resetSearch(),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) => surge.search(value),
                );
              },
            ),
          ),
          // Product list
          Expanded(
            child: SurgeBuilder<ProductSurge, List<Product>>.full(
              builder: (context, products, _) {
                if (products.isEmpty) {
                  return const Center(
                    child: Text('No products found'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    return ProductCard(product: products[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

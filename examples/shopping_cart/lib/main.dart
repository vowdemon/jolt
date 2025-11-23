import 'package:flutter/material.dart';
import 'package:jolt_surge/jolt_surge.dart';
import 'surges/product_surge.dart';
import 'surges/cart_surge.dart';
import 'widgets/product_list.dart';
import 'widgets/cart_page.dart';
import 'widgets/checkout_page.dart';

void main() {
  runApp(const ShoppingCartApp());
}

class ShoppingCartApp extends StatelessWidget {
  const ShoppingCartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return SurgeProvider<ProductSurge>(
      create: (_) => ProductSurge(),
      child: SurgeProvider<CartSurge>(
        create: (_) => CartSurge(),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Shopping Cart - Jolt Surge',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            useMaterial3: true,
          ),
          routes: {
            '/': (context) => const ProductList(),
            '/cart': (context) => const CartPage(),
            '/checkout': (context) => const CheckoutPage(),
          },
        ),
      ),
    );
  }
}

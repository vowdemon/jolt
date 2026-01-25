# Shopping Cart Example

A comprehensive e-commerce shopping cart application built with **Jolt Surge**, demonstrating advanced state management patterns, fine-grained reactivity, and multiple state containers working together.

## Overview

This example showcases a complete shopping experience with product browsing, cart management, and checkout flow. It demonstrates how Jolt Surge enables scalable, maintainable state management with precise control over UI rebuilds.

## Features

### Product Management
- Browse a catalog of products
- Search and filter products
- View product details and pricing

### Shopping Cart
- Add products to cart
- Adjust item quantities (increment/decrement)
- Remove items from cart
- Clear entire cart
- Real-time price and quantity calculations

### Performance Optimization
- **Fine-grained Rebuilds**: Uses `SurgeSelector` to rebuild only specific UI parts when relevant data changes
- **Selective Listening**: Cart badge only rebuilds when total quantity changes
- **Efficient Updates**: Product cards only update when their specific cart quantity changes

## Jolt Surge Concepts Demonstrated

### SurgeProvider

`SurgeProvider` provides Surge instances to the widget tree, enabling dependency injection and scoped state management.

```dart
SurgeProvider<ProductSurge>(
  create: (_) => ProductSurge(),
  child: SurgeProvider<CartSurge>(
    create: (_) => CartSurge(),
    child: MaterialApp(...),
  ),
)
```

### SurgeBuilder

`SurgeBuilder` rebuilds the widget tree when the Surge's state changes. It provides both the current state and the Surge instance.

```dart
SurgeBuilder<CartSurge, CartState>(
  builder: (context, cartState, surge) {
    return ListView.builder(
      itemCount: cartState.items.length,
      itemBuilder: (context, index) => ...,
    );
  },
)
```

### SurgeSelector

`SurgeSelector` enables fine-grained reactivity by rebuilding only when a selected value changes. This is crucial for performance optimization.

```dart
// Only rebuilds when totalQuantity changes
SurgeSelector<CartSurge, CartState, int>(
  selector: (state, _) => state.totalQuantity,
  builder: (context, quantity, _) => CartBadge(count: quantity),
)

// Only rebuilds when this specific product's quantity changes
SurgeSelector<CartSurge, CartState, int>(
  selector: (state, _) => state.getQuantity(product.id),
  builder: (context, quantity, _) => AddToCartButton(quantity: quantity),
)
```

### Surge State Management

Surges encapsulate business logic and state. They use `emit()` to update state, which automatically triggers UI updates.

```dart
class CartSurge extends Surge<CartState> {
  void addProduct(Product product) {
    // Business logic here
    emit(newState);
  }
}
```

## Architecture

### State Containers

- **ProductSurge**: Manages the product catalog and search functionality
- **CartSurge**: Handles all cart operations (add, remove, update quantities)

### Separation of Concerns

- **Models**: Data structures (`Product`, `CartItem`, `CartState`)
- **Surges**: Business logic and state management
- **Widgets**: Pure UI components that consume state

## Running the Example

```bash
cd examples/shopping_cart
flutter run
```

## Project Structure

```
lib/
├── models/              # Data models
│   ├── product.dart
│   ├── cart_item.dart
│   └── sample_products.dart
├── surges/              # State management (Surge classes)
│   ├── product_surge.dart
│   └── cart_surge.dart
├── widgets/             # UI components
│   ├── product_list.dart
│   ├── product_card.dart
│   ├── cart_page.dart
│   ├── cart_item_tile.dart
│   ├── cart_badge.dart
│   └── empty_cart.dart
└── main.dart            # Application entry point
```

## Key Learnings

1. **Multiple Surges**: How to manage multiple independent state containers
2. **Fine-grained Reactivity**: Using `SurgeSelector` to optimize performance
3. **State Encapsulation**: Business logic lives in Surge classes, not widgets
4. **Automatic Updates**: UI automatically reflects state changes without manual coordination
5. **Type Safety**: Full type safety with generics (`SurgeBuilder<CartSurge, CartState>`)

This example demonstrates production-ready patterns for building scalable Flutter applications with Jolt Surge.

import 'package:jolt_surge/jolt_surge.dart';
import '../models/product.dart';
import '../models/sample_products.dart';

class ProductSurge extends Surge<List<Product>> {
  ProductSurge() : super(sampleProducts);

  // Search products
  void search(String query) {
    if (query.isEmpty) {
      emit(sampleProducts);
      return;
    }

    final filtered = sampleProducts
        .where((product) =>
            product.name.toLowerCase().contains(query.toLowerCase()) ||
            product.description.toLowerCase().contains(query.toLowerCase()))
        .toList();

    emit(filtered);
  }

  // Reset search
  void resetSearch() {
    emit(sampleProducts);
  }
}

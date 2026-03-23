import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/product_controller.dart';
import '../../models/product.dart';
import 'widgets/product_grid_item.dart'; // ✅ Dùng widget hiển thị sản phẩm đã chuẩn hóa

class ProductListScreen extends StatelessWidget {
  const ProductListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ProductController()..fetch(),
      child: Consumer<ProductController>(
        builder: (context, vm, _) {
          if (vm.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (vm.products.isEmpty) {
            return const Center(child: Text('Chưa có sản phẩm'));
          }

          return Scaffold(
            appBar: AppBar(
              title: const Text('Product'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    // TODO: có thể mở search delegate sau
                  },
                ),
              ],
            ),
            body: GridView.builder(
              padding: const EdgeInsets.fromLTRB(
                12,
                12,
                12,
                120, // 👈 chừa đáy để không bị bottom bar che
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.68,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: vm.products.length,
              itemBuilder: (_, i) {
                final Product product = vm.products[i];
                return ProductGridItem(model: product); // ✅ tái sử dụng widget
              },
            ),
          );
        },
      ),
    );
  }
}

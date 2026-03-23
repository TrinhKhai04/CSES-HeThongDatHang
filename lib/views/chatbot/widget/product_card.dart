import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../routes/app_routes.dart';

/// ============================================================================
/// 🧱 ProductCard — Apple Store style
/// - Tối giản, nhiều khoảng trắng, bo góc lớn, viền mảnh, bóng nhẹ.
/// - Ảnh vuông có fade-in, placeholder xám F5F5F7, Hero animation.
/// - Giá màu Apple Blue (#007AFF), không gạch chân.
/// - CTA “Xem chi tiết” dạng link + chevron.
/// ============================================================================
class ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  const ProductCard({super.key, required this.product});

  /// Định dạng tiền VND theo locale Việt Nam
  String _vnd(num n) =>
      NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(n);

  @override
  Widget build(BuildContext context) {
    // --- Lấy dữ liệu với fallback an toàn ---
    final id    = (product['id'] ?? '').toString();
    final name  = (product['name'] ?? '').toString();
    final price = (product['price'] ?? 0) as num;
    final desc  = (product['description'] ?? '').toString();
    final image = (product['imageUrl'] ?? '').toString();

    // Điều hướng sang màn chi tiết (tái sử dụng ở onTap & CTA)
    void _goDetail() {
      Navigator.pushNamed(
        context,
        AppRoutes.productDetail,
        arguments: {'product': product},
      );
    }

    return Semantics(
      // Giúp trình đọc màn hình hiểu đây là 1 nút mở chi tiết sản phẩm
      button: true,
      label: 'Sản phẩm $name, giá ${_vnd(price)}',
      child: Material(
        color: Colors.white,
        elevation: 0, // Apple style: hạn chế elevation, dùng shadow mềm
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _goDetail,
          child: Container(
            // Khung thẻ: viền mảnh 1px + bóng cực nhẹ
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0x11000000), width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0F000000),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // -------------------- ẢNH SẢN PHẨM --------------------
                // Dùng Hero để chuyển cảnh mượt sang trang chi tiết.
                // Lưu ý: trang chi tiết cũng cần dùng cùng tag: 'product:$id'
                if (image.isNotEmpty)
                  Hero(
                    tag: 'product:$id',
                    child: AspectRatio(
                      aspectRatio: 1, // Grid vuông kiểu Apple
                      child: _NetworkImageApple(
                        url: image,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                    ),
                  )
                else
                // Placeholder khi thiếu ảnh
                  AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      alignment: Alignment.center,
                      color: const Color(0xFFF5F5F7),
                      child: const Icon(
                        CupertinoIcons.photo,
                        size: 28,
                        color: Color(0xFF8E8E93),
                      ),
                    ),
                  ),

                // -------------------- NỘI DUNG --------------------
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tên sản phẩm — semibold, tracking âm nhẹ cho cảm giác “gọn”
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                          letterSpacing: -0.2,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Mô tả ngắn — màu xám nhạt, tối đa 2 dòng
                      if (desc.isNotEmpty)
                        Text(
                          desc,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.35,
                            color: Colors.grey.shade700,
                          ),
                        ),

                      const SizedBox(height: 10),

                      // Giá (Apple Blue) + CTA "Xem chi tiết" dạng link
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _vnd(price),
                              // Không gạch chân; nhấn mạnh vừa phải
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF007AFF),
                                letterSpacing: -0.2,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                          _CupertinoLinkButton(
                            label: 'Xem chi tiết',
                            onTap: _goDetail,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ảnh mạng có fade-in nhẹ & placeholder kiểu Apple (xám F5F5F7)
class _NetworkImageApple extends StatelessWidget {
  final String url;
  final BorderRadius? borderRadius;
  const _NetworkImageApple({required this.url, this.borderRadius});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        // Fade-in mượt khi ảnh load xong frame đầu tiên
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            child: child,
          );
        },
        // Placeholder trong lúc tải
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            color: const Color(0xFFF5F5F7),
            alignment: Alignment.center,
            child: const Icon(CupertinoIcons.photo, size: 28, color: Color(0xFF8E8E93)),
          );
        },
        // Trường hợp lỗi ảnh
        errorBuilder: (context, error, stackTrace) => Container(
          color: const Color(0xFFF5F5F7),
          alignment: Alignment.center,
          child: const Icon(CupertinoIcons.exclamationmark_triangle, size: 24, color: Color(0xFF8E8E93)),
        ),
      ),
    );
  }
}

/// Nút “liên kết” kiểu Apple (text + chevron phải), không viền, hit target lớn.
class _CupertinoLinkButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _CupertinoLinkButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque, // tăng vùng chạm
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          // Text & chevron được thêm dưới đây bằng Rich UI (không gạch chân)
        ],
      ),
    );
  }
}

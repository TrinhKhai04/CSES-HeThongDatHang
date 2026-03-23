import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

import '../../controllers/admin_product_controller.dart';
import '../../controllers/cart_controller.dart';
import '../../models/product.dart';
import '../../routes/app_routes.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key});
  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  String? _productId;
  Map<String, dynamic>? product;
  List<Map<String, dynamic>> variants = [];

  String? selSize;
  String? selColor;
  int _qty = 1;

  int _currentImg = 0;
  bool _descExpanded = false;
  final PageController _pageCtl = PageController();

  final _fmtVND =
  NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

  int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  double _asDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  String _asString(dynamic v) => v?.toString() ?? '';

  List<String> _asImageList(dynamic v) {
    final out = <String>[];
    if (v is List) {
      for (final e in v) {
        if (e is String && e.isNotEmpty) out.add(e);
        if (e is Map && e['url'] != null) {
          final s = e['url'].toString();
          if (s.isNotEmpty) out.add(s);
        }
      }
    }
    return out;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments;

    // Chỉ xử lý lần đầu
    if (_productId != null) return;

    // Trường hợp cũ: chỉ truyền String productId
    if (args is String) {
      _productId = args;
      _load(args);
      return;
    }

    // Trường hợp mới: truyền Map { productId, product }
    if (args is Map) {
      final pid = args['productId'];
      if (pid is String) {
        _productId = pid;
      }

      final rawProduct = args['product'];

      // Nếu truyền object Product thì convert sang Map cho màn detail dùng
      if (rawProduct is Product) {
        product = {
          'id': rawProduct.id,
          'name': rawProduct.name,
          'price': rawProduct.price,
          'imageUrl': rawProduct.imageUrl,
          'description': rawProduct.description,
          'compareAtPrice': null,
          'stock': null,
          'images': const <String>[],
        };
      } else if (rawProduct is Map<String, dynamic>) {
        product = Map<String, dynamic>.from(rawProduct);
      }

      // Nếu đã có product từ arguments thì setState để vẽ ngay,
      // đồng thời nếu có _productId thì load thêm chi tiết/variants để cập nhật sau.
      if (product != null && product!.isNotEmpty) {
        setState(() {});
        if (_productId != null) {
          _load(_productId!);
        }
      } else if (_productId != null) {
        // Không có product truyền kèm -> vẫn fallback load bằng id như cũ
        _load(_productId!);
      }
    }
  }

  Future<void> _load(String productId) async {
    final c = context.read<AdminProductController>();
    try {
      final p = await c.getProductById(productId);
      final v = await c.getVariants(productId);

      if (!mounted) return;
      setState(() {
        // Nếu trước đó đã có product từ arguments thì merge thêm dữ liệu mới
        if (p != null) {
          product = {
            ...(product ?? {}),
            ...p,
          };
        } else {
          product ??= {};
        }

        variants = v.whereType<Map<String, dynamic>>().toList();

        final sizes = _sizes();
        if (sizes.isNotEmpty) {
          selSize ??= sizes.first;
          final cs = _colorsForSize(selSize);
          selColor ??= cs.isNotEmpty ? cs.first : null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không tải được sản phẩm: $e')),
      );
    }
  }

  List<String> _sizes() {
    final set = <String>{};
    for (final v in variants) {
      final s = _asString(v['size']);
      if (s.isNotEmpty) set.add(s);
    }
    return set.toList();
  }

  List<String> _colorsForSize(String? size) {
    final set = <String>{};
    for (final v in variants) {
      if (_asString(v['size']) == (size ?? '')) {
        final c = _asString(v['color']);
        if (c.isNotEmpty) set.add(c);
      }
    }
    return set.toList();
  }

  Map<String, dynamic>? _selectedVariant() {
    for (final v in variants) {
      if (_asString(v['size']) == (selSize ?? '') &&
          _asString(v['color']) == (selColor ?? '')) {
        return v;
      }
    }
    return null;
  }

  bool _hasStockForSize(String size) {
    for (final v in variants) {
      if (_asString(v['size']) == size && _asInt(v['stock']) > 0) {
        return true;
      }
    }
    return false;
  }

  int _stockForSizeColor(String? size, String? color) {
    for (final v in variants) {
      if (_asString(v['size']) == (size ?? '') &&
          _asString(v['color']) == (color ?? '')) {
        return _asInt(v['stock']);
      }
    }
    return 0;
  }

  List<String> _imagesForProduct() {
    final imgs = <String>[];
    final varUrl = _asString(_selectedVariant()?['imageUrl']);
    if (varUrl.isNotEmpty) imgs.add(varUrl);
    imgs.addAll(_asImageList(product?['images']));
    final base = _asString(product?['imageUrl']);
    if (base.isNotEmpty) imgs.add(base);
    return imgs.toSet().toList();
  }

  Future<bool> _canReviewProduct() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _productId == null) return false;

    final marker = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('purchases')
        .doc(_productId)
        .get();
    if (marker.exists) return true;

    final q = await FirebaseFirestore.instance
        .collection('orders')
        .where('userId', isEqualTo: uid)
        .where('status', whereIn: ['delivered', 'completed'])
        .where('itemsProductIds', arrayContains: _productId)
        .limit(1)
        .get();
    return q.docs.isNotEmpty;
  }

  Future<bool> _hasReviewedBefore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _productId == null) return false;

    final q = await FirebaseFirestore.instance
        .collection('products')
        .doc(_productId)
        .collection('reviews')
        .doc(uid)
        .get();
    return q.exists;
  }

  Future<void> _writeReviewDoc(Map<String, dynamic> result) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final displayName =
        FirebaseAuth.instance.currentUser?.displayName ?? 'Người dùng';
    if (uid == null || _productId == null) return;

    final reviewRef = FirebaseFirestore.instance
        .collection('products')
        .doc(_productId)
        .collection('reviews')
        .doc(uid);

    await reviewRef.set({
      'userId': uid,
      'userName': displayName,
      'productId': _productId,
      'rating': result['rating'],
      'comment': result['comment'],
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: false));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final media = MediaQuery.of(context);
    final double clampedScale =
    media.textScaler.scale(1.0).clamp(1.0, 1.20);
    final mq =
    media.copyWith(textScaler: TextScaler.linear(clampedScale));

    if (product == null || product!.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final name = _asString(product!['name']).isEmpty
        ? 'Sản phẩm'
        : _asString(product!['name']);
    final basePrice = _asDouble(product!['price']);
    final selected = _selectedVariant();
    final price = _asDouble(selected?['price'] ?? basePrice);
    final compareAt = _asDouble(
        selected?['compareAtPrice'] ?? product!['compareAtPrice']);
    final onSale = compareAt > 0 && compareAt > price;

    final rawStock = selected?['stock'] ?? product!['stock'] ?? 0;
    final stock = _asInt(rawStock);
    final inStock = stock > 0;

    // 🔹 ĐÃ BÁN
    final int soldCount = _asInt(product!['soldCount']);

    // 🔹 Trạng thái bán / tạm ẩn
    final String status = _asString(product!['status'] ?? 'active');
    final bool isInactive = status == 'inactive';

    // Có cho phép thêm vào giỏ không?
    final variantId = _asString(selected?['id'] ?? selected?['variantId']);
    final cart = context.watch<CartController>();
    final currentInCart = cart.quantityOfVariant(variantId);
    final bool canAddToCart = inStock && !isInactive;
    final maxAddable =
    canAddToCart ? (stock - currentInCart).clamp(0, stock) : 0;

    final sizes = _sizes();
    final colors = _colorsForSize(selSize);
    final imgs = _imagesForProduct();

    return MediaQuery(
      data: mq,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverLayoutBuilder(
              builder: (context, constraints) {
                const double _expandedHeight = 320;
                final bool collapsed =
                    constraints.scrollOffset >
                        (_expandedHeight - kToolbarHeight - 12);

                return SliverAppBar(
                  pinned: true,
                  expandedHeight: _expandedHeight,
                  backgroundColor: cs.surface,
                  systemOverlayStyle: SystemUiOverlayStyle.dark,
                  title: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: collapsed ? 1 : 0,
                    child: Text(name, overflow: TextOverflow.ellipsis),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    cs.surface.withValues(alpha: .95),
                                    cs.surface.withValues(alpha: .70),
                                    cs.surface.withValues(alpha: .40),
                                  ],
                                ),
                              ),
                            ),
                            Center(
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: cs.surface,
                                      borderRadius:
                                      BorderRadius.circular(22),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withOpacity(.10),
                                          blurRadius: 22,
                                          spreadRadius: 2,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius:
                                      BorderRadius.circular(22),
                                      child: PageView.builder(
                                        controller: _pageCtl,
                                        itemCount:
                                        math.max(1, imgs.length),
                                        onPageChanged: (i) async {
                                          setState(
                                                  () => _currentImg = i);
                                          final next = i + 1;
                                          if (next < imgs.length &&
                                              imgs[next]
                                                  .startsWith('http')) {
                                            precacheImage(
                                              NetworkImage(_transformUrl(
                                                  imgs[next])),
                                              context,
                                            );
                                          }
                                        },
                                        itemBuilder: (_, i) {
                                          if (imgs.isEmpty) {
                                            return _placeholderImage(cs);
                                          }
                                          final url = imgs[i];

                                          Widget img;
                                          if (url.startsWith('http')) {
                                            img = Image.network(
                                              _transformUrl(url),
                                              fit: BoxFit.contain,
                                              gaplessPlayback: true,
                                              filterQuality:
                                              FilterQuality.high,
                                              loadingBuilder:
                                                  (c, child, p) {
                                                if (p == null) {
                                                  return child;
                                                }
                                                final v = (p
                                                    .expectedTotalBytes !=
                                                    null)
                                                    ? p.cumulativeBytesLoaded /
                                                    (p.expectedTotalBytes ??
                                                        1)
                                                    : null;
                                                return Center(
                                                  child:
                                                  CircularProgressIndicator(
                                                      value: v),
                                                );
                                              },
                                              errorBuilder: (_, __, ___) =>
                                                  _placeholderImage(cs),
                                            );
                                          } else {
                                            final path = url.startsWith(
                                                'file://')
                                                ? Uri.parse(url)
                                                .toFilePath()
                                                : url;
                                            final f = File(path);
                                            img = f.existsSync()
                                                ? Image.file(
                                              f,
                                              fit: BoxFit.contain,
                                              filterQuality:
                                              FilterQuality
                                                  .high,
                                            )
                                                : _placeholderImage(cs);
                                          }

                                          if (i == 0 &&
                                              _productId != null) {
                                            img = Hero(
                                              tag:
                                              'product:${_productId!}',
                                              child: img,
                                            );
                                          }

                                          return GestureDetector(
                                            onTap: () =>
                                                _openFullScreenGallery(
                                                  imgs,
                                                  initialIndex: i,
                                                ),
                                            child: img,
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (imgs.length > 1)
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 8,
                                child: Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.center,
                                  children: List.generate(imgs.length, (i) {
                                    final active =
                                        i == _currentImg % imgs.length;
                                    return AnimatedContainer(
                                      duration: const Duration(
                                          milliseconds: 240),
                                      margin:
                                      const EdgeInsets.symmetric(
                                          horizontal: 3.5),
                                      width: active ? 20 : 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: active
                                            ? Colors.white
                                            : Colors.white
                                            .withOpacity(.35),
                                        borderRadius:
                                        BorderRadius.circular(4),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // ---------- Nội dung ----------
            SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16)),
                ),
                padding:
                const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                          fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),

                    onSale
                        ? Row(
                      children: [
                        Text(
                          _fmtVND.format(price),
                          semanticsLabel:
                          'Giá ${_fmtVND.format(price)}',
                          style: TextStyle(
                            color: cs.primary,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _fmtVND.format(compareAt),
                          style: const TextStyle(
                            decoration:
                            TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    )
                        : Text(
                      _fmtVND.format(price),
                      semanticsLabel:
                      'Giá ${_fmtVND.format(price)}',
                      style: TextStyle(
                        color: cs.primary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 4),

                    if (isInactive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius:
                          BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Sản phẩm tạm ẩn - không mở bán',
                          style: TextStyle(
                            color: cs.error,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),

                    const SizedBox(height: 10),

                    if (_asString(product!['description'])
                        .isNotEmpty)
                      Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            _asString(
                                product!['description']),
                            maxLines:
                            _descExpanded ? null : 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          TextButton(
                            onPressed: () => setState(
                                    () => _descExpanded =
                                !_descExpanded),
                            child: Text(_descExpanded
                                ? 'Thu gọn'
                                : 'Xem thêm'),
                          ),
                        ],
                      ),

                    if (sizes.isNotEmpty) ...[
                      const _SectionLabel('Size'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: sizes.map((s) {
                          final isSelected = s == selSize;
                          final enabled =
                          _hasStockForSize(s);
                          return ChoiceChip(
                            label: Text(s),
                            selected: isSelected,
                            onSelected: enabled
                                ? (_) {
                              setState(() {
                                selSize = s;
                                final newColors =
                                _colorsForSize(
                                    selSize);
                                if (!newColors
                                    .contains(
                                    selColor)) {
                                  selColor = newColors
                                      .isNotEmpty
                                      ? newColors.first
                                      : null;
                                }
                                _qty = _qty.clamp(
                                    1, maxAddable);
                              });
                            }
                                : null,
                          );
                        }).toList(),
                      ),
                    ],

                    if (colors.isNotEmpty) ...[
                      const _SectionLabel('Màu'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: colors.map((c) {
                          final isSelected = c == selColor;
                          final remain =
                          _stockForSizeColor(
                              selSize, c);
                          final enabled = remain > 0;
                          return ChoiceChip(
                            label: Text(c),
                            selected: isSelected,
                            onSelected: enabled
                                ? (_) {
                              setState(() {
                                selColor = c;
                                _qty = _qty.clamp(
                                    1, maxAddable);
                              });
                            }
                                : null,
                          );
                        }).toList(),
                      ),
                    ],

                    const SizedBox(height: 10),

                    // 🔹 Thông tin tồn kho + đã bán: 2 pill tách riêng
                    Row(
                      children: [
                        // Pill tồn kho / trạng thái
                            () {
                          Color stockBg;
                          Color stockFg;
                          String stockText;

                          if (isInactive) {
                            stockBg =
                                cs.surfaceContainerHighest;
                            stockFg = cs.onSurfaceVariant;
                            stockText = 'Tạm ẩn';
                          } else if (inStock) {
                            stockBg =
                                cs.secondaryContainer;
                            stockFg =
                                cs.onSecondaryContainer;
                            stockText = currentInCart > 0
                                ? 'Còn: $stock (trong giỏ: $currentInCart)'
                                : 'Còn: $stock';
                          } else {
                            stockBg = cs.errorContainer;
                            stockFg =
                                cs.onErrorContainer;
                            stockText = 'Hết hàng';
                          }

                          return Container(
                            padding: const EdgeInsets
                                .symmetric(
                                horizontal: 12,
                                vertical: 6),
                            decoration: BoxDecoration(
                              color: stockBg,
                              borderRadius:
                              BorderRadius.circular(
                                  999),
                            ),
                            child: Text(
                              stockText,
                              style: TextStyle(
                                color: stockFg,
                                fontWeight:
                                FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          );
                        }(),

                        const SizedBox(width: 8),

                        // Pill đã bán
                        if (soldCount > 0)
                          Container(
                            padding: const EdgeInsets
                                .symmetric(
                                horizontal: 12,
                                vertical: 6),
                            decoration: BoxDecoration(
                              color:
                              cs.surfaceContainerHighest,
                              borderRadius:
                              BorderRadius.circular(
                                  999),
                            ),
                            child: Text(
                              'Đã bán: $soldCount',
                              style: TextStyle(
                                color:
                                cs.onSurfaceVariant,
                                fontWeight:
                                FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    const _SectionLabel(
                        'Đánh giá & Bình luận'),

                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('products')
                          .doc(_productId)
                          .collection('reviews')
                          .orderBy('createdAt',
                          descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child:
                            CircularProgressIndicator(),
                          );
                        }

                        final docs =
                            snapshot.data?.docs ?? [];
                        final total = docs.length;
                        final counts =
                        List<int>.filled(6, 0);
                        int sum = 0;
                        for (final d in docs) {
                          final data = d.data()
                          as Map<String, dynamic>;
                          final r = _asInt(
                              data['rating'])
                              .clamp(1, 5);
                          counts[r] += 1;
                          sum += r;
                        }
                        final avg = total == 0
                            ? 0.0
                            : (sum / total);

                        if (total == 0) {
                          return Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: const [
                              _RatingSummary(
                                  avg: 0,
                                  total: 0,
                                  counts: [
                                    0,
                                    0,
                                    0,
                                    0,
                                    0
                                  ]),
                              SizedBox(height: 8),
                              Text(
                                  'Chưa có đánh giá nào.'),
                            ],
                          );
                        }

                        return Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            _RatingSummary(
                              avg: avg,
                              total: total,
                              counts: [
                                counts[5],
                                counts[4],
                                counts[3],
                                counts[2],
                                counts[1],
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...docs.map((d) {
                              final data = d.data()
                              as Map<String, dynamic>;
                              final user = (data['userName'] ??
                                  'Ẩn danh')
                                  .toString();
                              final rating = _asInt(
                                  data['rating'])
                                  .clamp(1, 5);
                              final comment = (data[
                              'comment'] ??
                                  '')
                                  .toString();
                              final createdAt =
                              (data['createdAt']
                              as Timestamp?)
                                  ?.toDate();

                              return _ReviewTileApple(
                                userName: user,
                                rating: rating,
                                comment: comment,
                                date: createdAt == null
                                    ? null
                                    : DateFormat(
                                    'dd/MM/yyyy')
                                    .format(
                                    createdAt),
                              );
                            }),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 8),
                    Builder(builder: (context) {
                      final uid = FirebaseAuth
                          .instance
                          .currentUser
                          ?.uid;
                      if (uid == null) {
                        return Text(
                          'Hãy đăng nhập để đánh giá sản phẩm.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        );
                      }
                      return FutureBuilder<bool>(
                        future: _canReviewProduct(),
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {      // ✅ dùng snap
                            return const Center(
                              child: CircularProgressIndicator(strokeWidth: 1.5),
                            );
                          }
                          final canReview =
                              snap.data == true;
                          if (!canReview) {
                            return Text(
                              'Chỉ khách đã mua hàng mới có thể đánh giá sản phẩm này.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                color: Theme.of(
                                    context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            );
                          }

                          return Center(
                            child: TextButton.icon(
                              icon: const Icon(Icons
                                  .edit_outlined),
                              label: const Text(
                                  'Viết đánh giá'),
                              onPressed: () async {
                                if (await _hasReviewedBefore()) {
                                  ScaffoldMessenger.of(
                                      context)
                                      .showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Bạn đã đánh giá sản phẩm này rồi.'),
                                    ),
                                  );
                                  return;
                                }
                                final prevSize =
                                    selSize;
                                final prevColor =
                                    selColor;
                                final prevQty =
                                    _qty;

                                final result =
                                await showDialog<
                                    Map<String,
                                        dynamic>>(
                                  context: context,
                                  builder: (_) =>
                                  const _ReviewDialog(),
                                );

                                if (result != null) {
                                  await _writeReviewDoc(
                                      result);
                                  if (mounted) {
                                    ScaffoldMessenger
                                        .of(context)
                                        .showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Cảm ơn bạn đã đánh giá!'),
                                      ),
                                    );
                                  }
                                }

                                if (mounted) {
                                  setState(() {
                                    selSize =
                                        prevSize;
                                    selColor =
                                        prevColor;
                                    _qty = prevQty
                                        .clamp(1,
                                        maxAddable);
                                  });
                                }
                              },
                            ),
                          );
                        },
                      );
                    }),

                    const SizedBox(height: 96),
                  ],
                ),
              ),
            ),
          ],
        ),

        bottomNavigationBar: SafeArea(
          minimum:
          const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Row(
            children: [
              _QtyStepper(
                qty: _qty,
                onDec: canAddToCart
                    ? () => setState(() {
                  final cap = math.max(
                      1,
                      maxAddable == 0
                          ? 1
                          : maxAddable);
                  _qty = (_qty - 1)
                      .clamp(1, cap);
                })
                    : null,
                onInc: canAddToCart
                    ? () {
                  final cap =
                  (maxAddable > 0)
                      ? maxAddable
                      : stock;
                  final next = _qty + 1;
                  if (next <= cap) {
                    setState(
                            () => _qty = next);
                  } else {
                    ScaffoldMessenger.of(
                        context)
                        .showSnackBar(
                      SnackBar(
                        content: Text(
                          maxAddable > 0
                              ? 'Bạn chỉ có thể thêm tối đa $maxAddable sản phẩm (đã có $currentInCart trong giỏ).'
                              : 'Đã đạt số lượng tối đa có thể thêm.',
                        ),
                      ),
                    );
                  }
                }
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: canAddToCart
                    ? ElevatedButton.icon(
                  icon: const Icon(Icons
                      .add_shopping_cart_rounded),
                  label:
                  const Text('Thêm vào giỏ'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor:
                    Colors.white,
                  ),
                  onPressed: () {
                    if (variants.isNotEmpty &&
                        (selSize == null ||
                            selColor == null ||
                            _selectedVariant() ==
                                null)) {
                      ScaffoldMessenger.of(
                          context)
                          .showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Vui lòng chọn Size và Màu'),
                        ),
                      );
                      return;
                    }

                    if (maxAddable <= 0) {
                      ScaffoldMessenger.of(
                          context)
                          .showSnackBar(
                        SnackBar(
                          content: Text(
                            currentInCart > 0
                                ? 'Bạn đã có $currentInCart trong giỏ. Chỉ còn $stock sản phẩm.'
                                : 'Sản phẩm tạm hết số lượng có thể thêm.',
                          ),
                        ),
                      );
                      return;
                    }

                    final p = Product(
                      id: _productId!,
                      name: name,
                      price: basePrice,
                      imageUrl:
                      _asString(product![
                      'imageUrl']),
                    );

                    final toAdd = _qty
                        .clamp(1, maxAddable);

                    context
                        .read<CartController>()
                        .addCustomized(
                      product: p,
                      qty: toAdd,
                      price: _asDouble(
                          _selectedVariant()?[
                          'price'] ??
                              product![
                              'price']),
                      variantId:
                      variantId.isEmpty
                          ? null
                          : variantId,
                      options: {
                        if (selSize != null)
                          'size': selSize!,
                        if (selColor != null)
                          'color':
                          selColor!,
                      },
                      stock: stock,
                    );

                    ScaffoldMessenger.of(
                        context)
                        .showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Đã thêm vào giỏ hàng')),
                    );

                    Navigator
                        .pushNamedAndRemoveUntil(
                      context,
                      AppRoutes.root,
                          (route) => false,
                      arguments: {'tab': 3},
                    );
                  },
                )
                    : isInactive
                    ? OutlinedButton.icon(
                  icon: const Icon(
                      Icons.block_outlined),
                  label: const Text(
                      'Sản phẩm tạm ẩn'),
                  onPressed: () {
                    ScaffoldMessenger.of(
                        context)
                        .showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Sản phẩm này đang tạm ẩn và không thể mua.'),
                      ),
                    );
                  },
                )
                    : OutlinedButton.icon(
                  icon: const Icon(Icons
                      .notifications_active_outlined),
                  label: const Text(
                      'Thông báo khi có hàng'),
                  onPressed: () {
                    ScaffoldMessenger.of(
                        context)
                        .showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Đã ghi nhận. Chúng tôi sẽ báo khi có hàng!'),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _transformUrl(String url) {
    if (!url.contains('res.cloudinary.com')) return url;
    return url.replaceFirst(
        '/upload/', '/upload/f_auto,q_auto,dpr_auto,w_1080/');
  }

  void _openFullScreenGallery(List<String> imgs,
      {int initialIndex = 0}) {
    final controller =
    PageController(initialPage: initialIndex);
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(.95),
      builder: (_) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.pop(context),
          child: Stack(
            children: [
              PageView.builder(
                controller: controller,
                itemCount: imgs.length,
                itemBuilder: (_, i) {
                  final url = imgs[i];
                  final provider = url.startsWith('http')
                      ? NetworkImage(_transformUrl(url))
                      : FileImage(
                    File(
                      url.startsWith('file://')
                          ? Uri.parse(url)
                          .toFilePath()
                          : url,
                    ),
                  ) as ImageProvider;

                  return Center(
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: Hero(
                        tag: 'product:${_productId!}-$i',
                        child: Image(
                          image: provider,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  );
                },
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Đóng',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _placeholderImage(ColorScheme cs) => Container(
    color: cs.surfaceContainerHighest,
    child: Icon(Icons.image_outlined,
        size: 80, color: cs.onSurfaceVariant),
  );
}

// ===== Widgets phụ =====

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: cs.onSurface,
        ),
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  final int qty;
  final VoidCallback? onDec;
  final VoidCallback? onInc;
  const _QtyStepper({required this.qty, this.onDec, this.onInc});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          IconButton(onPressed: onDec, icon: const Icon(Icons.remove)),
          Text('$qty',
              style:
              const TextStyle(fontWeight: FontWeight.bold)),
          IconButton(onPressed: onInc, icon: const Icon(Icons.add)),
        ],
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  final int rating;
  final double size;
  const _StarRow({required this.rating, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
            (i) => Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Icon(
            Icons.star_rounded,
            size: size,
            color: i < rating
                ? const Color(0xFFFFC107)
                : Colors.grey.shade300,
          ),
        ),
      ),
    );
  }
}

class _RatingSummary extends StatelessWidget {
  final double avg;
  final int total;
  final List<int> counts;

  const _RatingSummary({
    required this.avg,
    required this.total,
    required this.counts,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxCount =
    (counts.isEmpty ? 0 : counts.reduce((a, b) => a > b ? a : b));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  avg.toStringAsFixed(1),
                  style: Theme.of(context)
                      .textTheme
                      .displaySmall
                      ?.copyWith(
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                _StarRow(rating: avg.round(), size: 18),
                const SizedBox(height: 6),
                Text(
                  '$total lượt đánh giá',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: List.generate(5, (index) {
                final star = 5 - index;
                final c = counts[index];
                final ratio = (maxCount == 0)
                    ? 0.0
                    : c / maxCount;
                return Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 3),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        child: Text(
                          '$star',
                          style: const TextStyle(
                              fontWeight:
                              FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.star_rounded,
                          size: 14,
                          color:
                          Color(0xFFFFC107)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius:
                          BorderRadius.circular(
                              99),
                          child:
                          LinearProgressIndicator(
                            value: ratio,
                            minHeight: 8,
                            backgroundColor:
                            Theme.of(context)
                                .colorScheme
                                .surface,
                            valueColor:
                            AlwaysStoppedAnimation<
                                Color>(
                              Theme.of(context)
                                  .colorScheme
                                  .primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 32,
                        child: Text(
                          '$c',
                          textAlign:
                          TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewTileApple extends StatelessWidget {
  final String userName;
  final int rating;
  final String comment;
  final String? date;

  const _ReviewTileApple({
    required this.userName,
    required this.rating,
    required this.comment,
    this.date,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding:
      const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor:
            cs.surfaceContainerHighest,
            child: Text(
              userName.isNotEmpty
                  ? userName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                  fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        userName,
                        style: const TextStyle(
                          fontWeight:
                          FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    _StarRow(
                        rating: rating, size: 16),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding:
                  const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10),
                  decoration: BoxDecoration(
                    color: cs
                        .surfaceContainerHighest,
                    borderRadius:
                    BorderRadius.circular(
                        12),
                  ),
                  child: Text(
                    comment,
                    style: TextStyle(
                      color: cs.onSurface,
                      height: 1.3,
                    ),
                  ),
                ),
                if (date != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    date!,
                    style: TextStyle(
                      color:
                      cs.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog();
  @override
  State<_ReviewDialog> createState() =>
      _ReviewDialogState();
}

class _ReviewDialogState
    extends State<_ReviewDialog> {
  int _rating = 5;
  final _ctl = TextEditingController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Đánh giá sản phẩm'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment:
            MainAxisAlignment.center,
            children: List.generate(
              5,
                  (i) => IconButton(
                onPressed: () =>
                    setState(() => _rating = i + 1),
                icon: Icon(
                  Icons.star_rounded,
                  color: i < _rating
                      ? const Color(0xFFFFC107)
                      : cs.outlineVariant,
                ),
              ),
            ),
          ),
          TextField(
            controller: _ctl,
            decoration:
            const InputDecoration(
              hintText:
              'Hãy chia sẻ cảm nhận của bạn...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy')),
        ElevatedButton(
          onPressed: () {
            if (_ctl.text.trim().isEmpty) return;
            Navigator.pop(context, {
              'rating': _rating,
              'comment': _ctl.text.trim(),
            });
          },
          child: const Text('Gửi'),
        ),
      ],
    );
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../vendor_providers.dart';

const _primaryDark = Color(0xFF064E3B);
const _accentGold = Color(0xFFD4AF37);
const _bgOffWhite = Color(0xFFF8FAF9);

class GenericCatalogView extends ConsumerWidget {
  const GenericCatalogView({super.key});

  Future<String?> _uploadSingleImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return null;

    try {
      final bytes = await image.readAsBytes();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.cloudinary.com/v1_1/isuedugk/image/upload'),
      );
      request.fields['upload_preset'] = 'shadi_sphere_uploads';
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: image.name));

      final response = await request.send();
      final responseData = await response.stream.toBytes();
      final jsonMap = jsonDecode(String.fromCharCodes(responseData));

      if (response.statusCode == 200) {
        return jsonMap['secure_url'];
      }
    } catch (e) {
      print('Error uploading image: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(vendorProfileProvider);
    final products = profile.singleProducts;
    final packages = profile.servicePackages;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 600;
              
              final header = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Catalog & Inventory', style: TextStyle(fontSize: isSmall ? 24 : 28, fontWeight: FontWeight.bold, color: _primaryDark, fontFamily: 'PlayfairDisplay')),
                  SizedBox(height: isSmall ? 4 : 8),
                  Text('${products.length} product(s) and ${packages.length} package(s) listed', style: TextStyle(fontSize: isSmall ? 14 : 15, color: Colors.grey)),
                ],
              );
              
              final buttons = Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showAddProductDialog(context, ref, profile),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Product', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                      style: ElevatedButton.styleFrom(backgroundColor: _primaryDark, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showAddPackageDialog(context, ref, profile),
                      icon: const Icon(Icons.add_box, size: 18),
                      label: const Text('Add Package', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                      style: ElevatedButton.styleFrom(backgroundColor: _accentGold, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                ],
              );

              if (isSmall) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    header,
                    const SizedBox(height: 16),
                    buttons,
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: header),
                  const SizedBox(width: 24),
                  SizedBox(width: 350, child: buttons),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          if (products.isEmpty && packages.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    const Text('Your catalog is empty', style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    const Text('Click "Add Product" or "Add Package" to start listing your services.', style: TextStyle(fontSize: 14, color: Colors.grey)),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: CustomScrollView(
                slivers: [
                  if (products.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 16.0),
                        child: Text('Individual Products / Services', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _primaryDark, fontFamily: 'PlayfairDisplay')),
                      ),
                    ),
                    SliverGrid(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 400,
                        mainAxisExtent: 300,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final prod = products[index];
                          return _buildProductCard(context, ref, profile, prod);
                        },
                        childCount: products.length,
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  ],
                  if (packages.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 16.0),
                        child: Text('Bundled Service Packages', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _primaryDark, fontFamily: 'PlayfairDisplay')),
                      ),
                    ),
                    SliverGrid(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 400,
                        mainAxisExtent: 300,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final pkg = packages[index];
                          return _buildPackageCard(context, ref, profile, pkg);
                        },
                        childCount: packages.length,
                      ),
                    ),
                  ]
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, WidgetRef ref, VendorProfile profile, GenericSingleProduct prod) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              image: prod.imageUrl.isNotEmpty ? DecorationImage(image: NetworkImage(prod.imageUrl), fit: BoxFit.cover) : null,
            ),
            child: prod.imageUrl.isEmpty ? Center(child: Icon(Icons.image_outlined, size: 40, color: Colors.grey.shade400)) : null,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(prod.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _primaryDark), overflow: TextOverflow.ellipsis)),
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                        onSelected: (action) {
                          if (action == 'edit') {
                            _showAddProductDialog(context, ref, profile, existing: prod);
                          } else if (action == 'delete') {
                            _showDeleteProductConfirm(context, ref, profile, prod);
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18, color: _primaryDark), SizedBox(width: 8), Text('Edit')])),
                          const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Rs. ${prod.price.toStringAsFixed(0)}', style: const TextStyle(color: _primaryDark, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 6),
                  Expanded(child: Text(prod.description, style: const TextStyle(color: Colors.grey, fontSize: 13), maxLines: 3, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageCard(BuildContext context, WidgetRef ref, VendorProfile profile, GenericServicePackage pkg) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              image: pkg.imageUrl.isNotEmpty ? DecorationImage(image: NetworkImage(pkg.imageUrl), fit: BoxFit.cover) : null,
            ),
            child: pkg.imageUrl.isEmpty ? Center(child: Icon(Icons.image_outlined, size: 40, color: Colors.grey.shade400)) : null,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(pkg.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _primaryDark), overflow: TextOverflow.ellipsis)),
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                        onSelected: (action) {
                          if (action == 'edit') {
                            _showAddPackageDialog(context, ref, profile, existing: pkg);
                          } else if (action == 'delete') {
                            _showDeletePackageConfirm(context, ref, profile, pkg);
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18, color: _primaryDark), SizedBox(width: 8), Text('Edit')])),
                          const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Rs. ${pkg.price.toStringAsFixed(0)}', style: const TextStyle(color: _accentGold, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 6),
                  Expanded(child: Text(pkg.description, style: const TextStyle(color: Colors.grey, fontSize: 13), maxLines: 3, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteProductConfirm(BuildContext context, WidgetRef ref, VendorProfile profile, GenericSingleProduct prod) {
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Product', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text('Are you sure you want to delete "${prod.name}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              final newProducts = profile.singleProducts.where((p) => p.id != prod.id).toList();
              ref.read(vendorProfileProvider.notifier).updateProfile(singleProducts: newProducts);
              Navigator.pop(dlgCtx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showDeletePackageConfirm(BuildContext context, WidgetRef ref, VendorProfile profile, GenericServicePackage pkg) {
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Package', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text('Are you sure you want to delete "${pkg.name}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              final newPackages = profile.servicePackages.where((p) => p.id != pkg.id).toList();
              ref.read(vendorProfileProvider.notifier).updateProfile(servicePackages: newPackages);
              Navigator.pop(dlgCtx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddProductDialog(BuildContext context, WidgetRef ref, VendorProfile profile, {GenericSingleProduct? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final priceCtrl = TextEditingController(text: existing != null ? existing.price.toStringAsFixed(0) : '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    String currentImageUrl = existing?.imageUrl ?? '';
    bool isUploading = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 16,
            clipBehavior: Clip.antiAlias,
            child: Container(
              width: 440,
              decoration: const BoxDecoration(color: Colors.white),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Emerald & Gold Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF064E3B), Color(0xFF047857)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4AF37).withValues(alpha: 0.25),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.sell_rounded, color: Color(0xFFD4AF37), size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  existing == null ? 'Add Product / Service' : 'Edit Product / Service',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  existing == null ? 'List an individual service item' : 'Update product details',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),

                    // Form Content
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('PRODUCT / SERVICE NAME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF064E3B), letterSpacing: 0.8)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: nameCtrl,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'e.g. Bridal Stage Decor',
                              prefixIcon: const Icon(Icons.label_outline, color: Color(0xFF064E3B), size: 18),
                              prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              isDense: true,
                              filled: true,
                              fillColor: const Color(0xFFF8FAF9),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF064E3B), width: 1.8)),
                            ),
                          ),
                          const SizedBox(height: 16),

                          const Text('PRICE (RS.)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF064E3B), letterSpacing: 0.8)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: priceCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: '50000',
                              prefixText: 'Rs. ',
                              prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 14),
                              isDense: true,
                              filled: true,
                              fillColor: const Color(0xFFF8FAF9),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF064E3B), width: 1.8)),
                            ),
                          ),
                          const SizedBox(height: 16),

                          const Text('DESCRIPTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF064E3B), letterSpacing: 0.8)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: descCtrl,
                            maxLines: 3,
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Describe what this service includes...',
                              isDense: true,
                              filled: true,
                              fillColor: const Color(0xFFF8FAF9),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF064E3B), width: 1.8)),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Image Upload
                          const Text('PRODUCT IMAGE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF064E3B), letterSpacing: 0.8)),
                          const SizedBox(height: 6),
                          if (currentImageUrl.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(currentImageUrl, height: 120, width: double.infinity, fit: BoxFit.cover),
                                  ),
                                  Positioned(
                                    top: 4, right: 4,
                                    child: GestureDetector(
                                      onTap: () => setDlgState(() => currentImageUrl = ''),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                        child: const Icon(Icons.close, color: Colors.white, size: 14),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (isUploading)
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(child: CircularProgressIndicator(color: Color(0xFF064E3B))),
                            )
                          else if (currentImageUrl.isEmpty)
                            OutlinedButton.icon(
                              onPressed: () async {
                                setDlgState(() => isUploading = true);
                                final url = await _uploadSingleImage();
                                setDlgState(() {
                                  if (url != null) currentImageUrl = url;
                                  isUploading = false;
                                });
                              },
                              icon: const Icon(Icons.add_a_photo, color: Color(0xFF064E3B), size: 18),
                              label: const Text('Upload Image', style: TextStyle(color: Color(0xFF064E3B))),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey.shade300),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                            ),
                          const SizedBox(height: 24),

                          // Actions
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
                                child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                                label: Text(existing == null ? 'Save Product' : 'Update Product', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF064E3B),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  elevation: 2,
                                  shadowColor: const Color(0xFF064E3B).withValues(alpha: 0.3),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: isUploading ? null : () {
                                  final name = nameCtrl.text.trim();
                                  final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                                  if (name.isEmpty || price <= 0) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid name and price')));
                                    return;
                                  }
                                  
                                  List<GenericSingleProduct> updatedList = List.from(profile.singleProducts);
                                  
                                  if (existing != null) {
                                    final idx = updatedList.indexWhere((p) => p.id == existing.id);
                                    if (idx != -1) {
                                      updatedList[idx] = GenericSingleProduct(
                                        id: existing.id, name: name, price: price,
                                        description: descCtrl.text.trim(), imageUrl: currentImageUrl,
                                      );
                                    }
                                  } else {
                                    updatedList.add(GenericSingleProduct(
                                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                                      name: name, price: price,
                                      description: descCtrl.text.trim(), imageUrl: currentImageUrl,
                                    ));
                                  }
                                  
                                  ref.read(vendorProfileProvider.notifier).updateProfile(singleProducts: updatedList);
                                  Navigator.pop(ctx);
                                },
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
          );
        },
      ),
    );
  }

  void _showAddPackageDialog(BuildContext context, WidgetRef ref, VendorProfile profile, {GenericServicePackage? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final priceCtrl = TextEditingController(text: existing != null ? existing.price.toStringAsFixed(0) : '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final itemInputCtrl = TextEditingController();
    String currentImageUrl = existing?.imageUrl ?? '';
    bool isUploading = false;

    List<String> dlgItems = List.from(existing?.items ?? []);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 16,
            clipBehavior: Clip.antiAlias,
            child: Container(
              width: 440,
              decoration: const BoxDecoration(color: Colors.white),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Gold & Emerald Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFB48A1D), Color(0xFFD4AF37)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                            child: const Icon(Icons.stars_rounded, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  existing == null ? 'Create Service Package' : 'Edit Service Package',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  existing == null ? 'Bundle services into a complete deal' : 'Update package details',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 20),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),

                    // Form Content
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('PACKAGE NAME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF064E3B), letterSpacing: 0.8)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: nameCtrl,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'e.g. Complete Baraat Decor Package',
                              prefixIcon: const Icon(Icons.card_giftcard_outlined, color: Color(0xFFD4AF37), size: 18),
                              prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              isDense: true,
                              filled: true,
                              fillColor: const Color(0xFFF8FAF9),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 1.8)),
                            ),
                          ),
                          const SizedBox(height: 16),

                          const Text('PACKAGE PRICE (RS.)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF064E3B), letterSpacing: 0.8)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: priceCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: '150000',
                              prefixText: 'Rs. ',
                              prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 14),
                              isDense: true,
                              filled: true,
                              fillColor: const Color(0xFFF8FAF9),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 1.8)),
                            ),
                          ),
                          const SizedBox(height: 16),

                          const Text('DESCRIPTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF064E3B), letterSpacing: 0.8)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: descCtrl,
                            maxLines: 2,
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Describe what this package covers...',
                              isDense: true,
                              filled: true,
                              fillColor: const Color(0xFFF8FAF9),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 1.8)),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Included Items
                          const Text('INCLUDED ITEMS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF064E3B), letterSpacing: 0.8)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: itemInputCtrl,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                  decoration: InputDecoration(
                                    hintText: 'Add item (e.g. Stage Flowers)',
                                    isDense: true,
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAF9),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                                  ),
                                  onSubmitted: (val) {
                                    if (val.trim().isNotEmpty) {
                                      setDlgState(() {
                                        dlgItems.add(val.trim());
                                        itemInputCtrl.clear();
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF064E3B),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () {
                                  final val = itemInputCtrl.text.trim();
                                  if (val.isNotEmpty) {
                                    setDlgState(() {
                                      dlgItems.add(val);
                                      itemInputCtrl.clear();
                                    });
                                  }
                                },
                                child: const Text('+ Add', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (dlgItems.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: const Text('No items added yet.', style: TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
                            )
                          else
                            ...dlgItems.asMap().entries.map((entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.fiber_manual_record, size: 6, color: Color(0xFFD4AF37)),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(entry.value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                                  GestureDetector(
                                    onTap: () => setDlgState(() => dlgItems.removeAt(entry.key)),
                                    child: const Icon(Icons.close, size: 14, color: Colors.red),
                                  ),
                                ],
                              ),
                            )),
                          const SizedBox(height: 16),

                          // Image Upload
                          const Text('PACKAGE IMAGE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF064E3B), letterSpacing: 0.8)),
                          const SizedBox(height: 6),
                          if (currentImageUrl.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(currentImageUrl, height: 120, width: double.infinity, fit: BoxFit.cover),
                                  ),
                                  Positioned(
                                    top: 4, right: 4,
                                    child: GestureDetector(
                                      onTap: () => setDlgState(() => currentImageUrl = ''),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                        child: const Icon(Icons.close, color: Colors.white, size: 14),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (isUploading)
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37))),
                            )
                          else if (currentImageUrl.isEmpty)
                            OutlinedButton.icon(
                              onPressed: () async {
                                setDlgState(() => isUploading = true);
                                final url = await _uploadSingleImage();
                                setDlgState(() {
                                  if (url != null) currentImageUrl = url;
                                  isUploading = false;
                                });
                              },
                              icon: const Icon(Icons.add_a_photo, color: Color(0xFFD4AF37), size: 18),
                              label: const Text('Upload Image', style: TextStyle(color: Color(0xFFD4AF37))),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey.shade300),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                            ),
                          const SizedBox(height: 24),

                          // Actions
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
                                child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                                label: Text(existing == null ? 'Save Package' : 'Update Package', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD4AF37),
                                  foregroundColor: const Color(0xFF064E3B),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  elevation: 2,
                                  shadowColor: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: isUploading ? null : () {
                                  final name = nameCtrl.text.trim();
                                  final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                                  if (name.isEmpty || price <= 0) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid name and price')));
                                    return;
                                  }
                                  
                                  List<GenericServicePackage> updatedList = List.from(profile.servicePackages);

                                  if (existing != null) {
                                    final idx = updatedList.indexWhere((p) => p.id == existing.id);
                                    if (idx != -1) {
                                      updatedList[idx] = GenericServicePackage(
                                        id: existing.id, name: name, price: price,
                                        description: descCtrl.text.trim(), items: dlgItems, imageUrl: currentImageUrl,
                                      );
                                    }
                                  } else {
                                    updatedList.add(GenericServicePackage(
                                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                                      name: name, price: price,
                                      description: descCtrl.text.trim(), items: dlgItems, imageUrl: currentImageUrl,
                                    ));
                                  }
                                  
                                  ref.read(vendorProfileProvider.notifier).updateProfile(servicePackages: updatedList);
                                  Navigator.pop(ctx);
                                },
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
          );
        },
      ),
    );
  }
}
